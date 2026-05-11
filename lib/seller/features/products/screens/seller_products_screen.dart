import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/seller_product.dart';
import '../../../../shared/repositories/seller_product_repository.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../bloc/seller_products_bloc.dart';
import '../widgets/product_status_chip.dart';
import 'product_form_screen.dart';
import 'seller_product_detail_screen.dart';

// Typography note for this screen:
//
//   The seller theme pins the default font family to Plus Jakarta Sans via
//   `AppTypography.plusJakartaSansTextTheme(...)` in `seller_theme.dart`.
//   Every TextStyle here intentionally omits `fontFamily` so the family is
//   inherited from the theme — don't reintroduce `AppFonts.xxx(...)`.
//
//   Color overrides below also bypass the seller `ColorScheme` for the
//   surfaces that were picking up an off-brand greenish/teal tint
//   (FAB, filter chips, search field). Branded values come from
//   [AppColors.terracotta] / [AppColors.lightBackground] and a small set of
//   private constants below.
const _ink = Color(0xFF1D1D1D);
const _grey = Color(0xFF757575);
const _greyMid = Color(0xFFBDBDBD);
const _hairline = Color(0xFFEEEEEE);

class SellerProductsScreen extends StatelessWidget {
  const SellerProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SellerProductsBloc(sl<SellerProductRepository>())
        ..add(const SellerProductsRequested()),
      child: const _SellerProductsView(),
    );
  }
}

class _SellerProductsView extends StatefulWidget {
  const _SellerProductsView();

  @override
  State<_SellerProductsView> createState() => _SellerProductsViewState();
}

