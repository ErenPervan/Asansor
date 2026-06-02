import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

import 'core/constants/supabase_constants.dart';
import 'core/providers/connectivity_providers.dart';
import 'core/router/app_router.dart'; // also exports: appRouter, navigatorKey
import 'core/services/notification_service.dart';
import 'core/services/read_cache_service.dart';
import 'core/services/sync_queue_service.dart';
import 'core/theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait to match the target device form-factor.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Environment variables are provided via --dart-define or --dart-define-from-file.

  // Firebase must be initialised before any Firebase service is used.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register the background handler as early as possible — before any other
  // Firebase call.  NotificationService.initialize() also registers it as a
  // safety net, but registering here ensures it is set even before that runs.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Ensure FCM auto-init is enabled so token generation/refresh works reliably.
  await FirebaseMessaging.instance.setAutoInitEnabled(true);

  // Print startup FCM token for quick verification in debug console.
  try {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (kDebugMode) {
      debugPrint('====================================================');
      debugPrint("EREN'IN FCM TOKEN'I: $fcmToken");
      debugPrint('====================================================');
    }
  } catch (e) {
    debugPrint('Token alinirken hata olustu: $e');
  }

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  // Initialise Hive and open all persistent boxes:
  //   • sync queue  – write operations queued while offline
  //   • read caches – last-known-good snapshots for offline reads
  await Hive.initFlutter();

  const secureStorage = FlutterSecureStorage();
  final encryptionKeyString = await secureStorage.read(
    key: 'hive_encryption_key',
  );
  late List<int> encryptionKeyUint8List;
  if (encryptionKeyString == null) {
    final key = Hive.generateSecureKey();
    await secureStorage.write(
      key: 'hive_encryption_key',
      value: base64UrlEncode(key),
    );
    encryptionKeyUint8List = key;
  } else {
    encryptionKeyUint8List = base64Url.decode(encryptionKeyString);
  }

  final cipher = HiveAesCipher(encryptionKeyUint8List);

  await Hive.openBox<String>(syncQueueBoxName, encryptionCipher: cipher);
  await Hive.openBox<String>(elevatorsCacheBoxName, encryptionCipher: cipher);
  await Hive.openBox<String>(tasksCacheBoxName, encryptionCipher: cipher);
  await Hive.openBox<String>(checklistCacheBoxName, encryptionCipher: cipher);
  await Hive.openBox<String>(pastLogsCacheBoxName, encryptionCipher: cipher);
  await Hive.openBox<String>(faultsCacheBoxName, encryptionCipher: cipher);

  // Set up FCM permissions, notification channels, and message listeners.
  await NotificationService.instance.initialize();

  await initializeDateFormatting('tr_TR', null);

  runApp(const ProviderScope(child: AsansorApp()));
}

class AsansorApp extends ConsumerStatefulWidget {
  const AsansorApp({super.key});

  @override
  ConsumerState<AsansorApp> createState() => _AsansorAppState();
}

class _AsansorAppState extends ConsumerState<AsansorApp> {
  @override
  void initState() {
    super.initState();
    // State 1 — terminated: wait for the first frame so GoRouter has rendered
    // its initial route before we attempt to navigate.  At this point
    // `navigatorKey.currentState` is guaranteed to be non-null.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.handleInitialMessage();

      // Keep token synced if the user is already signed in on startup
      if (Supabase.instance.client.auth.currentUser != null) {
        NotificationService.instance.saveTokenToSupabase(
          Supabase.instance.client,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keep the auto-sync listener alive for the entire app lifetime so it
    // fires regardless of which screen is currently shown.  Previously this
    // was only watched inside HomeView, which meant the listener would die
    // whenever the technician navigated to another screen via context.go().
    ref.watch(autoSyncProvider);

    return MaterialApp.router(
      title: 'Asansor',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('de')],
      // `navigatorKey` is owned by `appRouter` (passed via GoRouter constructor).
      // MaterialApp.router does not accept a separate navigatorKey; the key
      // is accessed through `navigatorKey` exported from app_router.dart.
      routerConfig: appRouter,
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  const primaryColor = AppColors.primary;
  final colors = brightness == Brightness.dark
      ? AppThemeColors.dark
      : AppThemeColors.light;

  final base =
      ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
      ).copyWith(
        primary: primaryColor,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryFixed,
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        surface: colors.surface,
        onSurface: colors.onSurface,
        onSurfaceVariant: colors.onSurfaceVariant,
        outline: colors.outline,
        outlineVariant: colors.outlineVariant,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.primaryDark,
        surfaceContainerLowest: colors.surfaceContainerLowest,
        surfaceContainerLow: colors.surfaceContainerLow,
        surfaceContainer: colors.surfaceContainer,
        surfaceContainerHigh: colors.surfaceContainerHigh,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: base,
    scaffoldBackgroundColor: colors.background,

    // ── Typography ──────────────────────────────────────────────────────────
    textTheme: TextTheme(
      displayLarge: TextStyle(
        color: colors.onSurface,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
      ),
      headlineLarge: TextStyle(
        color: colors.onSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        color: colors.onSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(
        color: colors.onSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      bodyLarge: TextStyle(color: colors.onSurface, height: 1.5),
      bodyMedium: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
      bodySmall: TextStyle(color: colors.outline, height: 1.4),
      labelLarge: TextStyle(
        color: colors.onSurface,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    ),

    // ── AppBar ──────────────────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),

    // ── Cards ───────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant, width: 0.8),
      ),
      margin: EdgeInsets.zero,
    ),

    // ── Input fields ────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.outlineVariant, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      labelStyle: TextStyle(color: colors.onSurfaceVariant),
      hintStyle: TextStyle(
        color: colors.outline.withValues(alpha: 0.8),
        fontSize: 14,
      ),
      prefixIconColor: colors.outline,
      suffixIconColor: colors.outline,
    ),

    // ── Filled buttons ──────────────────────────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    ),

    // ── Outlined buttons ────────────────────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    // ── FAB ─────────────────────────────────────────────────────────────────
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: StadiumBorder(),
    ),

    // ── Bottom nav bar ──────────────────────────────────────────────────────
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colors.surface,
      selectedItemColor: primaryColor,
      unselectedItemColor: colors.outline,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    // ── Chips ───────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: colors.surfaceContainer,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    // ── Divider ─────────────────────────────────────────────────────────────
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant,
      thickness: 1,
      space: 1,
    ),

    // ── Dialog ──────────────────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: colors.onSurface,
      ),
    ),

    // ── SnackBar ─────────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      showCloseIcon: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: colors.onSurface,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
    ),
  );
}
