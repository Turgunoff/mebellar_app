import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/analytics/analytics_privacy.dart';
import 'package:woody_app/core/auth/auth_repository.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/core/presence/presence_service.dart';

class _MockApi extends Mock implements WoodyApiClient {}

class _MockAuth extends Mock implements AuthRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Box settings;
  late _MockApi api;
  late _MockAuth auth;
  late PresenceService service;

  setUp(() async {
    Hive.init('test_presence_service');
    settings = await Hive.openBox(
      'presence_test_${DateTime.now().microsecondsSinceEpoch}',
    );
    api = _MockApi();
    auth = _MockAuth();
    service = PresenceService(api: api, auth: auth, settingsBox: settings);
  });

  tearDown(() async {
    service.stop();
    await settings.deleteFromDisk();
  });

  test('ping no-ops when analytics privacy is off', () async {
    await settings.put(kAnalyticsCollectionEnabledKey, false);
    when(() => auth.currentUserId).thenReturn('user-1');

    await service.ping();

    verifyNever(
      () => api.post<dynamic>(any(), body: any(named: 'body')),
    );
  });

  test('ping no-ops when logged out', () async {
    await settings.put(kAnalyticsCollectionEnabledKey, true);
    when(() => auth.currentUserId).thenReturn(null);

    await service.ping();

    verifyNever(
      () => api.post<dynamic>(any(), body: any(named: 'body')),
    );
  });
}
