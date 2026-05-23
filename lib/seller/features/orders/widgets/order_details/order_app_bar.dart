import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_fonts.dart';
import 'order_details_kit.dart';

/// White-surface app bar with a bold Jakarta title and a hairline divider.
class OrderAppBar extends StatelessWidget implements PreferredSizeWidget {
  const OrderAppBar({
    super.key,
    required this.orderId,
    this.orderUuid,
  });

  final String orderId;

  /// When set, the trailing chat button is rendered and routes to the
  /// seller's view of the chat for this order. Null for synthetic /
  /// not-yet-loaded states.
  final String? orderUuid;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        splashRadius: 22,
        icon: const Icon(Iconsax.arrow_left_2, size: 22, color: kInk),
      ),
      titleSpacing: 0,
      title: Text(
        'Buyurtma $orderId',
        style: const TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: kInk,
          letterSpacing: -0.3,
          height: 1.2,
        ),
      ),
      centerTitle: false,
      actions: [
        if (orderUuid != null)
          IconButton(
            tooltip: 'Mijoz bilan suhbat',
            icon: const Icon(Iconsax.message, color: kInk, size: 22),
            onPressed: () =>
                context.push('/seller/orders/$orderUuid/chat'),
          ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: kDivider),
      ),
    );
  }
}
