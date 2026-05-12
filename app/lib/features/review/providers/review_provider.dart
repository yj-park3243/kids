import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/review.dart';
import '../data/review_repository.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository();
});

/// 멤버별 후기 입력 상태 (작성 화면용)
class ReviewDraft {
  final int score; // 1~5
  final Set<String> tags;
  final String comment;
  final bool submitted;
  final String? error;

  const ReviewDraft({
    this.score = 5,
    this.tags = const {},
    this.comment = '',
    this.submitted = false,
    this.error,
  });

  ReviewDraft copyWith({
    int? score,
    Set<String>? tags,
    String? comment,
    bool? submitted,
    String? error,
    bool clearError = false,
  }) {
    return ReviewDraft(
      score: score ?? this.score,
      tags: tags ?? this.tags,
      comment: comment ?? this.comment,
      submitted: submitted ?? this.submitted,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 후기 작성 화면 전체 상태: targetUserId -> draft
class ReviewWriteState {
  final Map<String, ReviewDraft> drafts;
  final bool isSubmitting;
  final String? globalError;

  const ReviewWriteState({
    this.drafts = const {},
    this.isSubmitting = false,
    this.globalError,
  });

  ReviewWriteState copyWith({
    Map<String, ReviewDraft>? drafts,
    bool? isSubmitting,
    String? globalError,
    bool clearError = false,
  }) {
    return ReviewWriteState(
      drafts: drafts ?? this.drafts,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      globalError: clearError ? null : (globalError ?? this.globalError),
    );
  }

  bool get allSubmitted =>
      drafts.isNotEmpty && drafts.values.every((d) => d.submitted);
}

class ReviewWriteNotifier extends StateNotifier<ReviewWriteState> {
  final ReviewRepository _repository;
  final String roomId;

  ReviewWriteNotifier(this._repository, this.roomId, List<String> targetIds)
      : super(ReviewWriteState(
          drafts: {for (final id in targetIds) id: const ReviewDraft()},
        ));

  void setScore(String targetUserId, int score) {
    final cur = state.drafts[targetUserId] ?? const ReviewDraft();
    final next = Map<String, ReviewDraft>.from(state.drafts);
    next[targetUserId] = cur.copyWith(score: score);
    state = state.copyWith(drafts: next);
  }

  void toggleTag(String targetUserId, String tag) {
    final cur = state.drafts[targetUserId] ?? const ReviewDraft();
    final tags = Set<String>.from(cur.tags);
    if (tags.contains(tag)) {
      tags.remove(tag);
    } else {
      tags.add(tag);
    }
    final next = Map<String, ReviewDraft>.from(state.drafts);
    next[targetUserId] = cur.copyWith(tags: tags);
    state = state.copyWith(drafts: next);
  }

  void setComment(String targetUserId, String comment) {
    final cur = state.drafts[targetUserId] ?? const ReviewDraft();
    final next = Map<String, ReviewDraft>.from(state.drafts);
    next[targetUserId] = cur.copyWith(comment: comment);
    state = state.copyWith(drafts: next);
  }

  /// 모든 드래프트를 멤버별로 순차 제출. 이미 제출된 항목은 건너뜀.
  Future<bool> submitAll() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    final next = Map<String, ReviewDraft>.from(state.drafts);
    try {
      for (final entry in state.drafts.entries) {
        if (entry.value.submitted) continue;
        try {
          await _repository.submitReview(
            roomId: roomId,
            targetUserId: entry.key,
            score: entry.value.score,
            tags: entry.value.tags.toList(),
            comment: entry.value.comment.trim().isEmpty
                ? null
                : entry.value.comment.trim(),
          );
          next[entry.key] = entry.value.copyWith(submitted: true, clearError: true);
        } catch (e) {
          next[entry.key] = entry.value.copyWith(error: '제출 실패');
        }
      }
      state = state.copyWith(drafts: next, isSubmitting: false);
      return state.allSubmitted;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        globalError: '후기 제출 중 오류가 발생했습니다',
      );
      return false;
    }
  }
}

/// 인자: (roomId, targetUserIds joined by comma)
/// family 키를 단순화하기 위해 record 사용
final reviewWriteProvider = StateNotifierProvider.family<ReviewWriteNotifier,
    ReviewWriteState, ({String roomId, List<String> targetUserIds})>(
  (ref, args) {
    final repo = ref.watch(reviewRepositoryProvider);
    return ReviewWriteNotifier(repo, args.roomId, args.targetUserIds);
  },
);

/// 받은 후기 집계 (유저별)
final userReviewAggregateProvider =
    FutureProvider.family<ReviewAggregate, String>((ref, userId) async {
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.getUserReviewsAggregate(userId);
});

/// 사용 가능한 정성 태그 목록
const kReviewTags = <String>[
  '친절했어요',
  '약속 잘 지켜요',
  '아이와 잘 놀아줬어요',
  '매너 좋았어요',
  '분위기 메이커',
];
