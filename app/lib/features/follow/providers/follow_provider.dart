import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
import '../../../models/follow.dart';
import '../data/follow_repository.dart';

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository();
});

/// 내 팔로잉 목록 + 토글 액션을 관리.
class FollowingState {
  final List<Follow> items;
  final bool isLoading;
  final String? error;

  const FollowingState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  FollowingState copyWith({
    List<Follow>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FollowingState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class FollowingNotifier extends StateNotifier<FollowingState> {
  final FollowRepository _repository;

  FollowingNotifier(this._repository) : super(const FollowingState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _repository.getMyFollowing();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '팔로잉 목록을 불러올 수 없어요',
      );
    }
  }

  Future<void> unfollow(String targetUserId) async {
    try {
      await _repository.unfollow(targetUserId);
      state = state.copyWith(
        items: state.items
            .where((f) => f.targetUserId != targetUserId)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(
        error: apiErrorMessage(e, fallback: '언팔로우에 실패했어요'),
      );
    }
  }
}

/// 나를 팔로우하는 사람 목록.
final followersProvider = FutureProvider.autoDispose<List<Follow>>((ref) {
  return ref.watch(followRepositoryProvider).getMyFollowers();
});

final followingProvider =
    StateNotifierProvider<FollowingNotifier, FollowingState>((ref) {
  return FollowingNotifier(ref.watch(followRepositoryProvider));
});

/// 단건 팔로우 토글 상태 (특정 유저 프로필 화면용).
/// key: targetUserId.
class FollowToggleNotifier
    extends StateNotifier<AsyncValue<bool>> {
  final FollowRepository _repository;
  final String targetUserId;

  FollowToggleNotifier(
    this._repository,
    this.targetUserId,
    bool initial,
  ) : super(AsyncValue.data(initial));

  /// 성공이면 null, 실패면 사용자에게 보여줄 사유(차단 관계 등 서버 메시지).
  Future<String?> toggle() async {
    final current = state.value ?? false;
    state = const AsyncValue.loading();
    try {
      if (current) {
        await _repository.unfollow(targetUserId);
        state = const AsyncValue.data(false);
      } else {
        await _repository.follow(targetUserId);
        state = const AsyncValue.data(true);
      }
      return null;
    } catch (e) {
      // 실패 시 직전 상태로 복귀
      state = AsyncValue.data(current);
      return apiErrorMessage(
        e,
        fallback: current ? '언팔로우에 실패했어요' : '팔로우에 실패했어요',
      );
    }
  }
}

/// family 인자: (targetUserId, initialIsFollowing)
final followToggleProvider = StateNotifierProvider.family<FollowToggleNotifier,
    AsyncValue<bool>, ({String targetUserId, bool initial})>((ref, args) {
  return FollowToggleNotifier(
    ref.watch(followRepositoryProvider),
    args.targetUserId,
    args.initial,
  );
});
