import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../auth/sign_out.dart';

/// Builds the shared Dio instance. The Bearer token interceptor reads the
/// current Supabase session at every request — auto-refresh is handled by the
/// Supabase SDK, so we never need to manage tokens ourselves.
Dio buildDioClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (AppConfig.hasSupabase) {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
        }
        return handler.next(options);
      },
      onError: (err, handler) async {
        if (err.response?.statusCode == 401 && AppConfig.hasSupabase) {
          // Token invalid even after auto-refresh: sign out so the UI returns
          // to the login screen instead of looping on 401s. Cleanup also
          // drops the FCM token so the dead device stops getting personal
          // pushes.
          await signOutWithPushCleanup(Supabase.instance.client);
        }
        return handler.next(err);
      },
    ),
  );

  return dio;
}
