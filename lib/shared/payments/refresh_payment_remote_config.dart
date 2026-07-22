import 'package:hive_flutter/hive_flutter.dart';

import '../../config/remote_config.dart';
import '../../core/di/service_locator.dart';
import '../../core/network/woody_api_client.dart';
import '../../core/storage/hive_boxes.dart';

/// Re-fetch admin `payment_methods` (Payme/Click modes + min wallet top-up)
/// using the DI-wired API client. Call when opening a payment surface so
/// toggles apply without an app restart. Failures keep the Hive cache.
Future<void> refreshPaymentRemoteConfig() {
  return RemoteConfig.instance.refreshPaymentMethods(
    sl<WoodyApiClient>(),
    sl<Box>(instanceName: HiveBoxes.settings),
  );
}
