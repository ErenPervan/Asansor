import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/features/admin/providers/profile_providers.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:asansor/features/admin/views/widgets/user_management_header.dart';
import 'package:asansor/features/admin/views/widgets/user_management_tabs.dart';

class UserManagementView extends ConsumerStatefulWidget {
  const UserManagementView({super.key});

  @override
  ConsumerState<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends ConsumerState<UserManagementView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      final next = _searchController.text.trim();
      if (next != _query) setState(() => _query = next);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(allProfilesProvider);
    ref.invalidate(profilesByRoleProvider(UserRole.technician));
    ref.invalidate(profilesByRoleProvider(UserRole.customer));
    ref.invalidate(profilesByRoleProvider(UserRole.admin));
    ref.invalidate(elevatorsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Icon(Icons.manage_accounts_rounded, color: colors.primary),
            const SizedBox(width: 10),
            Text(
              'Kullanıcı Yönetimi',
              style: textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: _refresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          UserManagementHeaderSection(
            searchController: _searchController,
            tabController: _tabs,
            onRefresh: _refresh,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                UserManagementListTab(role: UserRole.technician, query: _query),
                UserManagementCustomerTab(query: _query),
                UserManagementListTab(role: null, query: _query),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
