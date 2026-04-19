import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import '../../features/admin/views/user_management_view.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/elevator/views/customer_no_elevator_view.dart';
import '../../features/fault/views/fault_detail_view.dart';
import '../../features/elevator/views/elevator_detail_view.dart';
import '../../features/elevator/views/elevator_list_view.dart';
import '../../features/elevator/views/home_view.dart';
import '../../features/elevator/views/scanner_view.dart';

// ── Auth-aware refresh notifier ──────────────────────────────────────────────

/// Bridges the Supabase auth stream into a [ChangeNotifier] so that
/// [GoRouter] re-evaluates its `redirect` on every sign-in / sign-out event.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (AuthState _) => notifyListeners(),
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

final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,   // ← GoRouter now owns the key's Navigator
  initialLocation: '/',

  // Refresh whenever auth state OR the resolved role changes so that the
  // admin-route guard is re-evaluated as soon as the profile is loaded.
  refreshListenable:
      Listenable.merge([_authChangeNotifier, routerRoleNotifier]),

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
  /// authenticated) the request is allowed through to avoid a redirect loop.
  /// The router is refreshed the moment [routerRoleNotifier] emits a confirmed
  /// role, so the correct guard fires on the next evaluation.
  redirect: (BuildContext context, GoRouterState state) {
    final isAuthenticated =
        Supabase.instance.client.auth.currentUser != null;
    final loc = state.matchedLocation;
    final isOnLoginPage = loc == '/login';

    // Rule 1 & 2 — auth presence gate.
    if (!isAuthenticated && !isOnLoginPage) return '/login';
    if (isAuthenticated && isOnLoginPage) return '/';

    final role = routerRoleNotifier.role;

    // Rule 3 — admin route guard.
    if (loc.startsWith('/admin')) {
      if (role != null && role != 'admin') return '/';
    }

    // Rule 4 — customer-scoped routing.
    if (role == 'customer') {
      final custElevatorId = routerRoleNotifier.elevatorId;
      final isOnNoElevatorPage = loc == '/customer/no-elevator';
      final isOnTheirElevator = custElevatorId != null &&
          loc == '/elevator/$custElevatorId';

      // The customer is already on the correct page or navigating to a fault — let them through.
      final isOnFaultDetail = loc.startsWith('/fault/');
      if (isOnTheirElevator || isOnNoElevatorPage || isOnFaultDetail) return null;

      // Send them to their elevator, or to the "not yet assigned" page.
      if (custElevatorId != null && custElevatorId.isNotEmpty) {
        return '/elevator/$custElevatorId';
      }
      return '/customer/no-elevator';
    }

    // Non-customers should never land on the no-elevator page.
    if (loc == '/customer/no-elevator') return '/';

    return null;
  },

  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginView()),
    GoRoute(path: '/', builder: (context, state) => const HomeView()),
    // `/home` is a stable alias used in FCM notification data payloads so that
    // the edge function does not need to know the root path convention.
    GoRoute(
      path: '/home',
      redirect: (_, _) => '/',
    ),
    GoRoute(path: '/elevators', builder: (context, _) => const ElevatorListView()),
    GoRoute(path: '/scan', builder: (context, state) => const ScannerView()),
    GoRoute(
      path: '/elevator/:id',
      builder: (_, state) {
        final elevatorId = state.pathParameters['id'] ?? '';
        return ElevatorDetailView(elevatorId: elevatorId);
      },
    ),

    // ── Fault routes ──────────────────────────────────────────────────────
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
      path: '/admin/assign',
      builder: (context, _) => const AssignView(),
    ),
    GoRoute(
      path: '/admin/map',
      builder: (context, _) => const AdminMapView(),
    ),
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
      path: '/customer/no-elevator',
      builder: (context, _) => const CustomerNoElevatorView(),
    ),
  ],
);
