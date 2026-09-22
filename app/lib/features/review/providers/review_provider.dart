import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
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
  // 서버에 저장된 후기 id. 있으면 재진입(수정) 상태.
  final String? reviewId;
  // 마지막 저장 이후 바뀐 게 있는지.
  final bool dirty;
  final String? error;

  const ReviewDraft({
    this.score = 5,
    this.tags = const {},
    this.comment = '',
    this.reviewId,
    this.dirty = false,
    this.error,
  });

  bool get saved => reviewId != null && !dirty;

  ReviewDraft copyWith({
    int? score,
    Set<String>? tags,
    String? comment,
    String? reviewId,
    bool? dirty,
    String? error,
    bool clearError = false,
  }) {
    return ReviewDraft(
      score: score ?? this.score,
      tags: tags ?? this.tags,
      comment: comment ?? this.comment,
      reviewId: reviewId ?? this.reviewId,
      dirty: dirty ?? this.dirty,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 후기 작성 화면 전체 상태: targetUserId -> draft
class ReviewWriteState {
  final Map<String, ReviewDraft> drafts;
  // 기존 후기 불러오는 중 — 끝나기 전엔 폼을 그리지 않는다(초기값 주입 때문).
  final bool isLoading;
  final bool isSubmitting;
  final String? globalError;

  const ReviewWriteState({
    this.drafts = const {},
    this.isLoading = true,
    this.isSubmitting = false,
    this.globalError,
  });

  ReviewWriteState copyWith({
    Map<String, ReviewDraft>? drafts,
    bool? isLoading,
    bool? isSubmitting,
    String? globalError,
    bool clearError = false,
  }) {
    return ReviewWriteState(
      drafts: drafts ?? this.drafts,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      globalError: clearError ? null : (globalError ?? this.globalError),
    );
  }

  /// 전부 서버에 저장돼 있고 바뀐 게 없음.
  bool get allSaved =>
      drafts.isNotEmpty && drafts.values.every((d) => d.saved);

  /// 한 번이라도 저장한 적 있음 → 버튼 문구가 '수정 저장'.
  bool get anySaved => drafts.values.any((d) => d.reviewId != null);
}

class ReviewWriteNotifier extends StateNotifier<ReviewWriteState> {
  final ReviewRepository _repository;
  final String roomId;

  ReviewWriteNotifier(this._repository, this.roomId, List<String> targetIds)
      : super(ReviewWriteState(
          drafts: {for (final id in targetIds) id: const ReviewDraft()},
        )) {
    _loadExisting();
  }

  /// 재진입이면 기존 후기를 드래프트에 채운다. 실패해도 새로 쓰는 흐름은 막지 않는다.
  Future<void> _loadExisting() async {
    try {
      final existing = await _repository.getMyReviewsInRoom(roomId);
      final next = Map<String, ReviewDraft>.from(state.drafts);
      for (final r in existing) {
        if (!next.containsKey(r.targetUserId)) continue;
        next[r.targetUserId] = ReviewDraft(
          score: r.score,
          tags: r.tags.toSet(),
          comment: r.comment ?? '',
          reviewId: r.id,
        );
      }
      state = state.copyWith(drafts: next, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void setScore(String targetUserId, int score) {
    final cur = state.drafts[targetUserId] ?? const ReviewDraft();
    final next = Map<String, ReviewDraft>.from(state.drafts);
    next[targetUserId] = cur.copyWith(score: score, dirty: true);
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
    next[targetUserId] = cur.copyWith(tags: tags, dirty: true);
    state = state.copyWith(drafts: next);
  }

  void setComment(String targetUserId, String comment) {
    final cur = state.drafts[targetUserId] ?? const ReviewDraft();
    final next = Map<String, ReviewDraft>.from(state.drafts);
    next[targetUserId] = cur.copyWith(comment: comment, dirty: true);
    state = state.copyWith(drafts: next);
  }

  /// 모든 드래프트를 멤버별로 순차 저장. 이미 저장돼 있고 안 바뀐 항목은 건너뛰고,
  /// 저장된 적 있으면 수정(PATCH), 없으면 등록(POST).
  Future<bool> submitAll() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    final next = Map<String, ReviewDraft>.from(state.drafts);
    try {
      for (final entry in state.drafts.entries) {
        final d = entry.value;
        if (d.saved) continue;
        final comment = d.comment.trim();
        try {
          final Review saved;
          if (d.reviewId != null) {
            saved = await _repository.updateReview(d.reviewId!, {
              'score': d.score,
              'tags': d.tags.toList(),
              'comment': comment.isEmpty ? null : comment,
            });
          } else {
            saved = await _repository.submitReview(
              roomId: roomId,
              targetUserId: entry.key,
              score: d.score,
              tags: d.tags.toList(),
              comment: comment.isEmpty ? null : comment,
            );
          }
          next[entry.key] =
              d.copyWith(reviewId: saved.id, dirty: false, clearError: true);
        } catch (e) {
          // 서버 사유(이미 작성함/7일 경과 등)를 그대로 보여준다.
          next[entry.key] =
              d.copyWith(error: apiErrorMessage(e, fallback: '제출 실패'));
        }
      }
      state = state.copyWith(drafts: next, isSubmitting: false);
      return state.allSaved;
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
