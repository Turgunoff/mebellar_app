import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:woody_app/core/services/facebook_analytics_service.dart';
import 'package:woody_app/core/services/meta_consent_gate.dart';

/// Consent gate stub — answers a fixed verdict without touching the ATT
/// platform channel, and counts how many times it was asked (idempotency).
class _FakeConsentGate extends MetaConsentGate {
  _FakeConsentGate(this.allowed);

  final bool allowed;
  int calls = 0;

  @override
  Future<bool> requestTrackingAuthorization() async {
    calls++;
    return allowed;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The plugin's platform channel — see `channelName` in facebook_app_events.
  const channel = MethodChannel('flutter.oddbit.id/facebook_app_events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  bool throwOnEvents = false;

  setUp(() {
    calls = [];
    throwOnEvents = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (throwOnEvents &&
          (call.method == 'logEvent' || call.method == 'logPurchase')) {
        throw PlatformException(code: 'boom');
      }
      // getFlushBehavior returns a token string; everything else is void.
      if (call.method == 'getFlushBehavior') return 'auto';
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  List<MethodCall> callsTo(String method) =>
      calls.where((c) => c.method == method).toList();

  MethodCall? eventNamed(String fbName) {
    for (final c in callsTo('logEvent')) {
      final args = (c.arguments as Map).cast<String, dynamic>();
      if (args['name'] == fbName) return c;
    }
    return null;
  }

  FacebookAnalyticsService build(bool allowed) => FacebookAnalyticsService(
    events: FacebookAppEvents(),
    consent: _FakeConsentGate(allowed),
  );

  group('consent gate', () {
    test('declined ⇒ SDK left off and every event is suppressed', () async {
      final service = build(false);
      await service.initialize();

      expect(service.isEnabled, isFalse);
      // Collection switches are forced OFF, and the app is never activated.
      expect(callsTo('setAutoLogAppEventsEnabled').single.arguments, isFalse);
      expect(
        callsTo('setAdvertiserIdCollectionEnabled').single.arguments,
        isFalse,
      );
      expect(callsTo('activateApp'), isEmpty);

      calls.clear();
      await service.logViewContent(
        contentId: 'p1',
        contentName: 'Sofa',
        value: 1000,
      );
      await service.logAddToCart('p1', 1000, contentName: 'Sofa');
      await service.logInitiateCheckout(numItems: 2, value: 2000);
      await service.logPurchase(3000, 'UZS');

      // Nothing reached the SDK while tracking is declined.
      expect(callsTo('logEvent'), isEmpty);
      expect(callsTo('logPurchase'), isEmpty);
    });

    test('granted ⇒ SDK turned on and activated', () async {
      final service = build(true);
      await service.initialize();

      expect(service.isEnabled, isTrue);
      expect(callsTo('setAutoLogAppEventsEnabled').single.arguments, isTrue);
      expect(
        callsTo('setAdvertiserIdCollectionEnabled').single.arguments,
        isTrue,
      );
      expect(callsTo('activateApp'), hasLength(1));
    });

    test('privacy opt-out suppresses Meta even when ATT is granted', () async {
      final service = build(true);
      await service.setPrivacyCollectionAllowed(false);
      await service.initialize();

      expect(service.isEnabled, isFalse);
      expect(callsTo('setAutoLogAppEventsEnabled').last.arguments, isFalse);
      expect(
        callsTo('setAdvertiserIdCollectionEnabled').last.arguments,
        isFalse,
      );
      expect(callsTo('activateApp'), isEmpty);

      calls.clear();
      await service.logPurchase(1000, 'UZS');
      expect(callsTo('logPurchase'), isEmpty);
    });

    test(
      'privacy toggle mid-session turns Meta off without re-prompting',
      () async {
        final gate = _FakeConsentGate(true);
        final service = FacebookAnalyticsService(
          events: FacebookAppEvents(),
          consent: gate,
        );
        await service.initialize();
        expect(service.isEnabled, isTrue);
        expect(gate.calls, 1);

        calls.clear();
        await service.setPrivacyCollectionAllowed(false);
        expect(service.isEnabled, isFalse);
        expect(callsTo('setAutoLogAppEventsEnabled').single.arguments, isFalse);
        // ATT must not be asked again when privacy flips.
        expect(gate.calls, 1);
      },
    );

    test('initialize is idempotent — consent asked once', () async {
      final gate = _FakeConsentGate(true);
      final service = FacebookAnalyticsService(
        events: FacebookAppEvents(),
        consent: gate,
      );
      await service.initialize();
      await service.initialize();
      expect(gate.calls, 1);
    });
  });

  group('standard events (granted)', () {
    late FacebookAnalyticsService service;

    setUp(() async {
      service = build(true);
      await service.initialize();
      calls.clear();
    });

    test(
      'ViewContent → fb_mobile_content_view with structured params',
      () async {
        await service.logViewContent(
          contentId: 'p42',
          contentName: 'Sofa',
          value: 1500,
        );
        final call = eventNamed(FacebookAppEvents.eventNameViewedContent);
        expect(call, isNotNull);
        final params = (call!.arguments as Map)['parameters'] as Map;
        expect(params['fb_content_id'], 'p42');
        expect(params['fb_content_type'], 'product');
        expect(params['content_name'], 'Sofa');
      },
    );

    test('AddToCart → fb_mobile_add_to_cart', () async {
      await service.logAddToCart('p7', 999, contentName: 'Chair');
      final call = eventNamed(FacebookAppEvents.eventNameAddedToCart);
      expect(call, isNotNull);
      final params = (call!.arguments as Map)['parameters'] as Map;
      expect(params['fb_content_id'], 'p7');
      expect(params['content_name'], 'Chair');
    });

    test(
      'InitiateCheckout → fb_mobile_initiated_checkout with num_items',
      () async {
        await service.logInitiateCheckout(numItems: 3, value: 5000);
        final call = eventNamed(FacebookAppEvents.eventNameInitiatedCheckout);
        expect(call, isNotNull);
        final params = (call!.arguments as Map)['parameters'] as Map;
        expect(params['fb_num_items'], 3);
      },
    );

    test('Purchase → logPurchase with content_ids + num_items', () async {
      await service.logPurchase(
        4500000,
        'UZS',
        contentIds: ['102', '105'],
        numItems: 2,
        orderId: 'order-77',
      );
      final call = callsTo('logPurchase').single;
      final args = (call.arguments as Map).cast<String, dynamic>();
      expect(args['amount'], 4500000);
      expect(args['currency'], 'UZS');
      final params = args['parameters'] as Map;
      expect(params['fb_content_id'], json.encode(['102', '105']));
      expect(params['fb_num_items'], 2);
      expect(params['fb_order_id'], 'order-77');
    });

    test(
      'debug builds flush after each event for real-time Test Events',
      () async {
        await service.logViewContent(
          contentId: 'p1',
          contentName: 'Sofa',
          value: 1,
        );
        // kDebugMode is true under `flutter test`, so the event is flushed.
        expect(callsTo('flush'), isNotEmpty);
      },
    );
  });

  test('events never throw even when the platform channel fails', () async {
    final service = build(true);
    await service.initialize();
    throwOnEvents = true;

    // None of these should rethrow the PlatformException.
    await service.logViewContent(
      contentId: 'p1',
      contentName: 'Sofa',
      value: 1000,
    );
    await service.logPurchase(1000, 'UZS', contentIds: ['1']);
    expect(service.isEnabled, isTrue);
  });
}
