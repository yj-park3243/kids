import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  static const Color _pinkShadow = Color(0xFFE84C88);

  // Glass card (soft)
  static List<BoxShadow> get glass => [
        BoxShadow(
          color: _pinkShadow.withValues(alpha: 0.06),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: _pinkShadow.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  // Glass card pink (stronger)
  static List<BoxShadow> get glassPink => [
        BoxShadow(
          color: _pinkShadow.withValues(alpha: 0.10),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: _pinkShadow.withValues(alpha: 0.12),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ];

  // Pink CTA button
  static List<BoxShadow> get pinkCta => [
        BoxShadow(
          color: _pinkShadow.withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  // Bottom tab bar
  static List<BoxShadow> get tabBar => [
        BoxShadow(
          color: _pinkShadow.withValues(alpha: 0.14),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ];

  // FAB
  static List<BoxShadow> get fab => [
        BoxShadow(
          color: _pinkShadow.withValues(alpha: 0.4),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}
