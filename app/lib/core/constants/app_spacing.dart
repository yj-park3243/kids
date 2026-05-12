import 'package:flutter/widgets.dart';

/// "판을 키운" 여유 있는 spacing 토큰. 좁고 답답한 인상을 풀기 위해 의도적으로
/// 일반 머티리얼 기본값보다 한 단계씩 크게 잡음.
class AppSpacing {
  AppSpacing._();

  // 기본 스케일
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;

  // 화면 가장자리 (좌우 여백) — 기존 20 → 24
  static const double screen = 24;

  // 섹션 사이 vertical 간격
  static const double section = 28;

  // 카드 내부 padding
  static const double card = 20;

  // ─── EdgeInsets shortcut ───────────────────────────────────────
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: screen);
  static const EdgeInsets screenV = EdgeInsets.symmetric(vertical: screen);
  static const EdgeInsets screenAll = EdgeInsets.all(screen);
  static const EdgeInsets cardAll = EdgeInsets.all(card);
  static const EdgeInsets gapMd = EdgeInsets.all(md);
  static const EdgeInsets gapLg = EdgeInsets.all(lg);

  // ─── SizedBox shortcut (vertical gap) ──────────────────────────
  static const SizedBox gapXxs = SizedBox(height: xxs);
  static const SizedBox gapXs = SizedBox(height: xs);
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapMdV = SizedBox(height: md);
  static const SizedBox gapLgV = SizedBox(height: lg);
  static const SizedBox gapXl = SizedBox(height: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl);
  static const SizedBox gapSection = SizedBox(height: section);
}
