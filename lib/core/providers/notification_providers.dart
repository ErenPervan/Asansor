import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/core/services/notification_service.dart';
import 'package:asansor/core/router/app_router.dart';
import 'package:asansor/features/auth/providers/auth_providers.dart';

/// Holds the route path from a tapped notification when the app was launched
/// but the user was not yet fully authorized. The router reads this to navigate
/// once authorized.
final pendingNotificationRouteProvider = StateProvider<String?>((ref) => null);

/// Listens to auth state changes and updates the NotificationService singleton.
/// This decouples the Router from the NotificationService.
final notificationAuthListenerProvider = Provider<void>((ref) {
  final authState = ref.watch(appAuthStateProvider);
  final notif = NotificationService.instance;

  if (authState.status == AuthStatus.authorized) {
    notif.isAuthorized = true;
    notif.authState = authState;

    // Check if there is a pending route to dispatch
    final pending = notif.consumePendingRoute();
    if (pending != null) {
      scheduleMicrotask(() {
        ref.read(pendingNotificationRouteProvider.notifier).state = pending;
      });
    }
  } else {
    notif.isAuthorized = false;
    notif.authState = null;
  }
});
