import 'package:dio/dio.dart';

import '../../config/app_config.dart';

/// Builds the legacy raw Dio instance — kept only for callers that still
/// hit Supabase Edge Functions during the migration window. All Woody
/// backend traffic goes through `WoodyApiClient`, which owns its own Dio
/// with the token-refresh interceptor.
///
/// This file is on the deprecation track and will be deleted in the Phase 8
/// Supabase cleanup once no callers remain.
Dio buildDioClient() {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
    ),
  );
}
