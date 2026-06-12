import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/product_model.dart';
import '../home/widgets/premium/premium_tokens.dart';
import 'bloc/cart_bloc.dart';

/// One-tap add from a product card's "+" CTA.
///
/// A colour pick is mandatory in the cart for any product that has a palette,
/// and a card can't surface the picker — so a product WITH colours opens the
/// detail page (where the picker lives) rather than silently adding a
/// colour-less line. A colour-less product is added straight to the cart with a
/// light haptic + a brand confirmation snackbar.
void quickAddToCart(BuildContext context, ProductModel product) {
  if (product.colors.isNotEmpty) {
    context.push('/product-detail/${product.id}', extra: product);
    return;
  }
  context.read<CartBloc>().add(AddToCart(product));
  HapticFeedback.lightImpact();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: PremiumTokens.accent,
        duration: const Duration(seconds: 2),
        content: Text(
          '${product.name} — savatga qo\'shildi',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PremiumTokens.body(
            size: 14,
            weight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
}
