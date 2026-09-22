import 'package:flutter/material.dart';

/// 그림자는 화면에 하나만 — 홈의 '다음 모임' 카드([hero]).
/// 나머지 카드는 1px 헤어라인으로 구분한다 (docs/09_UI_수첩안.md).
class AppShadows {
  AppShadows._();

  static const Color _ink = Color(0xFF281C0A);

  /// 떠 있는 카드 하나(홈 다음 모임)에만.
  static List<BoxShadow> get hero => [
        BoxShadow(
          color: _ink.withValues(alpha: 0.08),
          blurRadius: 26,
          offset: const Offset(0, 10),
        ),
      ];

  /// 바텀시트·드롭다운 등 겹쳐 뜨는 면.
  static List<BoxShadow> get overlay => [
        BoxShadow(
          color: _ink.withValues(alpha: 0.10),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  // Legacy aliases — 일반 카드는 그림자 없음.
  static List<BoxShadow> get glass => const [];
  static List<BoxShadow> get glassStrong => hero;
  static List<BoxShadow> get primaryCta => const [];
  static List<BoxShadow> get soft => const [];
}
