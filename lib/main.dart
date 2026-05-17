import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'core/providers/connectivity_providers.dart';
import 'core/router/app_router.dart'; // also exports: appRouter, navigatorKey
import 'core/services/notification_service.dart';
import 'core/services/read_cache_service.dart';
import 'core/services/sync_queue_service.dart';

// ── Brand palette (shared with all view-layer files) ──────────────────────────

const kPrimary = Color(0xFFB91C1C);       // Red-700  – brand/headers
const kPrimaryDark = Color(0xFF991B1B);   // Red-800  – gradient endpoint
const kSecondary = Color(0xFFEF4444);     // Red-500  – bright accents/badges
const kBackground = Color(0xFFF9FAFB);   // Slate-50  – scaffold bg
const kSurface = Colors.white;            // card / sheet bg
const kOnSurface = Color(0xFF0F172A);     // Slate-900 – primary text
const kOnSurfaceVariant = Color(0xFF475569); // Slate-600 – secondary text
const kOutline = Color(0xFF94A3B8);       // Slate-400 – disabled text
const kOutlineVariant = Color(0xFFE2E8F0);// Slate-200 – borders/dividers
const kSurfaceContainer = Color(0xFFF1F5F9); // Slate-100 – input/chip bg

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

  await dotenv.load(fileName: '.env');

  // Firebase must be initialised before any Firebase service is used.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register the background handler as early as possible — before any other
  // Firebase call.  NotificationService.initialize() also registers it as a
  // safety net, but registering here ensures it is set even before that runs.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Ensure FCM auto-init is enabled so token generation/refresh works reliably.
  await FirebaseMessaging.instance.setAutoInitEnabled(true);

  // Print startup FCM token for quick verification in debug console.
  try {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    debugPrint('====================================================');
    debugPrint("EREN'IN FCM TOKEN'I: $fcmToken");
    debugPrint('====================================================');
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
  await Hive.openBox<String>(syncQueueBoxName);
  await Hive.openBox<String>(elevatorsCacheBoxName);
  await Hive.openBox<String>(tasksCacheBoxName);

  // Set up FCM permissions, notification channels, and message listeners.
  await NotificationService.instance.initialize();

  await initializeDateFormatting('tr_TR', null);

  runApp(
    const ProviderScope(
      child: AsansorApp(),
    ),
  );
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
        NotificationService.instance.saveTokenToSupabase(Supabase.instance.client);
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
      theme: _buildTheme(),
      // `navigatorKey` is owned by `appRouter` (passed via GoRouter constructor).
      // MaterialApp.router does not accept a separate navigatorKey; the key
      // is accessed through `navigatorKey` exported from app_router.dart.
      routerConfig: appRouter,
    );
  }
}

ThemeData _buildTheme() {
  const primaryColor = kPrimary;
  const seedColor = kPrimary;

  final base = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
  ).copyWith(
    primary: primaryColor,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFFFE4E4), // very light red tint
    onPrimaryContainer: kPrimaryDark,
    secondary: kSecondary,
    onSecondary: Colors.white,
    surface: kSurface,
    onSurface: kOnSurface,
    onSurfaceVariant: kOnSurfaceVariant,
    outline: kOutline,
    outlineVariant: kOutlineVariant,
    error: const Color(0xFFDC2626),
    onError: Colors.white,
    errorContainer: const Color(0xFFFEE2E2),
    onErrorContainer: kPrimaryDark,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF8FAFC),
    surfaceContainer: kSurfaceContainer,
    surfaceContainerHigh: const Color(0xFFE2E8F0),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: base,
    scaffoldBackgroundColor: kBackground,

    // ── Typography ──────────────────────────────────────────────────────────
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: kOnSurface,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
      ),
      headlineLarge: TextStyle(
        color: kOnSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        color: kOnSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(
        color: kOnSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      bodyLarge: TextStyle(color: kOnSurface, height: 1.5),
      bodyMedium: TextStyle(color: kOnSurfaceVariant, height: 1.5),
      bodySmall: TextStyle(color: kOutline, height: 1.4),
      labelLarge: TextStyle(
        color: kOnSurface,
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
      color: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kOutlineVariant, width: 0.8),
      ),
      margin: EdgeInsets.zero,
    ),

    // ── Input fields ────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kOutlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kOutlineVariant, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
      labelStyle: const TextStyle(color: kOnSurfaceVariant),
      hintStyle:
          TextStyle(color: kOutline.withValues(alpha: 0.8), fontSize: 14),
      prefixIconColor: kOutline,
      suffixIconColor: kOutline,
    ),

    // ── Filled buttons ──────────────────────────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
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
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: kSurface,
      selectedItemColor: primaryColor,
      unselectedItemColor: kOutline,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    // ── Chips ───────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: kSurfaceContainer,
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: kOnSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),

    // ── Divider ─────────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: kOutlineVariant,
      thickness: 1,
      space: 1,
    ),

    // ── Dialog ──────────────────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: kOnSurface,
      ),
    ),

    // ── SnackBar ─────────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: kOnSurface,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
    ),
  );
}
