import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';

/// Initialises the Supabase SDK if credentials are present. In dev/local builds
/// without Supabase keys, returns `null` so the rest of the app can still boot
/// (auth screens will simply show a "backend not configured" message).
Future<SupabaseClient?> initSupabase() async {
  if (!AppConfig.hasSupabase) {
    return null;
  }
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  return Supabase.instance.client;
}
