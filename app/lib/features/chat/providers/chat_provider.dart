import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/chat_message.dart';
import '../data/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final repo = ChatRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Loads the chat room list for the current user.
final chatRoomsProvider = FutureProvider.autoDispose<List<ChatRoom>>((ref) {
  return ref.watch(chatRepositoryProvider).fetchChatRooms();
});

/// 모든 채팅방의 안 읽은 메시지 총합 — 하단 탭(채팅) 배지용.
/// 목록 로딩 전/에러 시에는 0 으로 본다.
final totalUnreadProvider = Provider.autoDispose<int>((ref) {
  final rooms = ref.watch(chatRoomsProvider);
  return rooms.maybeWhen(
    data: (list) => list.fold<int>(0, (sum, r) => sum + r.unreadCount),
    orElse: () => 0,
  );
});

/// Opens the socket stream for a specific room (messages + read receipts).
final chatRoomEventStreamProvider =
    StreamProvider.autoDispose.family<ChatRoomEvent, String>((ref, roomId) {
  return ref.watch(chatRepositoryProvider).roomEventStream(roomId);
});

/// Loads a page of historical messages (newest first).
final chatHistoryProvider = FutureProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, roomId) async {
  final page =
      await ref.watch(chatRepositoryProvider).fetchMessages(roomId, limit: 50);
  return page.items;
});
