import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/scheduler.dart' as scheduler;
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:asansor/core/router/app_router.dart'; // exposes appRouter + navigatorKey
import 'package:go_router/go_router.dart';
import 'package:asansor/core/models/notification_payload.dart';
import 'package:asansor/features/auth/providers/auth_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Background handler (MUST be a top-level function, not a class method)
// ─────────────────────────────────────────────────────────────────────────────

/// Called by FCM when a message arrives while the app is in the background
/// or terminated.  Firebase is re-initialised here because this handler runs
/// in an isolate that may not have been started by [main].
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // FCM automatically displays the notification when the app is not in the
  // foreground.  No further action is needed here for notification messages.
}

// ─────────────────────────────────────────────────────────────────────────────
// Android notification channel
// ─────────────────────────────────────────────────────────────────────────────

const _tasksChannelId = 'asansor_tasks';
const _tasksChannelName = 'Görev Bildirimleri';
const _tasksChannelDesc = 'Yeni görev atamaları ve bakım hatırlatmaları';

const _faultsChannelId = 'asansor_faults';
const _faultsChannelName = 'Arıza Bildirimleri';
const _faultsChannelDesc = 'Acil arıza bildirimleri ve güncellemeler';

const _generalChannelId = 'asansor_general';
const _generalChannelName = 'Genel Bildirimler';
const _generalChannelDesc = 'Sistem mesajları ve diğer genel bildirimler';

