import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Pretendard 계열 한글 타이포. Pretendard 폰트 미등록 환경이라
/// google_fonts의 Noto Sans KR로 대체 렌더링하되, 자간/두께는 Pretendard 스펙을 따른다.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _base({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.ink900,
    double? height,
    double letterSpacing = -0.3,
  }) {
    return GoogleFonts.notoSansKr(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // ===== Display / Screen title =====
  static TextStyle get display => _base(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -1.2,
      );

  static TextStyle get screenTitle => _base(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        height: 1.25,
        letterSpacing: -0.8,
      );

  static TextStyle get sectionHead => _base(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 1.3,
        letterSpacing: -0.5,
      );

  // Legacy aliases (kept for existing screens)
  static TextStyle get heading1 => screenTitle;
  static TextStyle get heading2 => _base(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.3,
        letterSpacing: -0.6,
      );
  static TextStyle get heading3 => sectionHead;

  // ===== Card / Body =====
  static TextStyle get cardTitle => _base(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        height: 1.35,
        letterSpacing: -0.3,
      );

  static TextStyle get body1 => _base(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.55,
        letterSpacing: -0.25,
      );

  static TextStyle get body1Bold => _base(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.55,
        letterSpacing: -0.25,
      );

  static TextStyle get body2 => _base(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.5,
        letterSpacing: -0.2,
      );

  static TextStyle get body2Bold => _base(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 1.5,
        letterSpacing: -0.2,
      );

  // ===== Caption / Chip / Badge =====
  static TextStyle get caption => _base(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.ink500,
        height: 1.4,
        letterSpacing: -0.2,
      );

  static TextStyle get captionBold => _base(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.ink700,
        height: 1.4,
        letterSpacing: -0.2,
      );

  static TextStyle get chip => _base(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.2,
      );

  static TextStyle get badge => _base(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        height: 1.2,
        letterSpacing: -0.2,
      );

  // ===== Buttons =====
  static TextStyle get button => _base(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.3,
      );

  static TextStyle get buttonSmall => _base(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.2,
      );

  // ===== Special =====
  static TextStyle get onboarding => _base(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.3,
        letterSpacing: -0.6,
      );

  static TextStyle get tag => _base(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.pink700,
        height: 1.2,
        letterSpacing: -0.2,
      );
}
