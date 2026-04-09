import 'package:flutter_dotenv/flutter_dotenv.dart';

// Values are loaded at runtime from the `.env` file.
// Fill in your credentials in `.env` (see `.env.example` for the format).
// NEVER commit `.env` to version control.
class SupabaseConstants {
  SupabaseConstants._();

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? (throw Exception('SUPABASE_URL is not set in .env'));

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? (throw Exception('SUPABASE_ANON_KEY is not set in .env'));
}
