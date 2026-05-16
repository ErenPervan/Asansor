import 'package:flutter/material.dart';

/// Centralised brand palette for "The Red Anchor" (Industrial Dark).
/// Optimized for high-end technical readability and premium aesthetics.
abstract final class AppColors {
  // ── Brand ─────────────────────────────────────────────────────────────────
  static const primary = Color(0xFFB91C1C);          // Brand Red
  static const primaryDark = Color(0xFF7F1D1D);      // Deep Red for gradients
  static const secondary = Color(0xFFEF4444);         // Vibrant Red accent
  
  // ── Surfaces (Dark Industrial) ──────────────────────────────────────────
  static const background = Color(0xFF020617);        // Slate-950 (Deep Base)
  static const surface = Color(0xFF0F172A);           // Slate-900 (Content Card)
  static const surfaceLight = Color(0xFF1E293B);      // Slate-800 (Secondary Card)
  
  static const surfaceContainer = Color(0xFF0F172A);
  static const surfaceContainerLowest = Color(0xFF020617);
  static const surfaceContainerHighest = Color(0xFF334155); // Slate-700
  
  // ── Text ─────────────────────────────────────────────────────────────────
  static const onSurface = Color(0xFFF8FAFC);         // Slate-50 (Crisp White)
  static const onSurfaceVariant = Color(0xFF94A3B8);  // Slate-400 (Muted)
  static const textPrimary = onSurface;
  static const textSecondary = onSurfaceVariant;
  static const textMuted = Color(0xFF64748B);         // Slate-500
  
  static const outline = Color(0xFF475569);           // Slate-600
  static const outlineVariant = Color(0xFF1E293B);    // Slate-800
  
  // ── Semantic ──────────────────────────────────────────────────────────────
  static const error = Color(0xFFEF4444);             // Red-500
  static const errorContainer = Color(0xFF450A0A);    // Dark Red-950
  static const onErrorContainer = Color(0xFFFECACA);  // Light Red-200
  
  static const success = Color(0xFF10B981);           // Emerald-500
  static const successContainer = Color(0xFF064E3B);  // Emerald-950
  static const onSuccessContainer = Color(0xFFD1FAE5); // Emerald-100
  
  static const warning = Color(0xFFF59E0B);           // Amber-500
  static const warningContainer = Color(0xFF78350F);  // Amber-950
}
