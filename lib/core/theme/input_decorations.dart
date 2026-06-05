import 'package:flutter/material.dart';

import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';

InputDecoration appInputDecoration({
  String? label,
  String? hint,
  String? helper,
  Widget? prefixIcon,
  Widget? suffixIcon,
  Color fillColor = AppColors.surfaceContainerLowest,
  double radius = 14,
}) {
  final borderRadius = BorderRadius.circular(radius);
  final defaultBorder = BorderSide(
    color: AppColors.outlineVariant.withValues(alpha: 0.5),
  );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: fillColor,
    border: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: defaultBorder,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: defaultBorder,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: 14,
    ),
  );
}
