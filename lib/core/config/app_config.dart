/// Compile-time environment injection via --dart-define-from-file
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'MISSING_SUPABASE_URL',
  );
  
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'MISSING_SUPABASE_ANON_KEY',
  );
  
  static const flavor = String.fromEnvironment(
    'APP_FLAVOR', 
    defaultValue: 'dev',
  );
  
  static bool get isDev => flavor == 'dev';
  static bool get isStaging => flavor == 'staging';
  static bool get isProd => flavor == 'prod';
}
