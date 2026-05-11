import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/premium_empty_state.dart';
import '../../../customer_app.dart';
import '../../../widgets/glass_bottom_nav.dart';
import '../../home/widgets/premium/premium_product_card.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../bloc/favorites_bloc.dart';

/// Premium "Sevimlilar" (Favorites) screen wired to [FavoritesBloc].
///
/// Renders a two-column grid of saved products using [PremiumProductCard];
/// when the list is empty, falls through to a composed empty state with a
/// CTA back to the catalog.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    // Kick off the initial fetch once. The bloc also subscribes to the
    // repository's `watchIds` stream, so subsequent toggles from anywhere
    // in the app update this screen automatically.
    final bloc = context.read<FavoritesBloc>();
    if (bloc.state.status == FavoritesStatus.initial) {
      bloc.add(const FavoritesRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final bottomPad = GlassBottomNav.reservedHeight(context) + 24;

    return ColoredBox(
      color: pt.background,
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<FavoritesBloc, FavoritesState>(
          buildWhen: (a, b) =>
              a.status != b.status || a.products != b.products,
          builder: (context, state) {
            if (state.status == FavoritesStatus.loading ||
                state.status == FavoritesStatus.initial) {
              return const Center(
                child: CircularProgressIndicator(
                  color: PremiumTokens.accent,
                ),
              );
            }
            if (state.products.isEmpty) {
              return PremiumEmptyState(
                icon: Iconsax.heart,
                title: 'Sizda hozircha sevimlilar yo\'q',
                subtitle:
                    'Sizga yoqqan har qanday mahsulotni yurakcha tugmasi orqali saqlang — keyin osongina topib oling.',
                buttonText: 'Katalogga o\'tish',
                onButtonPressed: () =>
                    CustomerShellScope.of(context).goToTab(0),
                bottomPadding: bottomPad,
              );
            }
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _FavoritesHeader(count: state.products.length),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.65,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final product = state.products[i];
                        return _FavoriteProductTile(product: product);
                      },
                      childCount: state.products.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FavoriteProductTile extends StatelessWidget {
  const _FavoriteProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final shopName = product.shop?.name.get(lang) ?? '';
    return PremiumProductCard(
      imageUrl: product.heroImage,
      name: product.name.get(lang),
      shop: shopName,
      price: '${_formatPrice(product.price)} so\'m',
      isFavorite: true,
      onTap: () => context.push('/products/${product.slug}'),
      onFavoriteToggle: () =>
          context.read<FavoritesBloc>().add(FavoriteToggled(product)),
    );
  }
}

class _FavoritesHeader extends StatelessWidget {
  const _FavoritesHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sevimlilar',
            style: PremiumTokens.display(size: 32, letterSpacing: -0.6),
          ),
          const SizedBox(height: 4),
          Text(
            '$count saqlangan mahsulot',
            style: PremiumTokens.body(
              size: 13,
              color: pt.grey,
            ),
          ),
        ],
      ),
    );
  }
}


String _formatPrice(num value) {
  final s = value.toInt().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i != 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