const _tasksChannel = AndroidNotificationChannel(
  _tasksChannelId,
  _tasksChannelName,
  description: _tasksChannelDesc,
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

const _faultsChannel = AndroidNotificationChannel(
  _faultsChannelId,
  _faultsChannelName,
  description: _faultsChannelDesc,
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

const _generalChannel = AndroidNotificationChannel(
  _generalChannelId,
  _generalChannelName,
  description: _generalChannelDesc,
  importance: Importance.defaultImportance,
  playSound: true,
  enableVibration: true,
);

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

enum NotificationServiceState { notStarted, initializing, ready, failed }

/// Central service for Firebase Cloud Messaging and local notifications.
///
/// ### Lifecycle
/// 1. Call [initialize] once from [main] after `Firebase.initializeApp()`.
///    This registers listeners and channels but does NOT check for an initial
///    notification — that would race with the widget tree build.
/// 2. Call [handleInitialMessage] from [AsansorApp]'s first post-frame
///    callback so that a terminated-app launch via notification tap is handled
///    only after the router is fully ready.
/// 3. Call [saveTokenToSupabase] after the user logs in (or on token refresh).
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  NotificationServiceState _state = NotificationServiceState.notStarted;
  StreamSubscription<String>? _tokenRefreshSub;

  /// True if the user is authenticated and the router has fully processed the auth state.
  bool isAuthorized = false;

  /// Current user's auth state.
  AuthStateModel? authState;

  /// Stores a route received from a notification before the user was authorized or the router was ready.
  String? _pendingRoute;

  /// Consumes and returns the pending route, clearing it.
  String? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  // ── Setup ─────────────────────────────────────────────────────────────────

  /// Sets up permissions, local-notification channels, and message listeners.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  ///
  /// Does NOT check [FirebaseMessaging.instance.getInitialMessage]; call
  /// [handleInitialMessage] after the widget tree is built instead.
  Future<void> initialize() async {
    if (_state == NotificationServiceState.initializing ||
        _state == NotificationServiceState.ready) {
      return;
    }

    _state = NotificationServiceState.initializing;

    try {
      // The background handler MUST be registered before any other Firebase
      // call.  main.dart also registers it before runApp(); this guard makes
      // sure it is set even if initialize() is somehow called first.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Permissions are no longer requested here. Use requestPermission() explicitly.

      // Set foreground notification presentation options for iOS.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Initialise flutter_local_notifications.
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission:
            false, // already requested via FirebaseMessaging
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _localNotifications.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        // State 3 — foreground tap: user tapped a local notification while the
        // app was already open.
        onDidReceiveNotificationResponse: _onLocalNotificationTapped,
      );

      // Create the high-priority Android channels.
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(_tasksChannel);
        await androidPlugin.createNotificationChannel(_faultsChannel);
        await androidPlugin.createNotificationChannel(_generalChannel);
      }

      // State 2 — background tap: app was in the background and the user tapped
      // the system notification to bring it to the foreground.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpenedApp);

      _state = NotificationServiceState.ready;
    } catch (e) {
      _state = NotificationServiceState.failed;
      debugPrint('[FCM] NotificationService initialization failed: $e');
      rethrow;
    }
  }

  // ── Terminated-state tap ──────────────────────────────────────────────────

  /// Checks whether the app was launched by tapping a notification while it
  /// was fully terminated (State 1 — cold start via notification).
  ///
  /// Must be called **after** the widget tree and router are ready.
  /// The correct place is a [WidgetsBinding.addPostFrameCallback] inside
  /// [AsansorApp]'s [State.initState].
  Future<void> handleInitialMessage() async {
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      debugPrint('[FCM] State-1 (terminated) tap detected.');
      handleNotificationClick(initial.data);
    }
  }

  // ── Permissions & Token management ────────────────────────────────────────

  /// Returns true if the user has not yet been asked for notification permissions.
  Future<bool> shouldShowRationale() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.notDetermined;
  }

  /// Requests notification permissions from the OS.
  Future<void> requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  /// Retrieves the current FCM token and writes it to `profiles.fcm_token`
  /// for [userId].  Also listens for future token refreshes.
  ///
  /// Call this immediately after a successful sign-in.
  Future<void> saveTokenToSupabase(SupabaseClient client) async {
    try {
      // Check notification permission status first.
      final settings = await _messaging.getNotificationSettings();
      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      final token = await _messaging.getToken();
      debugPrint('[FCM] Token: $token');

      if (token != null) {
        await _updateToken(client, token);
      } else {
        debugPrint('[FCM] Token is null — permission may be denied.');
      }

      // Keep the token fresh.
      // IMPORTANT: do NOT capture [client] in the closure — it may belong to
      // an already-signed-out session by the time onTokenRefresh fires.
      // Instead, read Supabase.instance.client at the moment the event fires
      // so we always act on the currently authenticated session.
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed: $newToken');
        // Guard: if the user has already signed out in the race window,
        // currentUser will be null — _updateToken will bail out safely.
        final currentClient = Supabase.instance.client;
        unawaited(_updateToken(currentClient, newToken));
      });
    } catch (e) {
      debugPrint('[FCM] saveTokenToSupabase error: $e');
    }
  }

  Future<void> _updateToken(SupabaseClient client, String token) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[FCM] _updateToken: no logged-in user');
      return;
    }
    try {
      await client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);
      debugPrint('[FCM] Token saved to Supabase for user $userId ✅');
    } catch (e) {
      debugPrint('[FCM] _updateToken error: $e');
    }
  }

  // ── Dispatch helpers (call Supabase Edge Function) ────────────────────────

  /// Sends a push notification to a single [toUserId].
  ///
  /// Failures are silently swallowed so the calling operation is never blocked.
  Future<void> notifyUser({
    required SupabaseClient client,
    required String toUserId,
    required String title,
    required String body,
    Map<String, String> data = const {},
  }) async {
    try {
      await client.functions.invoke(
        'send-notification',
        body: {
          'to_user_id': toUserId,
          'title': title,
          'body': body,
          'data': data,
        },
      );
    } catch (_) {}
  }

  /// Sends a push notification to every user with `role = 'admin'`.
  Future<void> notifyAllAdmins({
    required SupabaseClient client,
    required String title,
    required String body,
    Map<String, String> data = const {},
  }) async {
    try {
      await client.functions.invoke(
        'send-notification',
        body: {'to_role': 'admin', 'title': title, 'body': body, 'data': data},
      );
    } catch (_) {}
  }

  // ── Message handlers ──────────────────────────────────────────────────────

  /// Shows a local notification when a message arrives while the app is open.
  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final String type = message.data['type'] as String? ?? '';
    final String route = message.data['route'] as String? ?? '';

    String channelId = _generalChannelId;
    String channelName = _generalChannelName;
    String channelDesc = _generalChannelDesc;
    Importance importance = Importance.defaultImportance;
    Priority priority = Priority.defaultPriority;

    if (type.contains('fault') || route.startsWith('/fault/')) {
      channelId = _faultsChannelId;
      channelName = _faultsChannelName;
      channelDesc = _faultsChannelDesc;
      importance = Importance.max;
      priority = Priority.max;
    } else if (type.contains('task') || route == '/' || route == '/home') {
      channelId = _tasksChannelId;
      channelName = _tasksChannelName;
      channelDesc = _tasksChannelDesc;
      importance = Importance.high;
      priority = Priority.high;
    }

    _localNotifications.show(
      // Use a stable numeric ID derived from the message ID.
      message.messageId?.hashCode ?? DateTime.now().millisecond,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          importance: importance,
          priority: priority,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      // Serialise data so we can navigate on tap.
      payload: jsonEncode(message.data),
    );
  }

  /// Called when the user taps the notification and the app was in the
  /// background (State 2 — not terminated).
  void _onNotificationOpenedApp(RemoteMessage message) {
    debugPrint('[FCM] State-2 (background) tap detected.');
    handleNotificationClick(message.data);
  }

  /// Called when the user taps a *local* notification shown by
  /// [_onForegroundMessage] (State 3 — app was in the foreground).
  void _onLocalNotificationTapped(NotificationResponse response) {
    debugPrint('[FCM] State-3 (foreground) local notification tap detected.');
    final payload = response.payload;
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      handleNotificationClick(data);
    } catch (_) {}
  }

  // ── Unified navigation entry-point ────────────────────────────────────────

  /// Single entry-point called for ALL three notification tap states.
  ///
  /// Safe to call from any context — Firebase platform callbacks, post-frame
  /// callbacks, or directly from [main].  Navigation is always deferred to a
  /// post-frame slot so it never races with an in-progress build or layout.
  ///
  /// Routing priority:
  ///   1. `type == task_assigned`  → `/`  (technician home / task list)
  ///   2. `elevator_id` present    → `/elevator/{id}`
  ///   3. explicit `route` value   → that path verbatim
  ///   4. fallback                 → `/`
  void handleNotificationClick(Map<String, dynamic>? data) {
    if (data == null) return;

    final payload = NotificationPayload.fromJson(data);
    final destination = determineDestination(payload, authState);

    if (!isAuthorized) {
      debugPrint(
        '[FCM] Not authorized yet. Storing pending route: $destination',
      );
      _pendingRoute = destination;
      return;
    }

    _scheduleNavigation(destination);
  }

  // ── Frame-safe navigation ─────────────────────────────────────────────────

  /// Schedules [destination] to be navigated to between frames.
  ///
  /// Why post-frame?  Firebase callbacks can fire mid-frame (during a build
  /// or layout pass).  Calling [GoRouter.go] during a frame causes GoRouter to
  /// silently discard the navigation.  A post-frame callback is the only safe
  /// window guaranteed to be outside any frame phase.
  ///
  /// Why [navigatorKey.currentState]?  It is non-null only when GoRouter's
  /// root Navigator is actually mounted in the widget tree.  If it is null
  /// (e.g. the app has not rendered its first frame yet), we re-schedule for
  /// the next frame rather than silently dropping the navigation.
  void _scheduleNavigation(String destination, {int retries = 0}) {
    void attempt() {
      final mounted = navigatorKey.currentState?.mounted ?? false;
      if (mounted) {
        debugPrint('[FCM] Navigating → $destination ✅');
        if (navigatorKey.currentContext != null) {
          GoRouter.of(navigatorKey.currentContext!).go(destination);
        }
      } else if (retries < 5) {
        // Navigator not ready yet — retry after the next frame.
        debugPrint('[FCM] Navigator not mounted, retry ${retries + 1}/5…');
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scheduleNavigation(destination, retries: retries + 1),
        );
      } else {
        debugPrint('[FCM] Navigator never became ready — navigation dropped.');
      }
    }

    // If we are already between frames (idle), navigate immediately.
    // Otherwise wait for the next frame boundary.
    if (scheduler.SchedulerBinding.instance.schedulerPhase ==
        scheduler.SchedulerPhase.idle) {
      attempt();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
    }
  }
}
