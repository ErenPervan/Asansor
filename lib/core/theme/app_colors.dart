import 'package:flutter/material.dart';

/// Centralised brand palette for the Asansör application.
///
/// Import this file in any view-layer file that needs to reference colours
/// directly (rather than via `Theme.of(context)`).
///
/// Naming convention follows Material Design 3 role names where possible.
abstract final class AppColors {
  // ── Brand ─────────────────────────────────────────────────────────────────
  static const primary = Color(0xFFB91C1C);          // Red-700
  static const primaryDark = Color(0xFF991B1B);       // Red-800  (gradient)
  static const secondary = Color(0xFFEF4444);         // Red-500  (bright)
  static const primaryFixed = Color(0xFFFFE4E4);      // very light red tint

  // ── Surfaces ──────────────────────────────────────────────────────────────
  static const background = Color(0xFFF9FAFB);        // Slate-50
  static const surface = Colors.white;
  static const surfaceContainerLowest = Colors.white;
  static const surfaceContainerLow = Color(0xFFF8FAFC);
  static const surfaceContainer = Color(0xFFF1F5F9);  // Slate-100
  static const surfaceContainerHigh = Color(0xFFE2E8F0); // Slate-200

  // ── Dark surfaces ─────────────────────────────────────────────────────────
  static const backgroundDark = Color(0xFF0B0F14);
  static const surfaceDark = Color(0xFF111827);
  static const surfaceContainerLowestDark = Color(0xFF0F172A);
  static const surfaceContainerLowDark = Color(0xFF111827);
  static const surfaceContainerDark = Color(0xFF1F2937);
  static const surfaceContainerHighDark = Color(0xFF374151);

  // ── Text / On-Surface ─────────────────────────────────────────────────────
  static const onSurface = Color(0xFF0F172A);         // Slate-900
  static const onSurfaceVariant = Color(0xFF475569);  // Slate-600
  static const outline = Color(0xFF94A3B8);           // Slate-400
  static const outlineVariant = Color(0xFFE2E8F0);    // Slate-200

  // ── Dark text / on-surface ────────────────────────────────────────────────
  static const onSurfaceDark = Color(0xFFE2E8F0);
  static const onSurfaceVariantDark = Color(0xFF94A3B8);
  static const outlineDark = Color(0xFF64748B);
  static const outlineVariantDark = Color(0xFF334155);

  // ── Semantic — Error ──────────────────────────────────────────────────────
  static const error = Color(0xFFDC2626);             // Red-600
  static const errorContainer = Color(0xFFFEE2E2);   // Red-100
  static const onErrorContainer = Color(0xFF991B1B);
  static const onError = Colors.white;

  // ── Semantic — Success ────────────────────────────────────────────────────
  static const success = Color(0xFF166534);           // Green-800
  static const successLight = Color(0xFF16A34A);      // Green-600
  static const successContainer = Color(0xFFDCFCE7);  // Green-100

  // ── Semantic — Warning ────────────────────────────────────────────────────
  static const warning = Color(0xFF92400E);           // Amber-800
  static const warningLight = Color(0xFFD97706);      // Amber-600
  static const warningContainer = Color(0xFFFEF3C7);  // Amber-100

  // ── Admin Dashboard — Chart Accents ────────────────────────────────────────
  static const navy = Color(0xFF0F2040);
  static const navyMid = Color(0xFF1B3A6B);
  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFEFF6FF);
  static const blueAccent = Color(0xFF3B82F6);

  // ── Quick Actions ───────────────────────────────────────────────────────────
  static const teal = Color(0xFF0D9488);
  static const tealSurface = Color(0xFFECFDF5);
  static const violet = Color(0xFF7C3AED);
  static const violetSurface = Color(0xFFF5F3FF);
}

class AppThemeColors {
  const AppThemeColors({
    required this.primary,
    required this.primaryDark,
    required this.secondary,
    required this.primaryFixed,
    required this.background,
    required this.surface,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.error,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.onError,
    required this.success,
    required this.successLight,
    required this.successContainer,
    required this.warning,
    required this.warningLight,
    required this.warningContainer,
    required this.navy,
    required this.navyMid,
    required this.blue,
    required this.blueSoft,
    required this.blueAccent,
    required this.teal,
    required this.tealSurface,
    required this.violet,
    required this.violetSurface,
  });

  final Color primary;
  final Color primaryDark;
  final Color secondary;
  final Color primaryFixed;
  final Color background;
  final Color surface;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color error;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color onError;
  final Color success;
  final Color successLight;
  final Color successContainer;
  final Color warning;
  final Color warningLight;
  final Color warningContainer;
  final Color navy;
  final Color navyMid;
  final Color blue;
  final Color blueSoft;
  final Color blueAccent;
  final Color teal;
  final Color tealSurface;
  final Color violet;
  final Color violetSurface;

  static const light = AppThemeColors(
    primary: AppColors.primary,
    primaryDark: AppColors.primaryDark,
    secondary: AppColors.secondary,
    primaryFixed: AppColors.primaryFixed,
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceContainerLowest: AppColors.surfaceContainerLowest,
    surfaceContainerLow: AppColors.surfaceContainerLow,
    surfaceContainer: AppColors.surfaceContainer,
    surfaceContainerHigh: AppColors.surfaceContainerHigh,
    onSurface: AppColors.onSurface,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
    error: AppColors.error,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    onError: AppColors.onError,
    success: AppColors.success,
    successLight: AppColors.successLight,
    successContainer: AppColors.successContainer,
    warning: AppColors.warning,
    warningLight: AppColors.warningLight,
    warningContainer: AppColors.warningContainer,
    navy: AppColors.navy,
    navyMid: AppColors.navyMid,
    blue: AppColors.blue,
    blueSoft: AppColors.blueSoft,
    blueAccent: AppColors.blueAccent,
    teal: AppColors.teal,
    tealSurface: AppColors.tealSurface,
    violet: AppColors.violet,
    violetSurface: AppColors.violetSurface,
  );

  static const dark = AppThemeColors(
    primary: AppColors.primary,
    primaryDark: AppColors.primaryDark,
    secondary: AppColors.secondary,
    primaryFixed: AppColors.primaryFixed,
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    surfaceContainerLowest: AppColors.surfaceContainerLowestDark,
    surfaceContainerLow: AppColors.surfaceContainerLowDark,
    surfaceContainer: AppColors.surfaceContainerDark,
    surfaceContainerHigh: AppColors.surfaceContainerHighDark,
    onSurface: AppColors.onSurfaceDark,
    onSurfaceVariant: AppColors.onSurfaceVariantDark,
    outline: AppColors.outlineDark,
    outlineVariant: AppColors.outlineVariantDark,
    error: AppColors.error,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    onError: AppColors.onError,
    success: AppColors.success,
    successLight: AppColors.successLight,
    successContainer: AppColors.successContainer,
    warning: AppColors.warning,
    warningLight: AppColors.warningLight,
    warningContainer: AppColors.warningContainer,
    navy: AppColors.navy,
    navyMid: AppColors.navyMid,
    blue: AppColors.blue,
    blueSoft: AppColors.blueSoft,
    blueAccent: AppColors.blueAccent,
    teal: AppColors.teal,
    tealSurface: AppColors.tealSurface,
    violet: AppColors.violet,
    violetSurface: AppColors.violetSurface,
  );

  static AppThemeColors of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dark : light;
  }
}
