import 'package:flutter/material.dart';

/// 모든 ScrollView 에 onDrag 키보드 dismiss 를 기본 적용.
/// MaterialApp.scrollBehavior 로 설정.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollViewKeyboardDismissBehavior getKeyboardDismissBehavior(
    BuildContext context,
  ) =>
      ScrollViewKeyboardDismissBehavior.onDrag;
}
