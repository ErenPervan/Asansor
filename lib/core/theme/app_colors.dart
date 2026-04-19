import 'package:flutter/material.dart';

/// Centralised brand palette. Import this file in any view layer file that
/// needs to reference colours directly (rather than via `Theme.of(context)`).
///
/// Naming convention follows Material Design 3 role names where possible.
abstract final class AppColors {
  // ── Brand ─────────────────────────────────────────────────────────────────
  static const primary = Color(0xFFB91C1C);          // Red-700
  static const primaryDark = Color(0xFF991B1B);       // Red-800  (gradient)
  static const secondary = Color(0xFFEF4444);         // Red-500  (bright)

  // ── Surfaces ──────────────────────────────────────────────────────────────
  static const background = Color(0xFFF9FAFB);        // Slate-50
  static const surface = Colors.white;
  static const surfaceContainer = Color(0xFFF1F5F9);  // Slate-100
  static const surfaceContainerLowest = Colors.white;
  static const surfaceContainerHighest = Color(0xFFE2E8F0); // Slate-200

  // ── Text ─────────────────────────────────────────────────────────────────
  static const onSurface = Color(0xFF0F172A);         // Slate-900
  static const onSurfaceVariant = Color(0xFF475569);  // Slate-600
  static const outline = Color(0xFF94A3B8);           // Slate-400
  static const outlineVariant = Color(0xFFE2E8F0);    // Slate-200

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const error = Color(0xFFDC2626);             // Red-600
  static const errorContainer = Color(0xFFFEE2E2);   // Red-100
  static const onErrorContainer = Color(0xFF991B1B);

  static const success = Color(0xFF166534);           // Green-800
  static const successContainer = Color(0xFFDCFCE7);  // Green-100

  static const warning = Color(0xFF92400E);           // Amber-800
  static const warningContainer = Color(0xFFFEF3C7);  // Amber-100
}
