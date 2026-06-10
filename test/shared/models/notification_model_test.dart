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
