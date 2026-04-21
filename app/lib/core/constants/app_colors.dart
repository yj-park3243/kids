import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ===== Pink palette (rose) — design handoff =====
  static const Color pink50 = Color(0xFFFFF1F6);
  static const Color pink100 = Color(0xFFFFDCE8);
  static const Color pink200 = Color(0xFFFFB8D0);
  static const Color pink300 = Color(0xFF8EB5FF); // placeholder
  static const Color pink300Real = Color(0xFFFF8EB5);
  static const Color pink400 = Color(0xFFF56799);
  static const Color pink500 = Color(0xFFE84C88);
  static const Color pink600 = Color(0xFFD13870);
  static const Color pink700 = Color(0xFFA62656);
  static const Color pinkInk = Color(0xFF5A1336);

  // Accents
  static const Color coral = Color(0xFFFFAD9A);
  static const Color cream = Color(0xFFFFF7F1);
  static const Color lilac = Color(0xFFE6D5FF);
  static const Color mint = Color(0xFFB9EAD2);

  // Neutral ink
  static const Color ink900 = Color(0xFF1A0F18);
  static const Color ink700 = Color(0xFF3B2A36);
  static const Color ink500 = Color(0xFF7A6270);
  static const Color ink300 = Color(0xFFB9A7B3);

  // Base backgrounds
  static const Color bg = Color(0xFFFFF9FB);
  static const Color bg2 = Color(0xFFFFF1F6);

  // ===== Legacy aliases (keep screen imports working) =====
  // Primary → pink500
  static const Color primary = pink500;
  static const Color primaryLight = Color(0xFFFF8EB5); // pink300
  static const Color primaryDark = pink600;

  // Secondary → lilac for subtle accent role
  static const Color secondary = Color(0xFFB08AE8);
  static const Color secondaryLight = lilac;
  static const Color secondaryDark = Color(0xFF7A5BB8);

  // Accent (legacy)
  static const Color accent = coral;
  static const Color accentLight = Color(0xFFFFC9BB);
  static const Color accentDark = Color(0xFFE89380);

  // Surface / background
  static const Color background = bg;
  static const Color surface = Colors.white;
  static const Color surfaceVariant = bg2;

  // Text
  static const Color textPrimary = ink900;
  static const Color textSecondary = ink500;
  static const Color textHint = ink300;
  static const Color textOnPrimary = Colors.white;

  // Status
  static const Color error = Color(0xFFE84C6B);
  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF39C12);
  static const Color info = Color(0xFF3498DB);

  // Badge / Tag
  static const Color recruiting = Color(0xFF27AE60);
  static const Color closed = ink300;
  static const Color cancelled = Color(0xFFE84C6B);

  // Social login
  static const Color kakao = Color(0xFFFEE500);
  static const Color kakaoText = Color(0xFF191919);
  static const Color apple = ink900;
  static const Color google = Colors.white;
  static const Color googleBorder = Color(0x24261A24);

  // Misc
  static const Color divider = Color(0x141A0F18); // 0.08 alpha on ink900
  static const Color dividerStrong = Color(0x241A0F18);
  static const Color shimmerBase = Color(0xFFF2E6EC);
  static const Color shimmerHighlight = Color(0xFFFFF9FB);
  static const Color chatBubbleMine = pink500;
  static const Color chatBubbleOther = Colors.white;
  static const Color unreadBadge = pink500;

  // ===== Gradients =====
  static const LinearGradient pinkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFF6AA0), pink500],
  );

  static const LinearGradient pinkTextGradient = LinearGradient(
    colors: [pink500, Color(0xFFFF8EB5)],
  );

  // ===== Glass =====
  static const Color glassWhite = Color(0x8CFFFFFF); // 0.55 alpha
  static const Color glassWhiteStrong = Color(0xB3FFFFFF); // 0.70 alpha
  static const Color glassPinkTop = Color(0x8CFFDBE8);
  static const Color glassPinkBottom = Color(0x59FFB8D0);
  static const Color glassBorder = Color(0xB3FFFFFF);
}
