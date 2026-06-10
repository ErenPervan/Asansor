import 'dart:io';
import 'package:flutter/material.dart';

final bool isCI = Platform.environment.containsKey('CI') || Platform.environment.containsKey('GITHUB_ACTIONS');
/// Minimal MaterialApp wrapper for golden and widget tests.
/// Provides a default ThemeData and a Scaffold.
Widget pumpWithTheme(Widget child) {
  return MaterialApp(
    theme: ThemeData.light(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF9FAFB), // AppColors.background
    ),
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );
}
