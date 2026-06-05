import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asansor/core/enums/app_capability.dart';
import 'package:asansor/core/services/notification_service.dart';

import 'package:asansor/features/auth/providers/auth_providers.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:asansor/features/fault/providers/fault_providers.dart';
import 'package:asansor/features/admin/providers/admin_providers.dart';
import 'package:asansor/features/admin/providers/profile_providers.dart';
import 'package:asansor/features/admin/providers/admin_analytics_provider.dart';
import 'package:asansor/core/providers/connectivity_providers.dart';
import 'package:asansor/core/widgets/scaffold_with_nav_bar.dart';
import 'package:asansor/features/admin/views/admin_calendar_view.dart';
import 'package:asansor/features/admin/views/admin_dashboard_view.dart';
import 'package:asansor/features/admin/views/admin_master_calendar_view.dart';
import 'package:asansor/features/admin/views/elevator_qr_view.dart';
import 'package:asansor/features/admin/views/technician_management_view.dart';
import 'package:asansor/features/elevator/views/add_elevator_view.dart';
import 'package:asansor/features/admin/views/admin_map_view.dart';
import 'package:asansor/features/admin/views/assign_view.dart';
import 'package:asansor/features/admin/views/checklist_management_view.dart';
import 'package:asansor/features/admin/views/user_management_view.dart';
import 'package:asansor/features/auth/views/loading_view.dart';
import 'package:asansor/features/auth/views/login_view.dart';
import 'package:asansor/features/customer/views/customer_dashboard_view.dart';
import 'package:asansor/features/elevator/views/customer_no_elevator_view.dart';
import 'package:asansor/features/fault/views/fault_detail_view.dart';
import 'package:asansor/features/fault/views/fault_list_view.dart';
import 'package:asansor/features/elevator/views/elevator_detail_view.dart';
import 'package:asansor/features/elevator/views/elevator_list_view.dart';
import 'package:asansor/features/elevator/views/home_view.dart';
import 'package:asansor/features/elevator/views/scanner_view.dart';
import 'package:asansor/features/maintenance/views/maintenance_log_entry_view.dart';
import 'package:asansor/features/admin/conflicts/admin_conflict_management_view.dart';
import 'package:asansor/features/admin/views/admin_statistics_dashboard.dart';

import 'package:asansor/core/views/not_found_view.dart';

// ── App Auth State Machine ───────────────────────────────────────────────────

final appAuthStateProvider = Provider<AuthStateModel>((ref) {
  final userAsync = ref.watch(authStateProvider);

  if (userAsync.isLoading && !userAsync.hasValue) {
    return const AuthStateModel(status: AuthStatus.initial);
  }

  if (userAsync.hasError) {
    return AuthStateModel(
      status: AuthStatus.error,
      errorMessage: userAsync.error.toString(),
    );
  }

  final user = userAsync.value;
  if (user == null) {
    return const AuthStateModel(status: AuthStatus.unauthenticated);
  }

  // User is authenticated, wait for profile.
  final profileAsync = ref.watch(currentProfileProvider);

  if (profileAsync.isLoading && !profileAsync.hasValue) {
    return AuthStateModel(status: AuthStatus.profileLoading, user: user);
  }

  if (profileAsync.hasError) {
    return AuthStateModel(
      status: AuthStatus.error,
      user: user,
      errorMessage: profileAsync.error.toString(),
    );
  }

  final profile = profileAsync.value;
  if (profile == null) {
    return AuthStateModel(
      status: AuthStatus.error,
      user: user,
      errorMessage: 'Profile missing or could not be loaded.',
    );
  }

  return AuthStateModel(
    status: AuthStatus.authorized,
    user: user,
    role: profile.role,
    elevatorId: profile.isCustomer ? profile.elevatorId : null,
  );
});

