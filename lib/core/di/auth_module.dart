import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../analytics/analytics_service.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_repository.dart';
import '../notifications/notification_handler.dart';
import '../notifications/push_service.dart';
import '../platform/messaging_facade.dart';
import '../storage/hive_boxes.dart';

/// Root-scope authentication + push wiring. Depends on `SupabaseClient` /
/// `Dio` / the `pending_route` box registered by [registerCoreModule].
void registerAuthModule(GetIt sl) {
  if (sl.isRegistered<SupabaseClient>()) {
    sl.registerLazySingleton<AuthRepository>(
      () => AuthRepository(sl<SupabaseClient>(), sl<Dio>()),
      dispose: (repo) => repo.dispose(),
    );
  }

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
      supabase: sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null,
    ),
  );

  // Single global auth listener — survives customer<->seller mode switches.
  sl.registerSingleton<AuthCubit>(
    AuthCubit(
      sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null,
      analytics: sl.isRegistered<AnalyticsService>()
          ? sl<AnalyticsService>()
          : null,
    ),
    dispose: (c) => c.close(),
  );
}
