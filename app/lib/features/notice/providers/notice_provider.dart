import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/notice.dart';
import '../data/notice_repository.dart';

/// 고정 공지는 1시간마다 재조회.
const _pinnedNoticesTtl = Duration(hours: 1);

/// 홈 배너용 고정 공지 — keepAlive + TTL 캐시.
final pinnedNoticesProvider = FutureProvider<List<Notice>>((ref) async {
  final link = ref.keepAlive();
  Timer? ttlTimer;
  ref.onDispose(() => ttlTimer?.cancel());

  final notices = await ref.read(noticeRepositoryProvider).getPinnedNotices();

  // TTL 만료 시 캐시 해제 → 다음 구독에서 서버 재조회.
  ttlTimer = Timer(_pinnedNoticesTtl, () => link.close());

  return notices;
});

/// 공지 목록.
final noticeListProvider =
    FutureProvider.autoDispose<List<Notice>>((ref) async {
  return ref.read(noticeRepositoryProvider).getNotices();
});

/// 공지 상세.
final noticeDetailProvider =
    FutureProvider.autoDispose.family<Notice, String>((ref, id) async {
  return ref.read(noticeRepositoryProvider).getNotice(id);
});
