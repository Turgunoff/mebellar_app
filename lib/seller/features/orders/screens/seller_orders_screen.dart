import 'package:flutter/material.dart';
import '../../../../core/theme/app_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:woody_app/config/app_config.dart';
import 'package:woody_app/core/widgets/coming_soon_beta_widget.dart';

import '../../../../core/theme/app_colors.dart';
import 'order_details_screen.dart';

// Local tokens — kept here so this screen reads top-to-bottom without
// chasing theme indirection. Plus Jakarta Sans is applied to every
// `Text` explicitly per the design spec rather than inheriting from
// the seller theme; this protects the screen from theme regressions.
const _ink = Color(0xFF1D1D1D);
const _grey = Color(0xFF757575);
const _greyMid = Color(0xFFBDBDBD);
const _divider = Color(0xFFEAEAEA);
const _outline = Color(0xFFE3E3E3);

// Amber pill — soft tint, saturated text. Don't darken `_amberFg`
// without re-checking contrast against `_amberBg`.
const _amberBg = Color(0xFFFFF1D6);
const _amberFg = Color(0xFF8C5A12);

// =============================================================================
// Screen — premium orders list with terracotta-accented tab bar.
// =============================================================================
class SellerOrdersScreen extends StatelessWidget {
  const SellerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ROADMAP A.2 — the orders surface is mock-only; hide it behind the
    // fulfillment flag so a release build never shows fake orders.
    if (!AppConfig.sellerFulfillmentEnabled) {
      return const ComingSoonBetaWidget();
    }
    return DefaultTabController(
      length: 4,
      child: ColoredBox(
        color: AppColors.lightBackground,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: const [
              _OrdersHeader(),
              _OrdersTabBar(),
              Expanded(
                child: TabBarView(
                  physics: BouncingScrollPhysics(),
                  children: [
                    _NewOrdersTab(),
                    _EmptyTab(message: "Faol buyurtmalar yo'q"),
                    _EmptyTab(message: "Yetkazilgan buyurtmalar yo'q"),
                    _EmptyTab(message: "Bekor qilingan buyurtmalar yo'q"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 1. Header — "Buyurtmalar" title in bold Jakarta
// =============================================================================
class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.lightBackground,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Buyurtmalar',
              style: TextStyle(fontFamily: AppFonts.seller, 
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _ink,
                height: 1.15,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 2. Tab bar — terracotta indicator, Jakarta labels, no teal
// =============================================================================
class _OrdersTabBar extends StatelessWidget {
  const _OrdersTabBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.lightBackground,
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: AppColors.terracotta,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppColors.terracotta,
        unselectedLabelColor: _grey,
        labelStyle: TextStyle(fontFamily: AppFonts.seller, 
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
        unselectedLabelStyle: TextStyle(fontFamily: AppFonts.seller, 
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
        ),
        dividerColor: _divider,
        dividerHeight: 1,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        tabs: const [
          Tab(text: 'Yangi'),
          Tab(text: 'Faol'),
          Tab(text: 'Yetkazilgan'),
          Tab(text: 'Bekor qilingan'),
        ],
      ),
    );
  }
}

// =============================================================================
// 3. New-orders tab — populated list of mock pending orders
// =============================================================================
class _NewOrdersTab extends StatelessWidget {
  const _NewOrdersTab();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.lightBackground,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: _kMockOrders.length,
        itemBuilder: (_, i) => Padding(
          padding: EdgeInsets.only(bottom: i == _kMockOrders.length - 1 ? 0 : 12),
          child: _OrderCard(order: _kMockOrders[i]),
        ),
      ),
    );
  }
}

// =============================================================================
// 4. Empty tab — neutral placeholder for non-"Yangi" tabs
// =============================================================================
class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.lightBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F1F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.shopping_bag,
                size: 28,
                color: _greyMid,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: TextStyle(fontFamily: AppFonts.seller, 
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 5. Order card — premium tile with action buttons
// =============================================================================
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final _MockOrder order;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black.withValues(alpha: 0.05),
      elevation: 0,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const OrderDetailsScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardHeader(orderId: order.orderId, time: order.time),
                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 1, color: _divider),
                const SizedBox(height: 12),
                _CardContent(
                  customerName: order.customerName,
                  itemsSummary: order.itemsSummary,
                ),
                const SizedBox(height: 14),
                _CardPriceRow(priceLabel: order.priceLabel),
                const SizedBox(height: 14),
                const _CardActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.orderId, required this.time});

  final String orderId;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            orderId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: AppFonts.seller, 
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: -0.2,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(Iconsax.clock, size: 14, color: _grey),
        const SizedBox(width: 4),
        Text(
          time,
          style: TextStyle(fontFamily: AppFonts.seller, 
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _grey,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.customerName,
    required this.itemsSummary,
  });

  final String customerName;
  final String itemsSummary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Iconsax.user, size: 18, color: _grey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: AppFonts.seller, 
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Iconsax.box, size: 18, color: _grey),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                itemsSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: AppFonts.seller, 
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _grey,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CardPriceRow extends StatelessWidget {
  const _CardPriceRow({required this.priceLabel});

  final String priceLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jami',
                style: TextStyle(fontFamily: AppFonts.seller, 
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _greyMid,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  text: priceLabel,
                  style: TextStyle(fontFamily: AppFonts.seller, 
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                  children: [
                    TextSpan(
                      text: '  UZS',
                      style: TextStyle(fontFamily: AppFonts.seller, 
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _greyMid,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _amberBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Kutilmoqda',
            style: TextStyle(fontFamily: AppFonts.seller, 
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _amberFg,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardActions extends StatelessWidget {
  const _CardActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink,
                backgroundColor: Colors.white,
                side: const BorderSide(color: _outline, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: TextStyle(fontFamily: AppFonts.seller, 
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(
                'Bekor qilish',
                style: TextStyle(fontFamily: AppFonts.seller, 
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 46,
            child: FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.terracotta,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: TextStyle(fontFamily: AppFonts.seller, 
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(
                'Qabul qilish',
                style: TextStyle(fontFamily: AppFonts.seller, 
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Mock data
// =============================================================================
@immutable
class _MockOrder {
  const _MockOrder({
    required this.orderId,
    required this.time,
    required this.customerName,
    required this.itemsSummary,
    required this.priceLabel,
  });

  final String orderId;
  final String time;
  final String customerName;
  final String itemsSummary;
  final String priceLabel;
}

const _kMockOrders = <_MockOrder>[
  _MockOrder(
    orderId: '#ORD-2026-1102',
    time: 'Bugun, 14:30',
    customerName: 'Aziz Rakhimov',
    itemsSummary: 'Klassik kuxnya jihozlari + 2 ta mahsulot',
    priceLabel: '12 400 000',
  ),
  _MockOrder(
    orderId: '#ORD-2026-1101',
    time: 'Bugun, 13:05',
    customerName: 'Madina Yusupova',
    itemsSummary: 'Yumshoq divan "Loft" + jurnal stolchasi',
    priceLabel: '8 750 000',
  ),
  _MockOrder(
    orderId: '#ORD-2026-1098',
    time: 'Bugun, 11:42',
    customerName: 'Sanjar Tursunov',
    itemsSummary: 'Yotoqxona to\'plami "Verona" + 3 ta mahsulot',
    priceLabel: '20 150 000',
  ),
  _MockOrder(
    orderId: '#ORD-2026-1095',
    time: 'Bugun, 09:18',
    customerName: 'Dilnoza Karimova',
    itemsSummary: 'Yozuv stoli + ofis kreslosi',
    priceLabel: '3 280 000',
  ),
];
