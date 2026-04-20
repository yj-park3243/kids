import 'dart:async';

import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../models/chat_message.dart';

/// REST + WebSocket 기반 채팅 레포지토리.
/// - 목록/히스토리 조회는 REST (`/v1/chat/...`)
/// - 실시간 수신은 socket.io (`namespace=/chat`, event=`message`)
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
  }) async {
    final res = await _dio.post(
      ApiConstants.chatMessages(roomId),
      data: {'content': content},
    );
    return ChatMessage.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  /// Returns a broadcast stream of messages for the given room.
  /// The first subscriber opens the socket; the last to cancel closes it.
  Stream<ChatMessage> messageStream(String roomId) {
    final controller = StreamController<ChatMessage>.broadcast();
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
              ChatMessage.fromJson(Map<String, dynamic>.from(data)),
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
