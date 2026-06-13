import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/theme/app_colors.dart';
import 'package:woody_app/core/theme/app_theme.dart';
import 'package:woody_app/shared/chat/widgets/message_bubble.dart';
import 'package:woody_app/shared/models/chat.dart';
import 'package:woody_app/shared/models/chat_message.dart';

ChatMessage _msg({
  required ChatSenderRole sender,
  bool read = false,
  ChatMessageStatus status = ChatMessageStatus.sent,
}) => ChatMessage(
  id: 'm1',
  chatId: 'c1',
  senderId: 's',
  senderRole: sender,
  body: 'salom',
  createdAt: DateTime.utc(2026, 6, 13, 8, 0),
  readAt: read ? DateTime.utc(2026, 6, 13, 9, 0) : null,
  status: status,
);

Future<void> _pump(
  WidgetTester tester,
  ChatMessage message,
  ChatSenderRole viewer, {
  ThemeData? theme,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      home: Scaffold(body: MessageBubble(message: message, viewer: viewer)),
    ),
  );
}

void main() {
  setUpAll(() {
    AppTranslations.setInstance(AppTranslations.forLocale(const Locale('uz')));
  });

  testWidgets('outgoing unread message shows a single check (Telegram)', (
    tester,
  ) async {
    await _pump(
      tester,
      _msg(sender: ChatSenderRole.customer),
      ChatSenderRole.customer,
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsNothing);
  });

  testWidgets('outgoing read message shows a double check (Telegram)', (
    tester,
  ) async {
    await _pump(
      tester,
      _msg(sender: ChatSenderRole.customer, read: true),
      ChatSenderRole.customer,
    );

    expect(find.byIcon(Icons.done_all), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('incoming message shows no read receipt for the viewer', (
    tester,
  ) async {
    // Viewer is the customer; the message came from the seller → not "mine",
    // so neither tick renders even though it has been read.
    await _pump(
      tester,
      _msg(sender: ChatSenderRole.seller, read: true),
      ChatSenderRole.customer,
    );

    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byIcon(Icons.done_all), findsNothing);
  });

  testWidgets('outgoing bubble fill follows the active theme primary '
      '(seller indigo), not the customer accent', (tester) async {
    final sellerTheme = ThemeData(
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.sellerPrimary,
          ).copyWith(primary: AppColors.sellerPrimary),
    );
    await _pump(
      tester,
      _msg(sender: ChatSenderRole.seller),
      ChatSenderRole.seller,
      theme: sellerTheme,
    );

    final paintedSellerPrimary = tester
        .widgetList<Container>(find.byType(Container))
        .any((c) {
          final d = c.decoration;
          return d is BoxDecoration && d.color == AppColors.sellerPrimary;
        });
    expect(paintedSellerPrimary, isTrue);
  });
}
