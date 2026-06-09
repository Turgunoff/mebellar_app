import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/core/notifications/notification_handler.dart';
import 'package:woody_app/core/notifications/push_service.dart';
import 'package:woody_app/core/platform/messaging_facade.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

class _MockLocalNotifications extends Mock
    implements FlutterLocalNotificationsPlugin {}

class _MockBox extends Mock implements Box<dynamic> {}

const _json = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

/// Fails every `POST /push/device-tokens` with a 500 so the token upsert
/// throws — the path a rotation hits when the backend is briefly down.
class _FailingAdapter implements HttpClientAdapter {
  int deviceTokenHits = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.path.endsWith('/push/device-tokens')) {
      deviceTokenHits++;
      return ResponseBody.fromString('{"detail":"down"}', 500, headers: _json);
    }
    return ResponseBody.fromString('{}', 200, headers: _json);
  }
}

/// Drives only the streams/getters [PushService.bootstrap] touches; the rest
/// of the FCM surface is unused on the token-refresh path.
class _FakeMessaging implements MessagingFacade {
  final _tokenRefresh = StreamController<String>.broadcast();

  void rotate(String token) => _tokenRefresh.add(token);

  Future<void> dispose() => _tokenRefresh.close();

  @override
  Stream<String> get onTokenRefresh => _tokenRefresh.stream;

  @override
  Stream<RemoteMessage> get onMessage => Stream<RemoteMessage>.empty();

  @override
  Stream<RemoteMessage> get onMessageOpenedApp => Stream<RemoteMessage>.empty();

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;

  @override
  Future<String?> getToken() async => 'unused-on-refresh-path';

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool badge = true,
    bool sound = true,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> setForegroundNotificationPresentationOptions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> subscribeToTopic(String topic) => throw UnimplementedError();

  @override
  Future<void> unsubscribeFromTopic(String topic) => throw UnimplementedError();
}

WoodyApiClient _client(HttpClientAdapter adapter, TokenStore store) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://test.local',
      validateStatus: (status) => status != null && status < 500,
    ),
  )..httpClientAdapter = adapter;
  return WoodyApiClient(tokens: store, dio: dio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => registerFallbackValue(const InitializationSettings()));

  late _MockSecureStorage storage;
  late TokenStore store;
  late _MockLocalNotifications localNotifications;

  setUp(() async {
    storage = _MockSecureStorage();
    final mem = <String, String>{};
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((i) async => mem[i.namedArguments[#key] as String]);
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((i) async {
      mem[i.namedArguments[#key] as String] =
          i.namedArguments[#value] as String;
    });
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((i) async {
      mem.remove(i.namedArguments[#key] as String);
    });
    store = TokenStore(storage);
    await store.write(
      const TokenPair(accessToken: 'OLD', refreshToken: 'OLDREFRESH'),
    );

    localNotifications = _MockLocalNotifications();
    when(() => localNotifications.initialize(
          any(),
          onDidReceiveNotificationResponse:
              any(named: 'onDidReceiveNotificationResponse'),
        )).thenAnswer((_) async => true);
    when(() => localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()).thenReturn(null);
  });

  test(
    'a token rotation whose upsert fails (5xx) is swallowed, not rethrown into '
    'the zone',
    () async {
      final adapter = _FailingAdapter();
      final messaging = _FakeMessaging();
      final service = PushService(
        messaging: messaging,
        localNotifications: localNotifications,
        notificationHandler: NotificationHandler(_MockBox()),
        woodyApi: _client(adapter, store),
      );

      await service.bootstrap();

      // FCM rotates the device token while the backend is down. The old code
      // awaited the upsert inside the stream callback, so the rejection
      // escaped to runZonedGuarded — flutter_test would surface it as an
      // unhandled async error and fail this test. The fix keeps it a caught
      // non-fatal.
      messaging.rotate('rotated-token');

      // Let the async upsert run and the 500 come back.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // The upsert was genuinely attempted (not short-circuited), and no error
      // escaped — reaching this line at all is the regression guard.
      expect(adapter.deviceTokenHits, 1);

      await service.dispose();
      await messaging.dispose();
    },
  );
}
