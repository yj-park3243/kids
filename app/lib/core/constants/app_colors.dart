import 'package:flutter/material.dart';

/// '우리 동네 육아 수첩' 팔레트 (docs/09_UI_수첩안.md).
///
/// 종이 한 장 위에 잉크로 쓰고, 형광펜(hi)으로 **지금·여기·오늘**만 표시한다.
/// 색이 정보를 갖는다 — hi=모집중/오늘/활성, sky=아이·개월수, sage=쑥쑥 등급,
/// berry=안읽음·알림 점. 그 밖의 강조는 굵기와 여백으로.
///
/// 아래 "Legacy" 이름들은 이전 팔레트(핑크·글래스) 시절 화면들이 깨지지 않도록
/// 남겨둔 별칭이다. 새 코드는 위쪽 정식 이름만 쓴다.
class AppColors {
  AppColors._();

  // ===== 종이 · 면 · 선 =====
  static const Color paper = Color(0xFFFFFCF5); // 화면 배경 (조금 노란 종이)
  static const Color surface = Color(0xFFFFFFFF); // 카드 · 바 · 입력창
  static const Color line = Color(0xFFEAE4D8); // 헤어라인
  static const Color line2 = Color(0xFFD9D1C2); // 점선 괘선 · 강한 선
  static const Color fill = Color(0xFFF4EFE4); // 비활성 면 · 세그먼트 트랙

  // ===== 잉크 =====
  static const Color ink = Color(0xFF221F1C); // 본문 · CTA 버튼 · 내 말풍선 · 활성 탭
  static const Color ink2 = Color(0xFF625B54); // 보조 텍스트
  static const Color ink3 = Color(0xFF9A928A); // 힌트 · 아이콘 · 비활성 탭

  // ===== 형광펜 =====
  static const Color hi = Color(0xFFFFD84D); // 모집중 · 오늘 · 활성 탭 자국 · D-day 도장
  static const Color hiInk = Color(0xFF5A4600); // hi 위의 진한 글씨

  // ===== 아이 · 개월수 =====
  static const Color sky = Color(0xFFE3EEFF);
  static const Color skyInk = Color(0xFF2456B8); // 링크 · 토요일 날짜

  // ===== 쑥쑥 등급 =====
  static const Color sage = Color(0xFFE4F1E6);
  static const Color sageInk = Color(0xFF2E6B4E);

  // ===== 스티커 점 (기존 브랜드 핑크의 흔적) =====
  static const Color berry = Color(0xFFF26E96); // 안읽음 배지 · 알림 점

  // ===== 상태 =====
  static const Color link = skyInk;
  static const Color ok = Color(0xFF2F9E6B);
  static const Color warn = Color(0xFFD48A1E);
  static const Color bad = Color(0xFFD64545);

  // ===== 소셜 로그인 (브랜드 색 보존) =====
  static const Color kakao = Color(0xFFFEE500);
  static const Color kakaoText = Color(0xFF191919);
  static const Color apple = ink;
  static const Color google = Colors.white;
  static const Color googleBorder = line2;

  // ─────────────────────────────────────────────────────────────
  // Legacy aliases — 기존 화면 호환용. 새 코드에서 쓰지 말 것.
  // ─────────────────────────────────────────────────────────────

  // primary 계열 → 잉크. (CTA·활성 상태가 검정으로 통일된다)
  static const Color primary = ink;
  static const Color primaryLight = ink2;
  static const Color primaryDark = ink;
  static const Color primary50 = fill;
  static const Color primary100 = line;
  static const Color primary200 = line2;
  static const Color primary300 = ink3;
  static const Color primary400 = ink2;
  static const Color primary700 = ink;

  // 알록달록 보조 5색 → 역할별 1색으로 수렴
  static const Color accentYellow = hi;
  static const Color accentSky = skyInk;
  static const Color accentLavender = skyInk;
  static const Color accentCoral = berry;
  static const Color accentLime = sageInk;

  static const Color secondary = skyInk;
  static const Color secondaryLight = sky;
  static const Color secondaryDark = skyInk;
  static const Color accent = berry;
  static const Color accentLightAlias = Color(0xFFFBD3DF);
  static const Color accentDark = Color(0xFFD14B73);

  static const Color background = paper;
  static const Color backgroundSoft = fill;
  static const Color surfaceVariant = fill;
  static const Color bg = paper;
  static const Color bg2 = fill;

  static const Color ink900 = ink;
  static const Color ink700 = ink;
  static const Color ink500 = ink2;
  static const Color ink300 = ink3;
  static const Color textPrimary = ink;
  static const Color textSecondary = ink2;
  static const Color textHint = ink3;
  static const Color textOnPrimary = Colors.white;

  static const Color error = bad;
  static const Color success = ok;
  static const Color warning = warn;
  static const Color info = skyInk;

  static const Color recruiting = hi;
  static const Color closed = line2;
  static const Color cancelled = berry;

  static const Color divider = line;
  static const Color dividerStrong = line2;
  static const Color shimmerBase = fill;
  static const Color shimmerHighlight = paper;
  static const Color chatBubbleMine = ink;
  static const Color chatBubbleOther = surface;
  static const Color unreadBadge = berry;

  static const Color coral = berry;
  static const Color cream = paper;
  static const Color lilac = sky;
  static const Color accentLight = accentLightAlias;

  // 그라데이션은 더 이상 쓰지 않는다 — 단색으로 평탄화 (API 호환용).
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [ink, ink],
  );
  static const LinearGradient primaryTextGradient = LinearGradient(
    colors: [ink, ink],
  );

  static const Color glassWhite = surface;
  static const Color glassWhiteStrong = surface;
  static const Color glassBorder = line;

  static const List<Color> accentRotation = [ink, skyInk, sageInk];

  /// 문자열 키 → 액센트 색 (안정적 매핑)
  static Color accentFor(String key) {
    if (key.isEmpty) return ink;
    final hash = key.codeUnits.fold<int>(0, (a, b) => (a + b) & 0xffff);
    return accentRotation[hash % accentRotation.length];
  }

  // 장소 타입은 더 이상 색으로 구분하지 않는다 (글자로 충분).
  static const Color placeAll = ink2;
  static const Map<String, Color> placeTypeColor = {
    'PLAYGROUND': ink,
    'KIDS_CAFE': ink,
    'PARTY_ROOM': ink,
    'PARK': ink,
    'OTHER': ink,
  };

  static Color placeColorFor(String key) => placeTypeColor[key] ?? ink;
}
