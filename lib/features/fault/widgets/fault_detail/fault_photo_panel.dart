import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:flutter/material.dart';

import 'package:asansor/features/fault/widgets/fault_detail/fault_premium_panel.dart';

class FaultPhotoPanel extends StatelessWidget {
  const FaultPhotoPanel({super.key, required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return FaultPremiumPanel(
      title: 'Görsel Kanıt',
      icon: Icons.image_outlined,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          photoUrl,
          width: double.infinity,
          height: 240,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 240,
              color: colors.surfaceContainer,
              child: const LoadingState(),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            height: 160,
            color: colors.surfaceContainer,
            alignment: Alignment.center,
            child: Icon(
              Icons.broken_image_outlined,
              size: 40,
              color: colors.outline,
            ),
          ),
        ),
      ),
    );
  }
}
