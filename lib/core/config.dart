import 'package:supabase_flutter/supabase_flutter.dart';

/// Paste your values from Supabase: Connect dialog or Settings > API Keys.
/// The publishable key is safe inside the app (Row Level Security protects data).
/// NEVER put the secret / service_role key here.
class AppConfig {
  static const supabaseUrl = 'https://exempcepcoqusewmwjuw.supabase.co';
  static const supabaseKey = 'sb_publishable_jGSNJj9pf2x0Guw6YZNpog_JzZgQNEQ';
}

SupabaseClient get supabase => Supabase.instance.client;
