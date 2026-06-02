import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.of(context).background,
      body: Center(
        child: CircularProgressIndicator(
          color: AppThemeColors.of(context).primary,
        ),
      ),
    );
  }
}
