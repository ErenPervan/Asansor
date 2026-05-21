// Values are provided at compile time using --dart-define or --dart-define-from-file.
// Example: flutter run --dart-define-from-file=.env
class SupabaseConstants {
  SupabaseConstants._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'MISSING_SUPABASE_URL',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'MISSING_SUPABASE_ANON_KEY',
  );
}
