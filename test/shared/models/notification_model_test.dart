import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/config/app_mode.dart';
import 'package:woody_app/shared/models/notification_model.dart';

NotificationModel _make({
  required NotificationKind kind,
  Map<String, dynamic>? payload,
}) {
  return NotificationModel(
    id: 'n1',
    userId: 'u1',
    title: 't',
    body: 'b',
    kind: kind,
    referenceId: null,
    isRead: false,
    createdAt: DateTime(2026, 6, 6),
    payload: payload,
  );
}

void main() {
  group('NotificationKind.fromString', () {
    test('maps the chat_message wire code', () {
      expect(
        NotificationKind.fromString('chat_message'),
        NotificationKind.chatMessage,
      );
    });

    test('unknown codes fall back to general', () {
      expect(NotificationKind.fromString('made_up'), NotificationKind.general);
    });

    test('every kind resolves an icon and accent without throwing', () {
      for (final kind in NotificationKind.values) {
        expect(kind.icon, isNotNull);
        expect(kind.accent, isNotNull);
      }
    });
  });

  group('NotificationCategory', () {
    test('parses the uppercase wire values', () {
      expect(NotificationCategory.fromString('ORDER'), NotificationCategory.order);
      expect(NotificationCategory.fromString('SYSTEM'), NotificationCategory.system);
      expect(NotificationCategory.fromString('PROMO'), NotificationCategory.promo);
      expect(NotificationCategory.fromString('CHAT'), NotificationCategory.chat);
    });

    test('returns null for an absent or unknown value', () {
      expect(NotificationCategory.fromString(null), isNull);
      expect(NotificationCategory.fromString('order'), isNull); // lowercase ≠ wire
      expect(NotificationCategory.fromString('whatever'), isNull);
    });

    test('kind rolls up to the expected coarse category', () {
      expect(NotificationKind.orderShipped.category, NotificationCategory.order);
      expect(NotificationKind.sellerNewOrder.category, NotificationCategory.order);
      expect(NotificationKind.chatMessage.category, NotificationCategory.chat);
      expect(NotificationKind.promo.category, NotificationCategory.promo);
      expect(NotificationKind.priceDrop.category, NotificationCategory.promo);
      // Anything unmapped (news, system alerts, seller verdicts, tariff…)
      // falls through to system — the catch-all tab.
      expect(NotificationKind.news.category, NotificationCategory.system);
      expect(NotificationKind.sellerApproved.category, NotificationCategory.system);
      expect(NotificationKind.general.category, NotificationCategory.system);
    });

    test('model.category prefers the backend value over the kind fallback', () {
      // A backend-reported category wins even if the kind would derive another.
      final tagged = NotificationModel(
        id: 'n1',
        userId: 'u1',
        title: 't',
        body: 'b',
        kind: NotificationKind.general, // would derive system…
        referenceId: null,
        isRead: false,
        createdAt: DateTime(2026, 6, 6),
        notificationType: NotificationCategory.promo, // …but backend says promo
      );
      expect(tagged.category, NotificationCategory.promo);

      // No backend value → derive from the kind.
      final untagged = _make(kind: NotificationKind.orderDelivered);
      expect(untagged.category, NotificationCategory.order);
    });

    test('fromJson parses notification_type and toJson emits the category', () {
      final model = NotificationModel.fromJson({
        'id': 'n1',
        'user_id': 'u1',
        'title': 't',
        'body': 'b',
        'type': 'order_shipped',
        'notification_type': 'ORDER',
        'reference_id': null,
        'is_read': false,
        'created_at': '2026-06-06T00:00:00.000Z',
      });
      expect(model.notificationType, NotificationCategory.order);
      expect(model.category, NotificationCategory.order);
      expect(model.toJson()['notification_type'], 'ORDER');
    });
  });

  group('resolveTargetMode', () {
    test('prefers an explicit seller mode in the payload (chat)', () {
      final n = _make(
        kind: NotificationKind.chatMessage,
        payload: {'mode': 'seller', 'chat_id': 'c1'},
      );
      expect(n.resolveTargetMode(), AppMode.seller);
    });

    test('prefers an explicit customer mode in the payload (chat)', () {
      final n = _make(
        kind: NotificationKind.chatMessage,
        payload: {'mode': 'customer', 'chat_id': 'c1'},
      );
      expect(n.resolveTargetMode(), AppMode.customer);
    });

    test('falls back to kind.targetMode when no payload mode is present', () {
      // sellerNewOrder is statically a seller-target kind.
      final n = _make(kind: NotificationKind.sellerNewOrder);
      expect(n.resolveTargetMode(), AppMode.seller);
      // an order kind is customer-target.
      final c = _make(kind: NotificationKind.order);
      expect(c.resolveTargetMode(), AppMode.customer);
    });

    test('ignores a malformed mode value and falls back to kind', () {
      final n = _make(
        kind: NotificationKind.order,
        payload: {'mode': 'martian'},
      );
      expect(n.resolveTargetMode(), AppMode.customer);
    });

    test(
        'verification verdicts always target customer mode — even when a '
        'stale pre-0019 payload says seller', () {
      for (final kind in [
        NotificationKind.sellerApproved,
        NotificationKind.sellerRejected,
      ]) {
        final stale = _make(
          kind: kind,
          payload: {'mode': 'seller', 'route': '/seller/profile'},
        );
        expect(
          stale.resolveTargetMode(),
          AppMode.customer,
          reason: 'a rejected applicant must never be switched into the '
              'seller shell',
        );
        expect(kind.targetMode, AppMode.customer);
      }
    });
  });
}
