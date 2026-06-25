import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/i18n/i18n.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';

/// Surface app bar with a bold Jakarta title and a hairline divider; flips
/// with the seller theme via [SellerColors].
class OrderAppBar extends StatelessWidget implements PreferredSizeWidget {
  const OrderAppBar({super.key, required this.orderId, this.orderUuid});

  final String orderId;

  /// When set, the trailing chat button is rendered and routes to the
  /// seller's view of the chat for this order. Null for synthetic /
  /// not-yet-loaded states.
  final String? orderUuid;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor: c.surface,
      surfaceTintColor: c.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        splashRadius: 22,
        icon: Icon(Iconsax.arrow_left_2_copy, size: 22, color: c.ink),
      ),
      titleSpacing: 0,
      title: Text(
        tr('seller_orders.detail_app_bar_title', args: [orderId]),
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: c.ink,
          letterSpacing: -0.3,
          height: 1.2,
        ),
      ),
      centerTitle: false,
      actions: [
        if (orderUuid != null)
          IconButton(
            tooltip: tr('seller_orders.chat_tooltip'),
            icon: Icon(Iconsax.message, color: c.ink, size: 22),
            onPressed: () => context.push('/seller/orders/$orderUuid/chat'),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: c.dividerStrong),
      ),
    );
  }
}
