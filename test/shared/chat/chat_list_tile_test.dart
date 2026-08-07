import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/theme/app_colors.dart';
import 'package:woody_app/core/theme/app_theme.dart';
import 'package:woody_app/core/theme/premium_tokens.dart';
import 'package:woody_app/shared/chat/widgets/chat_list_tile.dart';
import 'package:woody_app/shared/models/chat.dart';

Chat _chat({
  ChatSenderRole? lastSender,
  DateTime? readAt,
  int customerUnread = 0,
  int sellerUnread = 0,
}) {
  final now = DateTime(2026, 6, 13, 11, 10);
  return Chat(
    id: 'ch1',
    orderId: 'order-1234',
    customerId: 'cu1',
    shopId: 'sh1',
    shopName: 'Mebel Shop',
    customerName: 'Ali',
    lastMessageAt: now,
    lastMessagePreview: 'salom',
    lastMessageSenderRole: lastSender,
    lastMessageReadAt: readAt,
    customerUnreadCount: customerUnread,
    sellerUnreadCount: sellerUnread,
    createdAt: now,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Chat chat,
  ChatSenderRole viewer, {
  ThemeData? theme,
}) {
  return tester.pumpWidget(
    MaterialApp(
      // Default to the real customer theme so colorScheme.primary resolves to
      // the brand terracotta the read-receipt/badge now key off.
      theme: theme ?? AppTheme.lightTheme,
      home: Scaffold(
        body: ChatListTile(chat: chat, viewer: viewer, onTap: () {}),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    AppTranslations.setInstance(AppTranslations.forLocale(const Locale('uz')));
  });

  testWidgets('shows a double-check when my last message has been read', (
    tester,
  ) async {
    await _pump(
      tester,
      _chat(lastSender: ChatSenderRole.customer, readAt: DateTime(2026, 6, 13)),
      ChatSenderRole.customer,
    );

    expect(find.byIcon(Icons.done_all), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);

    final icon = tester.widget<Icon>(find.byIcon(Icons.done_all));
    // Customer theme primary == brand terracotta == PremiumTokens.accent.
    expect(icon.color, PremiumTokens.accent);
    expect(icon.color, AppColors.terracotta);
  });

  testWidgets(
    'read receipt follows the active theme primary — Deep Indigo in seller '
    'mode, not the customer terracotta',
    (tester) async {
      final sellerTheme = ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: AppColors.sellerPrimary,
            ).copyWith(primary: AppColors.sellerPrimary),
      );
      // Seller is the viewer; their own last message has been read → done_all.
      await _pump(
        tester,
        _chat(
          lastSender: ChatSenderRole.seller,
          readAt: DateTime(2026, 6, 13),
        ),
        ChatSenderRole.seller,
        theme: sellerTheme,
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.done_all));
      expect(icon.color, AppColors.sellerPrimary);
      expect(icon.color, isNot(PremiumTokens.accent));
    },
  );

  testWidgets('shows a single check when my last message is unread', (
    tester,
  ) async {
    await _pump(
      tester,
      _chat(lastSender: ChatSenderRole.customer),
      ChatSenderRole.customer,
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsNothing);
  });

  testWidgets('shows no receipt when the last message was incoming', (
    tester,
  ) async {
    // Viewer is the customer; the last message came from the seller, so it is
    // not "mine" — no tick, and the incoming unread badge shows instead.
    await _pump(
      tester,
      _chat(lastSender: ChatSenderRole.seller, customerUnread: 3),
      ChatSenderRole.customer,
    );

    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byIcon(Icons.done_all), findsNothing);
    expect(find.text('3'), findsOneWidget); // unread badge survives
  });
}
