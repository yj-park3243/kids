import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle _base({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.notoSansKr(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Headings
  static TextStyle get heading1 => _base(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.3,
      );

  static TextStyle get heading2 => _base(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
      );

  static TextStyle get heading3 => _base(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  // Body
  static TextStyle get body1 => _base(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get body1Bold => _base(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.5,
      );

  static TextStyle get body2 => _base(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get body2Bold => _base(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.5,
      );

  // Caption
  static TextStyle get caption => _base(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  static TextStyle get captionBold => _base(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  // Button
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

  // Special
  static TextStyle get onboarding => _base(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.4,
      );

  static TextStyle get tag => _base(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.primary,
        height: 1.2,
      );

  static TextStyle get badge => _base(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.2,
      );
}
