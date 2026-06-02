import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../enums/app_enums.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/admin/providers/profile_providers.dart';
import '../../features/admin/views/admin_calendar_view.dart';
import '../../features/admin/views/admin_dashboard_view.dart';
import '../../features/admin/views/admin_master_calendar_view.dart';
import '../../features/admin/views/elevator_qr_view.dart';
import '../../features/admin/views/technician_management_view.dart';
import '../../features/elevator/views/add_elevator_view.dart';
import '../../features/admin/views/admin_map_view.dart';
import '../../features/admin/views/assign_view.dart';
import '../../features/admin/views/checklist_management_view.dart';
import '../../features/admin/views/user_management_view.dart';
import '../../features/auth/views/loading_view.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/customer/views/customer_dashboard_view.dart';
import '../../features/elevator/views/customer_no_elevator_view.dart';
import '../../features/fault/views/fault_detail_view.dart';
import '../../features/fault/views/fault_list_view.dart';
import '../../features/elevator/views/elevator_detail_view.dart';
import '../../features/elevator/views/elevator_list_view.dart';
import '../../features/elevator/views/home_view.dart';
import '../../features/elevator/views/scanner_view.dart';
import '../../features/maintenance/views/maintenance_log_entry_view.dart';
import '../../features/admin/conflicts/admin_conflict_management_view.dart';
import '../../features/admin/views/admin_statistics_dashboard.dart';

// ── Auth-aware refresh notifier ──────────────────────────────────────────────

/// Bridges the Supabase auth stream into a [ChangeNotifier] so that
/// [GoRouter] re-evaluates its `redirect` on every sign-in / sign-out event.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (AuthState state) {
        if (state.session == null) {
          routerRoleNotifier.clear();
        }
        notifyListeners();
      },
    );
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// Singletons — live as long as the app.
final _authChangeNotifier = _AuthChangeNotifier();

// ── Global navigator key ──────────────────────────────────────────────────────

