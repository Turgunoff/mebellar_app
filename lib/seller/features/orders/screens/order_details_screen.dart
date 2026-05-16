import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/order_details/customer_card.dart';
import '../widgets/order_details/items_card.dart';
import '../widgets/order_details/order_action_bar.dart';
import '../widgets/order_details/order_app_bar.dart';
import '../widgets/order_details/order_details_kit.dart';
import '../widgets/order_details/order_meta_card.dart';
import '../widgets/order_details/payment_summary_card.dart';
import '../widgets/order_details/status_timeline_card.dart';

/// Premium seller order-details screen with a sticky bottom action bar.
///
/// ROADMAP B.4 — the original 1,149-line file was split: every section lives
/// under `widgets/order_details/`, leaving this file as the scroll shell.
class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: const OrderAppBar(orderId: kMockOrderId),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: const [
            OrderMetaCard(
              orderId: 'ORD-2026-1102',
              date: '03 May 2026, 14:30',
              statusLabel: 'Kutilmoqda',
            ),
            SizedBox(height: 14),
            StatusTimelineCard(currentStep: 1),
            SizedBox(height: 14),
            CustomerCard(
              name: 'Aziz Rakhimov',
              phone: '+998 90 123 45 67',
              address:
                  "Toshkent sh., Chilonzor tumani, 9-kvartal, 12-uy, 45-xonadon",
            ),
            SizedBox(height: 14),
            ItemsCard(items: kMockOrderItems),
            SizedBox(height: 14),
            PaymentSummaryCard(
              subtotal: '12 400 000',
              delivery: '150 000',
              total: '12 550 000',
              paymentMethod: 'Naqd pul',
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: const OrderActionBar(),
    );
  }
}
