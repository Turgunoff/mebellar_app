import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/app_config.dart';
import '../analytics/analytics_service.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_repository.dart';
import '../network/token_store.dart';
import '../network/woody_api_client.dart';
import '../realtime/woody_realtime_service.dart';
import '../notifications/notification_handler.dart';
import '../notifications/push_service.dart';
import '../platform/messaging_facade.dart';
import '../storage/hive_boxes.dart';

/// Root-scope authentication + push wiring. Depends on `WoodyApiClient` /
/// `TokenStore` / the `pending_route` box registered by [registerCoreModule].
void registerAuthModule(GetIt sl) {
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepository(
      api: sl<WoodyApiClient>(),
      tokens: sl<TokenStore>(),
    ),
    dispose: (repo) => repo.dispose(),
  );

  sl.registerLazySingleton<NotificationHandler>(
    () => NotificationHandler(sl<Box>(instanceName: HiveBoxes.pendingRoute)),
  );

  // FCM push handler — registration only wires the dependency; no network
  // calls happen until `sl<PushService>().initialise()` is awaited.
  sl.registerLazySingleton<PushService>(
    () => PushService(
      messaging: FirebaseMessagingFacade(),
      localNotifications: FlutterLocalNotificationsPlugin(),
      notificationHandler: sl<NotificationHandler>(),
      // Woody REST takes precedence over Supabase for device-token
      // registration. `supabase` stays as the fallback for builds without
      // a configured Woody backend (dev / integration tests).
      supabase: null,
      woodyApi: AppConfig.hasWoodyApi ? sl<WoodyApiClient>() : null,
    ),
  );

  // Single global auth listener — survives customer<->seller mode switches.
  sl.registerSingleton<AuthCubit>(
    AuthCubit(
      tokens: sl<TokenStore>(),
      analytics:
          sl.isRegistered<AnalyticsService>() ? sl<AnalyticsService>() : null,
      realtime: sl.isRegistered<WoodyRealtimeService>()
          ? sl<WoodyRealtimeService>()
          : null,
    ),
    dispose: (c) => c.close(),
  );
}