/// Owned here so that GoRouter, the notification service, and main.dart all
/// share a single reference without circular imports.
///
/// Usage pattern:
///   • Pass to `GoRouter(navigatorKey: navigatorKey, ...)` so GoRouter uses
///     this key for its root Navigator.
///   • Check `navigatorKey.currentState?.mounted == true` before navigating
///     from outside the widget tree (e.g. FCM callbacks).
///   • Call `appRouter.go(route)` — NOT `navigatorKey.currentState!.pushNamed`
///     — to keep GoRouter's redirect guards in the loop.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ── Router ────────────────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: navigatorKey, // ← GoRouter now owns the key's Navigator
    initialLocation: '/',

  // Refresh whenever auth state OR the resolved role changes so that the
  // admin-route guard is re-evaluated as soon as the profile is loaded.
  refreshListenable: Listenable.merge([
    _authChangeNotifier,
    routerRoleNotifier,
  ]),

  /// Guards every navigation attempt.
  ///
  /// Rules:
  /// 1. Unauthenticated → `/login`
  /// 2. Authenticated on `/login` → `/`
  /// 3. Admin-only: non-admin confirmed role on `/admin/*` → `/`
  /// 4. Customer-scoped: customer redirected to their elevator detail page;
  ///    if no elevator is assigned yet → `/customer/no-elevator`.
  ///    Customers are also blocked from all other routes (home, scan, admin).
  ///
  /// Note on rules 3 & 4: while the role is `null` (still loading but user is
  /// authenticated), the user is redirected to `/loading`. Once the role is
  /// confirmed, the router is refreshed and the correct guard fires.
  redirect: (BuildContext context, GoRouterState state) {
    final isAuthenticated = Supabase.instance.client.auth.currentUser != null;
    final loc = state.matchedLocation;
    final isOnLoginPage = loc == '/login';

    // Rule 1 & 2 — auth presence gate.
    if (!isAuthenticated && !isOnLoginPage) return '/login';
    if (isAuthenticated && isOnLoginPage) return '/';

    final role = routerRoleNotifier.role;

    // ── ROLE IS STILL LOADING ──────────────────────────────────────────────
    if (isAuthenticated && role == null) {
      // Block ALL protected routes until the role is confirmed.
      // Show a loading splash instead of leaking any screen.
      if (loc != '/loading') return '/loading';
      return null;
    }

    // If we are on loading but role is now known, go home.
    if (loc == '/loading' && role != null) {
      return '/';
    }

    // Rule 3 — admin route guard.
    if (loc.startsWith('/admin')) {
      if (role != UserRole.admin) return '/';
    }

    // Rule 4 — customer-scoped routing.
    if (role == UserRole.customer) {
      final custElevatorId = routerRoleNotifier.elevatorId;
      final isOnNoElevatorPage = loc == '/customer/no-elevator';
      final isOnDashboard = loc == '/customer/dashboard';

      // The customer is already on the correct page or navigating to a fault — let them through.
      final isOnFaultDetail = loc.startsWith('/fault/');
      if (isOnDashboard || isOnNoElevatorPage || isOnFaultDetail) return null;

      // Send them to their dashboard, or to the "not yet assigned" page.
      if (custElevatorId != null && custElevatorId.isNotEmpty) {
        return '/customer/dashboard';
      }
      return '/customer/no-elevator';
    }

    // Non-customers should never land on customer pages.
    if (loc.startsWith('/customer/')) return '/';

    return null;
  },

  routes: [
    GoRoute(path: '/loading', builder: (context, state) => const LoadingView()),
    GoRoute(path: '/login', builder: (context, state) => const LoginView()),
    GoRoute(path: '/', builder: (context, state) => const HomeView()),
    // `/home` is a stable alias used in FCM notification data payloads so that
    // the edge function does not need to know the root path convention.
    GoRoute(path: '/home', redirect: (_, _) => '/'),
    GoRoute(
      path: '/elevators',
      builder: (context, _) => const ElevatorListView(),
    ),
    GoRoute(path: '/scan', builder: (context, state) => const ScannerView()),
    GoRoute(
      path: '/elevator/:id',
      builder: (_, state) {
        final elevatorId = state.pathParameters['id'] ?? '';
        return ElevatorDetailView(elevatorId: elevatorId);
      },
    ),
    GoRoute(
      path: '/elevator/:id/maintenance/new',
      builder: (_, state) {
        final elevatorId = state.pathParameters['id'] ?? '';
        return MaintenanceLogEntryView(elevatorId: elevatorId);
      },
    ),

    // ── Fault routes ──────────────────────────────────────────────────────
    GoRoute(path: '/faults', builder: (context, _) => const FaultListView()),
    GoRoute(
      path: '/fault/:id',
      builder: (_, state) {
        final faultId = state.pathParameters['id'] ?? '';
        return FaultDetailView(faultId: faultId);
      },
    ),

    // ── Admin / Manager routes ────────────────────────────────────────────
    // All guarded by the role check above (role == 'admin').
    GoRoute(
      path: '/admin/dashboard',
      builder: (context, _) => const AdminDashboardView(),
    ),
    GoRoute(
      path: '/admin/conflicts',
      builder: (context, _) => const AdminConflictManagementView(),
    ),
    GoRoute(path: '/admin/assign', builder: (context, _) => const AssignView()),
    GoRoute(path: '/admin/map', builder: (context, _) => const AdminMapView()),
    GoRoute(
      path: '/admin/users',
      builder: (context, _) => const UserManagementView(),
    ),
    GoRoute(
      path: '/admin/calendar',
      builder: (context, _) => const AdminCalendarView(),
    ),
    GoRoute(
      path: '/admin/master-calendar',
      builder: (context, _) => const AdminMasterCalendarView(),
    ),
    GoRoute(
      path: '/admin/technicians',
      builder: (context, _) => const TechnicianManagementView(),
    ),
    GoRoute(
      path: '/admin/checklists',
      builder: (context, _) => const ChecklistManagementView(),
    ),
    GoRoute(
      path: '/admin/statistics',
      builder: (context, _) => const AdminStatisticsDashboard(),
    ),
    GoRoute(
      path: '/admin/add-elevator',
      builder: (context, _) => const AddElevatorView(),
    ),
    GoRoute(
      path: '/admin/elevator-qr/:id',
      builder: (_, state) {
        final elevatorId = state.pathParameters['id'] ?? '';
        return ElevatorQrView(elevatorId: elevatorId);
      },
    ),

    // ── Customer routes ───────────────────────────────────────────────────
    GoRoute(
      path: '/customer/dashboard',
      builder: (context, _) => const CustomerDashboardView(),
    ),
    GoRoute(
      path: '/customer/no-elevator',
      builder: (context, _) => const CustomerNoElevatorView(),
    ),
  ],
  );
});
