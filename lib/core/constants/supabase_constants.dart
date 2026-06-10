// Values are provided at compile time using --dart-define or --dart-define-from-file.
// Example: flutter run --dart-define-from-file=.env
class SupabaseConstants {
  SupabaseConstants._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static void validate() {
    final missing = <String>[
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
    ];

    if (missing.isNotEmpty) {
      throw StateError(
        'Missing required compile-time environment values: '
        '${missing.join(', ')}. Pass them with --dart-define or '
        '--dart-define-from-file=.env.',
      );
    }
  }
}
