import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/enums/app_capability.dart';
import '../../core/theme/app_colors.dart';
import '../../features/admin/providers/profile_providers.dart';

class AppBottomNavBar extends ConsumerWidget {
  const AppBottomNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final canViewSchedule =
        profile?.can(AppCapability.viewAdminCalendar) ?? false;
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavItem(
              icon: Icons.domain_outlined,
              label: 'Filo',
              isActive: navigationShell.currentIndex == 0,
              onPressed: () => _goBranch(0),
            ),
            _NavItem(
              icon: Icons.error_outline,
              label: 'Arızalar',
              isActive: navigationShell.currentIndex == 1,
              onPressed: () => _goBranch(1),
            ),
            const SizedBox(width: 56), // spacer for the centre FAB
            _NavItem(
              icon: Icons.event_note_outlined,
              label: 'Program',
              isActive: navigationShell.currentIndex == 2,
              onPressed: canViewSchedule ? () => _goBranch(2) : null,
            ),
            _NavItem(
              icon: Icons.history,
              label: 'Günlük',
              isActive: navigationShell.currentIndex == 3,
              onPressed: () => _goBranch(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    final colors = AppThemeColors.of(context);
    final color = isActive ? colors.primary : colors.outline;

    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: color,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );

    if (isDisabled) {
      return Tooltip(
        message: 'Yalnızca yöneticiler erişebilir',
        child: Opacity(
          opacity: 0.4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: child,
          ),
        ),
      );
    }

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: child,
      ),
    );
  }
}
