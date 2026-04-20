import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';

/// 현재 선택된 아이를 관리하는 글로벌 Provider.
/// 홈, 지도, 방 생성 등에서 공유하여 아이 기준으로 방을 찾고 생성한다.
class SelectedChildNotifier extends StateNotifier<Child?> {
  SelectedChildNotifier() : super(null);

  void select(Child child) => state = child;

  void clear() => state = null;

  /// 유저의 첫 번째 아이로 초기화 (최초 로그인 후)
  void initFromUser(User user) {
    if (state != null) return; // 이미 선택되어 있으면 유지
    if (user.children != null && user.children!.isNotEmpty) {
      state = user.children!.first;
    }
  }
}

final selectedChildProvider =
    StateNotifierProvider<SelectedChildNotifier, Child?>((ref) {
  return SelectedChildNotifier();
});
