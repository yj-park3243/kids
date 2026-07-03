import 'dart:async';

import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../models/chat_message.dart';

/// 채팅방에서 들어오는 실시간 이벤트.
sealed class ChatRoomEvent {
  const ChatRoomEvent();
}

class ChatMessageEvent extends ChatRoomEvent {
  final ChatMessage message;
  const ChatMessageEvent(this.message);
}

/// 다른 유저(또는 본인 다른 기기)가 채팅방을 읽었다는 알림.
/// `lastReadAt` 이전의 메시지들은 그 유저 기준 읽음으로 간주.
class ChatReadEvent extends ChatRoomEvent {
  final String userId;
  final DateTime lastReadAt;
  const ChatReadEvent({required this.userId, required this.lastReadAt});
}

/// REST + WebSocket 기반 채팅 레포지토리.
/// - 목록/히스토리/읽음 처리는 REST (`/v1/chat/...`)
/// - 실시간 수신은 socket.io (`namespace=/chat`, event=`message`/`read`)
/// - 메시지 전송은 REST (서버가 WS로 브로드캐스트).
class ChatRepository {
  ChatRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;

  io.Socket? _socket;

  Future<List<ChatRoom>> fetchChatRooms() async {
    final res = await _dio.get(ApiConstants.chatRooms);
    final data = _unwrap(res.data);
    final list = (data as List).cast<Map<String, dynamic>>();
    return list.map(ChatRoom.fromJson).toList();
  }

  Future<({List<ChatMessage> items, String? nextCursor, bool hasMore})>
      fetchMessages(String roomId, {String? cursor, int limit = 50}) async {
    final res = await _dio.get(
      ApiConstants.chatMessages(roomId),
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );
    final data = _unwrap(res.data) as Map<String, dynamic>;
    final items = (data['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
    return (
      items: items,
      nextCursor: data['nextCursor'] as String?,
      hasMore: (data['hasMore'] as bool?) ?? false,
    );
  }

  Future<ChatMessage> sendMessage(
    String roomId, {
    required String content,
    String? type, // 'TEXT' (default) | 'LOCATION'
  }) async {
    final res = await _dio.post(
      ApiConstants.chatMessages(roomId),
      data: {
        'content': content,
        if (type != null) 'type': type,
      },
    );
    return ChatMessage.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<DateTime> markRoomRead(String roomId, {DateTime? asOf}) async {
    final res = await _dio.post(
      ApiConstants.chatRoomRead(roomId),
      data: {
        if (asOf != null) 'asOf': asOf.toUtc().toIso8601String(),
      },
    );
    final data = _unwrap(res.data) as Map<String, dynamic>;
    return DateTime.parse(data['lastReadAt'] as String);
  }

  /// 메시지 + 읽음 이벤트를 모두 받는 단일 스트림.
  /// 첫 구독자가 소켓을 열고 마지막 해제자가 소켓을 닫는다.
  Stream<ChatRoomEvent> roomEventStream(String roomId) {
    final controller = StreamController<ChatRoomEvent>.broadcast();
    io.Socket? socket;

    controller.onListen = () async {
      final token = await SecureStorage.getAccessToken();
      socket = io.io(
        ApiConstants.chatWsUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setAuth({'token': token})
            .build(),
      );
      _socket = socket;

      socket!
        ..onConnect((_) => socket!.emit('join', {'roomId': roomId}))
        ..on('message', (data) {
          if (data is Map) {
            controller.add(
              ChatMessageEvent(
                ChatMessage.fromJson(Map<String, dynamic>.from(data)),
              ),
            );
          }
        })
        ..on('read', (data) {
          if (data is Map) {
            final m = Map<String, dynamic>.from(data);
            final userId = m['userId'] as String?;
            final lastReadAtStr = m['lastReadAt'] as String?;
            if (userId == null || lastReadAtStr == null) return;
            controller.add(
              ChatReadEvent(
                userId: userId,
                lastReadAt: DateTime.parse(lastReadAtStr),
              ),
            );
          }
        })
        ..onConnectError((e) => controller.addError(e))
        ..onError((e) => controller.addError(e))
        ..connect();
    };

    controller.onCancel = () async {
      socket?.emit('leave', {'roomId': roomId});
      socket?.dispose();
      _socket = null;
      await controller.close();
    };

    return controller.stream;
  }

  /// WS로 읽음 알림을 즉시 emit (서버는 멤버 lastReadAt 갱신 + 룸 broadcast).
  void emitRead(String roomId, {DateTime? asOf}) {
    _socket?.emit('read', {
      'roomId': roomId,
      if (asOf != null) 'asOf': asOf.toUtc().toIso8601String(),
    });
  }

  /// 앱이 백그라운드로 갈 때 소켓을 즉시 끊는다 — 소켓이 살아있으면 서버가
  /// 이 유저를 "방을 보고 있음"으로 판정해 푸시를 스킵하기 때문
  /// (ping timeout 감지까지 최대 ~45초간 푸시 누락).
  void pauseSocket() => _socket?.disconnect();

  /// 포어그라운드 복귀 시 재연결 — onConnect 핸들러가 join 을 다시 emit 한다.
  void resumeSocket() => _socket?.connect();

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body['data'] != null) {
      return body['data'];
    }
    return body;
  }
}
