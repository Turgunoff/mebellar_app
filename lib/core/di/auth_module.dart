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
import '../services/facebook_analytics_service.dart';
import '../notifications/app_badge_service.dart';
import '../notifications/notification_handler.dart';
import '../notifications/push_service.dart';
import '../presence/presence_service.dart';
import '../platform/messaging_facade.dart';
import '../storage/hive_boxes.dart';

/// Root-scope authentication + push wiring. Depends on `WoodyApiClient` /
/// `TokenStore` / the `pending_route` box registered by [registerCoreModule].
void registerAuthModule(GetIt sl) {
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepository(api: sl<WoodyApiClient>(), tokens: sl<TokenStore>()),
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
      // Device-token registration goes through the Woody REST endpoint.
      woodyApi: AppConfig.hasWoodyApi ? sl<WoodyApiClient>() : null,
      // Root singleton (registered by core_module, before this) so a
      // foreground push can paint the launcher badge immediately.
      badge: sl<AppBadgeService>(),
    ),
  );

  if (AppConfig.hasWoodyApi) {
    sl.registerLazySingleton<PresenceService>(
      () => PresenceService(
        api: sl<WoodyApiClient>(),
        auth: sl<AuthRepository>(),
        settingsBox: sl<Box>(instanceName: HiveBoxes.settings),
      ),
      dispose: (s) => s.stop(),
    );
  }

  // Single global auth listener — survives customer<->seller mode switches.
  sl.registerSingleton<AuthCubit>(
    AuthCubit(
      tokens: sl<TokenStore>(),
      analytics: sl.isRegistered<AnalyticsService>()
          ? sl<AnalyticsService>()
          : null,
      realtime: sl.isRegistered<WoodyRealtimeService>()
          ? sl<WoodyRealtimeService>()
          : null,
      // Lookup closure, not an instance: this is an EAGER singleton and
      // FacebookAnalyticsService is registered later, by catalog_module.
      facebookAnalyticsLookup: () => sl<FacebookAnalyticsService>(),
    ),
    dispose: (c) => c.close(),
  );
}
