import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/block_repository.dart';

final blockRepositoryProvider = Provider<BlockRepository>((ref) {
  return BlockRepository();
});

/// 차단한 유저 목록. 화면 진입 시 자동 fetch.
final blockedUsersProvider =
    FutureProvider.autoDispose<List<BlockedUser>>((ref) async {
  final repo = ref.watch(blockRepositoryProvider);
  return repo.getBlockedUsers();
});