// ── Auth-aware refresh notifier ──────────────────────────────────────────────

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  ProviderSubscription? _subscription;

  RouterNotifier(this._ref) {
    _subscription = _ref.listen<AuthStateModel>(appAuthStateProvider, (
      previous,
      current,
    ) {
      // Kullanıcı authorized'dan unauthenticated'a geçince tüm user verisi temizlenir
      if (previous?.status == AuthStatus.authorized &&
          current.status == AuthStatus.unauthenticated) {
        _clearUserData();
      }

      if (current.status == AuthStatus.authorized) {
        NotificationService.instance.isAuthorized = true;
        NotificationService.instance.authState = current;
      } else {
        NotificationService.instance.isAuthorized = false;
        NotificationService.instance.authState = null;
      }
      notifyListeners();
    }, fireImmediately: true);
  }

  /// Kullanıcı oturumu kapandığında tüm user-specific Riverpod provider'larını
  /// ve Hive read cache'lerini sıfırlar.
  void _clearUserData() {
    debugPrint('[RouterNotifier] Sign-out detected — clearing user data...');

    // Feature provider'ları sıfırla
    _ref.invalidate(elevatorsProvider);
    _ref.invalidate(activeFaultsProvider);
    _ref.invalidate(allSchedulesProvider);
    _ref.invalidate(myPendingSchedulesProvider);
    _ref.invalidate(adminStatsProvider);
    _ref.invalidate(adminAnalyticsProvider);
    _ref.invalidate(allProfilesProvider);
    _ref.invalidate(
      currentProfileProvider,
    ); // en son — appAuthStateProvider buna bağlı

    // Hive read cache'lerini temizle
    // (Sync queue kasıtlı olarak temizlenmez: offline kuyruktaki işlemler korunur)
    _ref.read(readCacheServiceProvider).clearAll();

    debugPrint('[RouterNotifier] User data cleared.');
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }
}

// ── Global navigator key ──────────────────────────────────────────────────────

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ── Router ────────────────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final routerNotifier = RouterNotifier(ref);

  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    refreshListenable: routerNotifier,
    errorBuilder: (context, state) => const NotFoundView(),
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(appAuthStateProvider);
      final loc = state.matchedLocation;
      final isOnLoginPage = loc == '/login';
      final isOnLoadingPage = loc == '/loading';

      switch (authState.status) {
        case AuthStatus.initial:
          return isOnLoginPage ? null : '/login';

        case AuthStatus.unauthenticated:
          return isOnLoginPage ? null : '/login';

        case AuthStatus.profileLoading:
          return isOnLoadingPage ? null : '/loading';

        case AuthStatus.error:
          // Remain on loading to display the error/retry UI, unless logging out
          if (isOnLoginPage) return null;
          return isOnLoadingPage ? null : '/loading';

        case AuthStatus.authorized:
          final pendingRoute = NotificationService.instance
              .consumePendingRoute();
          if (pendingRoute != null) {
            return pendingRoute;
          }

          // Let authorized users out of the login/loading pages
          if (isOnLoginPage || isOnLoadingPage) {
            return '/';
          }

          // Rule 3 — Admin route guard
          if (loc.startsWith('/admin')) {
            if (!authState.can(AppCapability.accessAdminPanel)) return '/';
          }

          // Rule 4 — Customer-scoped routing
          if (!authState.can(AppCapability.viewAllElevators)) {
            final custElevatorId = authState.elevatorId;
            final isOnNoElevatorPage = loc == '/customer/no-elevator';
            final isOnDashboard = loc == '/customer/dashboard';
            final isOnFaultDetail = loc.startsWith('/fault/');

            // Block access if they have no elevator assigned
            if (custElevatorId == null || custElevatorId.isEmpty) {
              if (isOnNoElevatorPage) return null;
              return '/customer/no-elevator';
            }

            // Customer HAS an elevator. Allow valid pages.
            if (isOnDashboard || isOnFaultDetail || isOnNoElevatorPage) {
              return null;
            }

            // Default redirect for customers with an elevator is their dashboard
            return '/customer/dashboard';
          }

          // Non-customers should never land on customer pages
          if (loc.startsWith('/customer/')) {
            return '/';
          }

          return null;
      }
    },

    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const LoadingView(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginView()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/elevators',
                builder: (context, _) => const ElevatorListView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/faults',
                builder: (context, _) => const FaultListView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/master-calendar',
                builder: (context, _) => const AdminMasterCalendarView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (context, state) => const HomeView()),
            ],
          ),
        ],
      ),
      // `/home` is a stable alias used in FCM notification data payloads so that
      // the edge function does not need to know the root path convention.
      GoRoute(path: '/home', redirect: (_, _) => '/'),

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
