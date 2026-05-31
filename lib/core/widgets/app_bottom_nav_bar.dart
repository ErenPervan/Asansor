import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../features/admin/providers/profile_providers.dart';

class AppBottomNavBar extends ConsumerWidget {
  const AppBottomNavBar({super.key, required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider) ?? 'technician';
    final isAdmin = role == 'admin';
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
              isActive: currentIndex == 0,
              onPressed: () => context.go('/elevators'),
            ),
            _NavItem(
              icon: Icons.error_outline,
              label: 'Arızalar',
              isActive: currentIndex == 1,
              onPressed: () => context.go('/faults'),
            ),
            const SizedBox(width: 56), // spacer for the centre FAB
            _NavItem(
              icon: Icons.event_note_outlined,
              label: 'Program',
              isActive: currentIndex == 2,
              onPressed: isAdmin
                  ? () => context.go('/admin/master-calendar')
                  : null,
            ),
            _NavItem(
              icon: Icons.history,
              label: 'Günlük',
              isActive: currentIndex == 3,
              onPressed: () => context.go('/'),
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
    final color = isActive ? AppColors.primary : const Color(0xFF94A3B8);
    
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
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
