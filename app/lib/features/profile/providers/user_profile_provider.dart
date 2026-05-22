import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user.dart';
import '../data/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

/// 상대방 프로필 (userId 별로 캐시)
final userProfileProvider =
    FutureProvider.family<User, String>((ref, userId) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getUserById(userId);
});
