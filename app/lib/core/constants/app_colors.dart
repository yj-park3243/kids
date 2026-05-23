import 'package:flutter/material.dart';

/// 파스텔 키즈 팔레트. 흰 베이스 + 민트 primary + 5색 알록달록 보조.
class AppColors {
  AppColors._();

  // ===== Primary (핑크) =====
  static const Color primary = Color(0xFFF26E96);
  static const Color primaryLight = Color(0xFFF9A8BF);
  static const Color primaryDark = Color(0xFFD14B73);

  // Primary tonal scale (light → deep)
  static const Color primary50 = Color(0xFFFDEDF1);
  static const Color primary100 = Color(0xFFFAD2DD);
  static const Color primary200 = Color(0xFFF5AFC2);
  static const Color primary300 = Color(0xFFF08FA8);
  static const Color primary400 = Color(0xFFEE7B98);
  static const Color primary700 = Color(0xFFA63A5C);

  // ===== Accent palette (알록달록 보조) =====
  static const Color accentYellow = Color(0xFFFFD96B);
  static const Color accentSky = Color(0xFF6FB7FF);
  static const Color accentLavender = Color(0xFFB89BE8);
  static const Color accentCoral = Color(0xFFFF9476);
  static const Color accentLime = Color(0xFFB8E186);

  // ===== Semantic aliases =====
  static const Color secondary = accentLavender;
  static const Color secondaryLight = Color(0xFFD9C6F2);
  static const Color secondaryDark = Color(0xFF9176CC);
  static const Color accent = accentCoral;
  static const Color accentLightAlias = Color(0xFFFFC0AC);
  static const Color accentDark = Color(0xFFE07560);

  // ===== Surfaces =====
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundSoft = Color(0xFFFAFAF8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F1);
  static const Color bg = background;
  static const Color bg2 = backgroundSoft;

  // ===== Ink (text) =====
  static const Color ink900 = Color(0xFF1A1A2E);
  static const Color ink700 = Color(0xFF374151);
  static const Color ink500 = Color(0xFF6B7280);
  static const Color ink300 = Color(0xFF9CA3AF);
  static const Color textPrimary = ink900;
  static const Color textSecondary = ink500;
  static const Color textHint = ink300;
  static const Color textOnPrimary = Colors.white;

  // ===== Status =====
  static const Color error = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = accentYellow;
  static const Color info = accentSky;

  // ===== Badge / Tag =====
  static const Color recruiting = accentLime;
  static const Color closed = Color(0xFFD1D5DB);
  static const Color cancelled = accentCoral;

  // ===== Social login (브랜드 색 보존) =====
  static const Color kakao = Color(0xFFFEE500);
  static const Color kakaoText = Color(0xFF191919);
  static const Color apple = ink900;
  static const Color google = Colors.white;
  static const Color googleBorder = Color(0xFFE5E7EB);

  // ===== Misc =====
  static const Color divider = Color(0xFFE5E7EB);
  static const Color dividerStrong = Color(0xFFD1D5DB);
  static const Color shimmerBase = Color(0xFFF5F5F1);
  static const Color shimmerHighlight = Color(0xFFFAFAF8);
  static const Color chatBubbleMine = primary;
  static const Color chatBubbleOther = Color(0xFFF5F5F1);
  static const Color unreadBadge = accentCoral;

  // ===== Legacy aliases (non-primary 톤 — DesignChip/CategoryBadge에서 사용) =====
  static const Color coral = accentCoral;
  static const Color cream = backgroundSoft;
  static const Color lilac = Color(0xFFE6DAF9);
  static const Color accentLight = accentLightAlias;

  // ===== Gradients =====
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF08FA8), primary],
  );
  static const LinearGradient primaryTextGradient = LinearGradient(
    colors: [primary, primary400],
  );

  // ===== Glass =====
  static const Color glassWhite = Color(0xF2FFFFFF);
  static const Color glassWhiteStrong = Colors.white;
  static const Color glassBorder = Color(0xFFE5E7EB);

  // ===== Accent helpers (카테고리/카드별 좌측 보더용 순환) =====
  static const List<Color> accentRotation = [
    primary,
    accentLavender,
    accentCoral,
  ];

  /// 문자열 키 → 액센트 색 (안정적 매핑)
  static Color accentFor(String key) {
    if (key.isEmpty) return primary;
    final hash = key.codeUnits.fold<int>(0, (a, b) => (a + b) & 0xffff);
    return accentRotation[hash % accentRotation.length];
  }

  // ===== 장소 타입별 고정 색 (필터 칩 등 — 서로 뚜렷이 구분) =====
  static const Color placeAll = Color(0xFF455A64); // 장소 전체 - 청회색
  static const Map<String, Color> placeTypeColor = {
    'PLAYGROUND': Color(0xFFE0654A), // 놀이터 - 코랄
    'KIDS_CAFE': Color(0xFFD81B60), // 키즈카페 - 핑크
    'PARTY_ROOM': Color(0xFF8E24AA), // 파티룸 - 보라
    'PARK': Color(0xFFAD3A6E), // 공원 - 플럼
    'OTHER': Color(0xFF6D4C41), // 기타 - 갈색
  };

  /// 장소 타입 키 → 색 (미정의 키는 primary 폴백)
  static Color placeColorFor(String key) =>
      placeTypeColor[key] ?? primary;
}
