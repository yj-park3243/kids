import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// 같이크자 타이포 (docs/09_UI_수첩안.md).
///
/// - UI 전체 → IBM Plex Sans KR. 400/500/600/700 네 굵기로 위계를 세운다.
///   (이전 고운돋움은 굵기가 하나뿐이라 크기로만 위계를 내야 했고, 그래서 산만했다)
/// - 손글씨(개구체, [hand]) → 숫자와 인사말에만. 날짜·개월수·통계·D-day.
///   본문에 쓰면 읽기 힘들어지므로 절대 문장에 쓰지 않는다.
///
/// 폰트 파일은 `google_fonts/` 폴더에 번들돼 있어 런타임 다운로드가 없다.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _base({
    double fontSize = 14.5,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.ink,
    double? height,
    double letterSpacing = -0.2,
  }) {
    return GoogleFonts.ibmPlexSansKr(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle _hand({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w700,
    Color color = AppColors.ink,
    double? height,
  }) {
    return GoogleFonts.gaegu(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height ?? 1.0,
    );
  }

  // ===== 손글씨 (숫자 · 인사말 전용) =====

  /// 홈 인사말. "내일 성미산에서 만나요" — 핵심 단어는 [Highlight]로 형광펜.
  static TextStyle get greeting => _hand(fontSize: 32, height: 1.2);

  /// 워드마크 "같이크자".
  static TextStyle get wordmark => _hand(fontSize: 26);

  /// 목록 행의 날짜 숫자, 통계 큰 숫자.
  static TextStyle get handXl => _hand(fontSize: 28);

  /// 정보 목록 안의 숫자(9/13, 2/4), 개월수.
  static TextStyle get handLg => _hand(fontSize: 19);

  /// 문장 안에 섞이는 작은 숫자(함께한 모임 8회).
  static TextStyle get hand => _hand(fontSize: 16);

  /// D-day 도장, 날짜 구분선.
  static TextStyle get stamp => _hand(fontSize: 17);

  // ===== 화면 제목 · 섹션 =====

  /// 상세 화면 큰 제목 (모임 이름).
  static TextStyle get display => _base(
        fontSize: 23,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.4,
      );

  /// 앱바 제목.
  static TextStyle get screenTitle => _base(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.3,
      );

  /// 섹션 제목 ("이번 주", "참여자").
  static TextStyle get sectionHead => _base(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.3,
      );

  // Legacy aliases (kept for existing screens)
  static TextStyle get heading1 => display;
  static TextStyle get heading2 => _base(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.4,
      );
  static TextStyle get heading3 => sectionHead;

  // ===== 목록 행 · 본문 =====

  /// 목록 행 제목 (모임 이름 한 줄).
  static TextStyle get cardTitle => _base(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: -0.2,
      );

  static TextStyle get body1 => _base(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        height: 1.55,
      );

  static TextStyle get body1Bold => _base(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        height: 1.55,
      );

  /// 보조 정보 (위치 · 시간).
  static TextStyle get body2 => _base(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.ink2,
        height: 1.5,
      );

  static TextStyle get body2Bold => _base(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.5,
      );

  /// 긴 설명글 (모임 소개, 공지 본문).
  static TextStyle get paragraph => _base(
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
        color: AppColors.ink2,
        height: 1.65,
      );

  // ===== 캡션 · 칩 · 배지 =====
  static TextStyle get caption => _base(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.ink3,
        height: 1.4,
      );

  static TextStyle get captionBold => _base(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.ink2,
        height: 1.4,
      );

  /// 목록 그룹 라벨 ("오늘 · 9월 12일 금요일", "다음 주").
  static TextStyle get groupLabel => _base(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.ink3,
        height: 1.3,
        letterSpacing: 0.2,
      );

  static TextStyle get chip => _base(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.0,
      );

  static TextStyle get badge => _base(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.0,
      );

  // ===== 버튼 =====
  static TextStyle get button => _base(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.2,
      );

  static TextStyle get buttonSmall => _base(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
      );

  // ===== Special =====
  static TextStyle get onboarding => _base(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.4,
      );

  static TextStyle get tag => _base(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.ink2,
        height: 1.2,
      );
}
