import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../models/review.dart';

/// 받은 후기 집계 (GET /users/:userId/reviews 응답)
class ReviewAggregate {
  final double mannerScore;
  final int reviewCount;
  final Map<String, int> scoreDistribution;
  final List<ReviewTagCount> topTags;

  const ReviewAggregate({
    required this.mannerScore,
    required this.reviewCount,
    required this.scoreDistribution,
    required this.topTags,
  });

  factory ReviewAggregate.fromJson(Map<String, dynamic> json) {
    final dist = <String, int>{};
    final rawDist = json['scoreDistribution'];
    if (rawDist is Map) {
      rawDist.forEach((k, v) {
        dist[k.toString()] = (v is num) ? v.toInt() : 0;
      });
    }
    final tags = <ReviewTagCount>[];
    final rawTags = json['topTags'];
    if (rawTags is List) {
      for (final e in rawTags) {
        if (e is Map<String, dynamic>) tags.add(ReviewTagCount.fromJson(e));
      }
    }
    return ReviewAggregate(
      mannerScore: double.tryParse('${json['mannerScore'] ?? ''}') ?? 36.5,
      reviewCount: int.tryParse('${json['reviewCount'] ?? ''}') ?? 0,
      scoreDistribution: dist,
      topTags: tags,
    );
  }
}

class ReviewTagCount {
  final String tag;
  final int count;

  const ReviewTagCount({required this.tag, required this.count});

  factory ReviewTagCount.fromJson(Map<String, dynamic> json) {
    return ReviewTagCount(
      tag: json['tag']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReviewRepository {
  final Dio _dio = ApiClient.instance;

  /// 후기 등록 — POST /rooms/:roomId/reviews
  Future<Review> submitReview({
    required String roomId,
    required String targetUserId,
    required int score,
    required List<String> tags,
    String? comment,
  }) async {
    final response = await _dio.post(
      ApiConstants.roomReviews(roomId),
      data: {
        'targetUserId': targetUserId,
        'score': score,
        'tags': tags,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
    final data = response.data['data'] ?? response.data;
    return Review.fromJson(data);
  }

  /// 후기 수정 — PATCH /reviews/:reviewId
  Future<Review> updateReview(
    String reviewId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.patch(
      ApiConstants.reviewById(reviewId),
      data: payload,
    );
    final data = response.data['data'] ?? response.data;
    return Review.fromJson(data);
  }

  /// 후기 삭제 — DELETE /reviews/:reviewId
  Future<void> deleteReview(String reviewId) async {
    await _dio.delete(ApiConstants.reviewById(reviewId));
  }

  /// 받은 후기 집계 — GET /users/:userId/reviews
  Future<ReviewAggregate> getUserReviewsAggregate(String userId) async {
    final response = await _dio.get(ApiConstants.userReviews(userId));
    final data = response.data['data'] ?? response.data;
    return ReviewAggregate.fromJson(data as Map<String, dynamic>);
  }
}
