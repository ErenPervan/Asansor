import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/features/admin/views/widgets/user_management_helpers.dart';

class UserManagementHeaderSection extends StatelessWidget {
  const UserManagementHeaderSection({
    super.key,
    required this.searchController,
    required this.tabController,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final TabController tabController;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: const Border(bottom: BorderSide(color: panelLine)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 720;
                  return Flex(
                    direction: compact ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: compact
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: compact ? 0 : 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kullanıcı Yönetimi',
                              style: textTheme.headlineSmall?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Platform erişimlerini, operasyonel rolleri ve müşteri asansör bağlantılarını yönetin.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (compact) const SizedBox(height: AppSpacing.md),
                      _RefreshButton(onRefresh: onRefresh),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              _SearchBox(controller: searchController),
              const SizedBox(height: AppSpacing.md),
              TabBar(
                controller: tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: colors.primary,
                indicatorWeight: 3,
                labelColor: colors.primary,
                unselectedLabelColor: colors.onSurfaceVariant,
                labelStyle: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.engineering_rounded, size: 18),
                    text: 'Teknisyenler',
                  ),
                  Tab(
                    icon: Icon(Icons.apartment_rounded, size: 18),
                    text: 'Müşteriler',
                  ),
                  Tab(
                    icon: Icon(Icons.groups_rounded, size: 18),
                    text: 'Tüm Kullanıcılar',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return OutlinedButton.icon(
      onPressed: onRefresh,
      icon: const Icon(Icons.refresh_rounded, size: 19),
      label: const Text('Yenile'),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.primary,
        backgroundColor: colors.surface,
        side: const BorderSide(color: panelLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Kullanıcı ara: isim, e-posta, telefon veya asansör',
        prefixIcon: Icon(Icons.search_rounded, color: colors.outline),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: controller.clear,
              ),
        filled: true,
        fillColor: colors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
    );
  }
}
