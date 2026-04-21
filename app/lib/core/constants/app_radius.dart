import 'package:flutter/widgets.dart';

class AppRadius {
  AppRadius._();

  static const double xs = 10;
  static const double sm = 14;
  static const double md = 20;
  static const double lg = 26;
  static const double xl = 32;
  static const double pill = 999;

  static BorderRadius all(double v) => BorderRadius.all(Radius.circular(v));
  static BorderRadius get rXs => all(xs);
  static BorderRadius get rSm => all(sm);
  static BorderRadius get rMd => all(md);
  static BorderRadius get rLg => all(lg);
  static BorderRadius get rXl => all(xl);
  static BorderRadius get rPill => all(pill);
}
