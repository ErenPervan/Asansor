import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'shimmer_card.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.isList = true,
    this.count = 3,
    this.height = 100,
  });

  final bool isList;
  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (!isList) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ShimmerCard(height: height),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: count,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => ShimmerCard(height: height),
    );
  }
}
