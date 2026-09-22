import 'package:flutter/widgets.dart';

class AppRadius {
  AppRadius._();

  static const double xs = 8; // 스탬프 · 작은 태그
  static const double sm = 12; // 세그먼트 · 입력창
  static const double md = 16; // 카드 · 메뉴 묶음
  static const double lg = 18; // 떠 있는 카드
  static const double xl = 24; // 바텀시트
  static const double pill = 999;

  static BorderRadius all(double v) => BorderRadius.all(Radius.circular(v));
  static BorderRadius get rXs => all(xs);
  static BorderRadius get rSm => all(sm);
  static BorderRadius get rMd => all(md);
  static BorderRadius get rLg => all(lg);
  static BorderRadius get rXl => all(xl);
  static BorderRadius get rPill => all(pill);
}