class _SellerProductsViewState extends State<_SellerProductsView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openCreate(BuildContext context) {
    final bloc = context.read<SellerProductsBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: const ProductFormScreen(),
        ),
      ),
    );
  }

  void _openEdit(BuildContext context, SellerProduct product) {
    final bloc = context.read<SellerProductsBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: ProductFormScreen(existing: product),
        ),
      ),
    );
  }

  // Opens the customer-style preview of the seller's product. The preview's
  // "Edit" CTA hands off to [_openEdit] via the [onEdit] callback, so the
  // existing form flow is one tap away.
  void _openPreview(BuildContext context, SellerProduct product) {
    final bloc = context.read<SellerProductsBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (previewContext) => BlocProvider.value(
          value: bloc,
          child: SellerProductDetailScreen(
            onEdit: () {
              Navigator.of(previewContext).pop();
              _openEdit(context, product);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SellerProductsBloc, SellerProductsState>(
      builder: (context, state) {
        final visible = state.visibleProducts;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            backgroundColor: AppColors.lightBackground,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleSpacing: 20,
            title: Text(
              tr('seller.tab_products'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _ink,
                letterSpacing: -0.4,
                height: 1.15,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(110),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _SearchField(
                      controller: _searchCtrl,
                      onChanged: (v) {
                        context
                            .read<SellerProductsBloc>()
                            .add(SellerProductsSearchChanged(v));
                        setState(() {});
                      },
                      onClear: () {
                        _searchCtrl.clear();
                        context
                            .read<SellerProductsBloc>()
                            .add(const SellerProductsSearchChanged(''));
                        setState(() {});
                      },
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _StatusFilterChip(
                          label: tr('seller.filter_all'),
                          selected: state.filter.statuses.isEmpty,
                          onTap: () => context
                              .read<SellerProductsBloc>()
                              .add(SellerProductsFilterChanged(
                                state.filter.copyWith(statuses: const {}),
                              )),
                        ),
                        for (final s in SellerProductStatus.values) ...[
                          const SizedBox(width: 8),
                          _StatusFilterChip(
                            label: tr('seller_product_status.${s.code}'),
                            selected: state.filter.statuses.contains(s),
                            onTap: () {
                              final next = Set<SellerProductStatus>.from(
                                  state.filter.statuses);
                              if (next.contains(s)) {
                                next.remove(s);
                              } else {
                                next.add(s);
                              }
                              context
                                  .read<SellerProductsBloc>()
                                  .add(SellerProductsFilterChanged(
                                    state.filter.copyWith(statuses: next),
                                  ));
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: switch (state.status) {
            SellerProductsStatus.initial ||
            SellerProductsStatus.loading =>
              const Center(
                child: CircularProgressIndicator(color: AppColors.terracotta),
              ),
            SellerProductsStatus.failure when state.products.isEmpty =>
              ErrorState(
                message: state.error,
                onRetry: () => context
                    .read<SellerProductsBloc>()
                    .add(const SellerProductsRequested()),
              ),
            _ => visible.isEmpty
                ? EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: tr('seller.products_empty'),
                    message: tr('seller.products_empty_hint'),
                    action: () => _openCreate(context),
                    actionLabel: tr('seller.add_product'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _ProductTile(
                      product: visible[i],
                      onTap: () => _openPreview(context, visible[i]),
                    ),
                  ),
          },
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openCreate(context),
            backgroundColor: AppColors.terracotta,
            foregroundColor: Colors.white,
            elevation: 4,
            highlightElevation: 6,
            icon: const Icon(Iconsax.add, size: 20),
            label: Text(
              tr('seller.add_product'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0,
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Search field — pure white pill with Iconsax.search_normal
// =============================================================================
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;
    return TextField(
      controller: controller,
      cursorColor: AppColors.terracotta,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _ink,
        height: 1.2,
      ),
      decoration: InputDecoration(
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 14, right: 8),
          child: Icon(Iconsax.search_normal, size: 18, color: _grey),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        hintText: tr('seller.products_search_hint'),
        hintStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _greyMid,
          height: 1.2,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.terracotta.withValues(alpha: 0.5),
          ),
        ),
        suffixIcon: hasText
            ? IconButton(
                icon: const Icon(Iconsax.close_circle, size: 18, color: _grey),
                onPressed: onClear,
              )
            : null,
      ),
      onChanged: onChanged,
    );
  }
}

// =============================================================================
// Filter chip — terracotta tint + terracotta text when selected, white pill
// otherwise. Replaces Material's `FilterChip` which was picking up the seller
// scheme's secondary color (the off-brand greenish tint).
// =============================================================================
class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        // ignore: deprecated_member_use
        ? Colors.orange.withOpacity(0.1)
        : Colors.white;
    final fg = selected ? AppColors.terracotta : _grey;
    final borderColor = selected
        ? AppColors.terracotta.withValues(alpha: 0.35)
        : _hairline;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: fg,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Product tile — pure white, soft drop shadow, no hard border.
// =============================================================================
class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onTap});
  final SellerProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final priceFormat = NumberFormat('#,###', lang);
    final hero = product.heroImage;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductThumbnail(hero: hero),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name.get(lang),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                          letterSpacing: -0.1,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${product.sku}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _greyMid,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            "${priceFormat.format(product.price)} so'm",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                              letterSpacing: -0.2,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            tr('seller.stock_label',
                                args: ['${product.stock}']),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _grey,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ProductStatusChip(
                            status: product.status,
                            compact: true,
                          ),
                          const Spacer(),
                          if (product.status == SellerProductStatus.draft ||
                              product.status == SellerProductStatus.rejected)
                            TextButton(
                              onPressed: () => context
                                  .read<SellerProductsBloc>()
                                  .add(SellerProductSubmitted(product.id)),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.terracotta,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                tr('seller.product_submit_for_review'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.terracotta,
                                  height: 1.2,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (product.rejectionReason != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          product.rejectionReason!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFC0392B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.hero});

  final String? hero;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: const Color(0xFFF4F4F4),
      alignment: Alignment.center,
      child: const Icon(Iconsax.image, size: 22, color: _greyMid),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 76,
        height: 76,
        child: hero == null || hero!.isEmpty
            ? placeholder
            : (hero!.startsWith('http')
                ? CachedNetworkImage(
                    imageUrl: hero!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => placeholder,
                    errorWidget: (_, _, _) => placeholder,
                  )
                : Image.asset(
                    hero!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => placeholder,
                  )),
      ),
    );
  }
}
