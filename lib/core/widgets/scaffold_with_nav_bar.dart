import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_bottom_nav_bar.dart';
import '../../features/elevator/widgets/home/home_qr_fab.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: QrFab(onPressed: () => context.push('/scan')),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AppBottomNavBar(navigationShell: navigationShell),
    );
  }
}
