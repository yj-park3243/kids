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

/// Opens the socket stream for a specific room.
final chatMessageStreamProvider =
    StreamProvider.autoDispose.family<ChatMessage, String>((ref, roomId) {
  return ref.watch(chatRepositoryProvider).messageStream(roomId);
});

/// Loads a page of historical messages (newest first).
final chatHistoryProvider = FutureProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, roomId) async {
  final page =
      await ref.watch(chatRepositoryProvider).fetchMessages(roomId, limit: 50);
  return page.items;
});
