import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/seller_product.dart';

// Local tokens — pinned per-screen so the preview reads top-to-bottom without
// chasing theme indirection. Mirrors the order_details screen's palette so
// the seller surfaces stay visually consistent.
const _ink = Color(0xFF1D1D1D);
const _grey = Color(0xFF757575);
const _greyMid = Color(0xFFBDBDBD);
const _greySoft = Color(0xFFB0B0B0);
const _divider = Color(0xFFEAEAEA);
const _outline = Color(0xFFE3E3E3);
const _surfaceMuted = Color(0xFFF5F5F5);
const _imageBg = Color(0xFFF0F0F0);
const _terracottaSoft = Color(0xFFFBEDE6);

// Status palette — kept aligned with [ProductStatusChip] so the preview's
// banner pill matches the list-tile pill exactly.
({Color bg, Color fg, IconData icon, String label}) _statusPalette(
  SellerProductStatus status,
) {
  return switch (status) {
    SellerProductStatus.draft => (
        bg: const Color(0xFFF1F1F1),
        fg: const Color(0xFF555555),
        icon: Iconsax.edit,
        label: 'Qoralama',
      ),
    SellerProductStatus.pendingReview => (
        bg: const Color(0xFFFFF1D6),
        fg: const Color(0xFF8C5A12),
        icon: Iconsax.clock,
        label: 'Tekshirilmoqda',
      ),
    SellerProductStatus.approved => (
        bg: const Color(0xFFDCF1E5),
        fg: const Color(0xFF1F6B49),
        icon: Iconsax.tick_circle,
        label: 'Tasdiqlangan',
      ),
    SellerProductStatus.rejected => (
        bg: const Color(0xFFFDECEA),
        fg: const Color(0xFFC0392B),
        icon: Iconsax.close_circle,
        label: 'Rad etilgan',
      ),
    SellerProductStatus.archived => (
        bg: const Color(0xFFEDEDED),
        fg: const Color(0xFF8A8A8A),
        icon: Iconsax.archive_2,
        label: 'Arxivlangan',
      ),
  };
}

// =============================================================================
// Screen — customer-style preview of a seller's own product. Layout follows
// the customer detail view (gallery → title/price → stock → description →
// attributes), with seller-specific signals (status banner, SKU, internal
// dimensions) layered on top. Bottom bar swaps the customer's add-to-cart /
// buy-now actions for an Edit primary action.
// =============================================================================
class SellerProductDetailScreen extends StatelessWidget {
  const SellerProductDetailScreen({super.key, this.onEdit});

  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    const product = _kMockProduct;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          _PreviewAppBar(images: product.images),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _PreviewModeBanner(),
                  SizedBox(height: 14),
                  _StatusCard(
                    status: SellerProductStatus.approved,
                    updatedAtLabel: '02 May 2026, 18:42',
                  ),
                  SizedBox(height: 14),
                  _TitlePriceCard(product: product),
                  SizedBox(height: 14),
                  _MetaCard(
                    sku: 'MH-KIT-010',
                    category: 'Oshxona jihozlari',
                    stock: 2,
                  ),
                  SizedBox(height: 14),
                  _DescriptionCard(
                    text:
                        'Klassik uslubdagi premium oshxona jihozlari to\'plami. '
                        'Tabiiy yong\'oq daraxtidan ishlangan, qo\'lda jilolangan '
                        'sirt va mis dastalar bilan bezatilgan. Komplektga oshxona '
                        'shkafi, ish stoli, hamda 4 ta yumshoq stul kiradi. '
                        'Materiallar O\'zbekistonda yetishtirilgan, eko-do\'st '
                        'lak bilan qoplangan. Yetkazib berish va yig\'ish '
                        'xizmati shahar ichida bepul.',
                  ),
                  SizedBox(height: 14),
                  _AttributesCard(
                    rows: [
                      ('Material', 'Yong\'oq daraxti'),
                      ('Rang', 'Tabiiy jigarrang'),
                      ('Uslub', 'Klassik'),
                      ('Kafolat muddati', '24 oy'),
                      ('Ishlab chiqaruvchi', "O'zbekiston"),
                    ],
                  ),
                  SizedBox(height: 14),
                  _DimensionsCard(
                    lengthCm: 220,
                    widthCm: 80,
                    heightCm: 95,
                    weightKg: 64.5,
                  ),
                  SizedBox(height: 14),
                  _IdentifiersCard(
                    productId: 'pr_01HVZ8N7K4Q9X2',
                    createdAtLabel: '14 Apr 2026',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomActionBar(onEdit: onEdit),
    );
  }
}

// =============================================================================
// AppBar — pinned, expanding image gallery. Uses Iconsax glyphs over a
// translucent chip so the icons remain legible against any image.
// =============================================================================
class _PreviewAppBar extends StatelessWidget {
  const _PreviewAppBar({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width;
    return SliverAppBar(
      pinned: true,
      expandedHeight: size,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _GlassIconButton(
          icon: Iconsax.arrow_left_2,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: _GlassIconButton(
            icon: Iconsax.share,
            onTap: () {},
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _ImageGallery(images: images),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: _ink),
        ),
      ),
    );
  }
}

class _ImageGallery extends StatefulWidget {
  const _ImageGallery({required this.images});

  final List<String> images;

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imgs.isEmpty)
          Container(
            color: _imageBg,
            alignment: Alignment.center,
            child: const Icon(Iconsax.image, size: 72, color: _greyMid),
          )
        else
          PageView.builder(
            controller: _controller,
            itemCount: imgs.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => CachedNetworkImage(
              imageUrl: imgs[i],
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: _imageBg),
              errorWidget: (_, _, _) => Container(
                color: _imageBg,
                alignment: Alignment.center,
                child: const Icon(
                  Iconsax.gallery_slash,
                  size: 48,
                  color: _greyMid,
                ),
              ),
            ),
          ),
        if (imgs.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < imgs.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// Preview-mode banner — leading strip that tells the seller "this is the
// customer-facing view." Subtle terracotta tint so it doesn't compete with
// the content cards below.
// =============================================================================
class _PreviewModeBanner extends StatelessWidget {
  const _PreviewModeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _terracottaSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.terracotta.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.eye, size: 18, color: AppColors.terracotta),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Mijoz ko'rinishi",
                  style: TextStyle(fontFamily: AppFonts.seller, 
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.terracotta,
                    height: 1.2,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Mahsulotingiz xaridorlarga qanday ko'rinishini tekshiring",
                  style: TextStyle(fontFamily: AppFonts.seller, 
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8A4A35),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Status card — moderation state pill + last-updated timestamp.
// =============================================================================
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.updatedAtLabel});

  final SellerProductStatus status;
  final String updatedAtLabel;

  @override
  Widget build(BuildContext context) {
    final palette = _statusPalette(status);
    return _SectionCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(palette.icon, size: 14, color: palette.fg),
                const SizedBox(width: 6),
                Text(
                  palette.label,
                  style: TextStyle(fontFamily: AppFonts.seller, 
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: palette.fg,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Icon(Iconsax.refresh, size: 13, color: _greySoft),
          const SizedBox(width: 6),
          Text(
            updatedAtLabel,
            style: TextStyle(fontFamily: AppFonts.seller, 
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _grey,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Title + price card — title, current price (large), strike-through old
// price, discount pill, and an in-stock indicator.
// =============================================================================
class _TitlePriceCard extends StatelessWidget {
  const _TitlePriceCard({required this.product});

  final _MockProduct product;

  @override
  Widget build(BuildContext context) {
    final hasDiscount =
        product.oldPriceLabel != null && product.oldPriceLabel!.isNotEmpty;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.title,
            style: TextStyle(fontFamily: AppFonts.seller, 
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: -0.4,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RichText(
                text: TextSpan(
                  text: product.priceLabel,
                  style: TextStyle(fontFamily: AppFonts.seller, 
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.6,
                    height: 1.0,
                  ),
                  children: [
                    TextSpan(
                      text: '  UZS',
                      style: TextStyle(fontFamily: AppFonts.seller, 
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _greyMid,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasDiscount) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    "${product.oldPriceLabel!} UZS",
                    style: TextStyle(fontFamily: AppFonts.seller, 
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _greySoft,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: _greySoft,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (hasDiscount) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '-${product.discountPercent}%',
                style: TextStyle(fontFamily: AppFonts.seller, 
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFC0392B),
                  height: 1.0,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: _divider),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                product.stock > 0
                    ? Iconsax.tick_circle
                    : Iconsax.close_circle,
                size: 16,
                color: product.stock > 0
                    ? const Color(0xFF1F6B49)
                    : const Color(0xFFC0392B),
              ),
              const SizedBox(width: 8),
              Text(
                product.stock > 0
                    ? 'Sotuvda mavjud · ${product.stock} dona'
                    : 'Sotuvda yo\'q',
                style: TextStyle(fontFamily: AppFonts.seller, 
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: product.stock > 0
                      ? const Color(0xFF1F6B49)
                      : const Color(0xFFC0392B),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Meta card — SKU (copyable), category, stock count. Mirrors fields the
// seller list tile already exposes so the preview confirms what's saved.
// =============================================================================
class _MetaCard extends StatelessWidget {
  const _MetaCard({
    required this.sku,
    required this.category,
    required this.stock,
  });

  final String sku;
  final String category;
  final int stock;

  Future<void> _copySku(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: sku));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _ink,
          content: Text(
            "SKU nusxa olindi",
            style: TextStyle(fontFamily: AppFonts.seller, 
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(text: 'Asosiy ma\'lumotlar'),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Iconsax.barcode, size: 18, color: _grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SKU',
                      style: TextStyle(fontFamily: AppFonts.seller, 
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _grey,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sku,
                      style: TextStyle(fontFamily: AppFonts.seller, 
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        height: 1.2,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: _surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => _copySku(context),
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Iconsax.copy, size: 16, color: _ink),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: _divider),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Iconsax.category, size: 18, color: _grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kategoriya',
                      style: TextStyle(fontFamily: AppFonts.seller, 
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _grey,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      category,
                      style: TextStyle(fontFamily: AppFonts.seller, 
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: _divider),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Iconsax.box, size: 18, color: _grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ombor qoldig\'i',
                      style: TextStyle(fontFamily: AppFonts.seller, 
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _grey,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$stock dona',
                      style: TextStyle(fontFamily: AppFonts.seller, 
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (stock > 0 && stock <= 3)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1D6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Kam qoldi',
                    style: TextStyle(fontFamily: AppFonts.seller, 
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8C5A12),
                      height: 1.0,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Description card — collapses to 5 lines with a "Show more" toggle so very
// long descriptions don't dominate the scroll.
// =============================================================================
class _DescriptionCard extends StatefulWidget {
  const _DescriptionCard({required this.text});

  final String text;

  @override
  State<_DescriptionCard> createState() => _DescriptionCardState();
}

class _DescriptionCardState extends State<_DescriptionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(text: "Tavsif"),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Text(
              widget.text,
              maxLines: _expanded ? null : 5,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(fontFamily: AppFonts.seller, 
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: _ink,
                height: 1.55,
                letterSpacing: -0.05,
              ),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _expanded ? "Yopish" : "Ko'proq o'qish",
                    style: TextStyle(fontFamily: AppFonts.seller, 
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.terracotta,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Iconsax.arrow_up_2
                        : Iconsax.arrow_down_1,
                    size: 14,
                    color: AppColors.terracotta,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Attributes card — key/value rows inside a single bordered shell so each row
// stays light without a per-row background.
// =============================================================================
class _AttributesCard extends StatelessWidget {
  const _AttributesCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(text: 'Xususiyatlar'),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      rows[i].$1,
                      style: TextStyle(fontFamily: AppFonts.seller, 
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _grey,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: Text(
                      rows[i].$2,
                      textAlign: TextAlign.end,
                      style: TextStyle(fontFamily: AppFonts.seller, 
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                        height: 1.3,
                        letterSpacing: -0.05,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i != rows.length - 1)
              const Divider(height: 1, thickness: 1, color: _divider),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Dimensions card — four-up grid of length / width / height / weight tiles.
// Surfaces internal logistic data the customer screen also shows on shop
// detail pages, so the seller can verify what they entered.
// =============================================================================
class _DimensionsCard extends StatelessWidget {
  const _DimensionsCard({
    required this.lengthCm,
    required this.widthCm,
    required this.heightCm,
    required this.weightKg,
  });

  final num lengthCm;
  final num widthCm;
  final num heightCm;
  final num weightKg;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(text: "O'lchamlari va og'irligi"),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DimensionTile(
                  icon: Iconsax.ruler,
                  label: 'Uzunligi',
                  value: '$lengthCm sm',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DimensionTile(
                  icon: Iconsax.size,
                  label: 'Kengligi',
                  value: '$widthCm sm',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DimensionTile(
                  icon: Iconsax.maximize_3,
                  label: 'Balandligi',
                  value: '$heightCm sm',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DimensionTile(
                  icon: Iconsax.weight,
                  label: 'Og\'irligi',
                  value: '$weightKg kg',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DimensionTile extends StatelessWidget {
  const _DimensionTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: _surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: _grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontFamily: AppFonts.seller, 
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _grey,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontFamily: AppFonts.seller, 
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: -0.2,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Identifiers card — internal product id + creation timestamp. Compact strip
// at the very bottom so it doesn't pull focus from the buyer-facing content.
// =============================================================================
class _IdentifiersCard extends StatelessWidget {
  const _IdentifiersCard({
    required this.productId,
    required this.createdAtLabel,
  });

  final String productId;
  final String createdAtLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mahsulot ID',
                  style: TextStyle(fontFamily: AppFonts.seller, 
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _grey,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  productId,
                  style: TextStyle(fontFamily: AppFonts.seller, 
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                    height: 1.2,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Yaratilgan',
                style: TextStyle(fontFamily: AppFonts.seller, 
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _grey,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                createdAtLabel,
                style: TextStyle(fontFamily: AppFonts.seller, 
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Bottom action bar — Archive (outlined, secondary) + Edit (filled, primary).
// Layout intentionally mirrors order_details so seller surfaces share a
// muscle-memory button arrangement.
// =============================================================================
class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({required this.onEdit});

  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(
          top: BorderSide(color: _divider, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Iconsax.archive_2, size: 18),
                    label: Text(
                      'Arxivlash',
                      style: TextStyle(fontFamily: AppFonts.seller, 
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                        height: 1.0,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: _outline, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 7,
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Iconsax.edit_2,
                        size: 18, color: Colors.white),
                    label: Text(
                      'Tahrirlash',
                      style: TextStyle(fontFamily: AppFonts.seller, 
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -0.1,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
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
// Shared bits
// =============================================================================
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontFamily: AppFonts.seller, 
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _ink,
        letterSpacing: -0.2,
        height: 1.2,
      ),
    );
  }
}

// =============================================================================
// Mock data — bundled here so the screen renders without a repository or
// bloc wired up. Swap to real data when the API contract lands.
// =============================================================================
@immutable
class _MockProduct {
  const _MockProduct({
    required this.title,
    required this.priceLabel,
    required this.oldPriceLabel,
    required this.discountPercent,
    required this.stock,
    required this.images,
  });

  final String title;
  final String priceLabel;
  final String? oldPriceLabel;
  final int discountPercent;
  final int stock;
  final List<String> images;
}

const _kMockProduct = _MockProduct(
  title: 'Klassik kuxnya jihozlari',
  priceLabel: '9 800 000',
  oldPriceLabel: '11 200 000',
  discountPercent: 13,
  stock: 2,
  images: [
    'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=900',
    'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=900',
    'https://images.unsplash.com/photo-1493663284031-b7e3aefcae8e?w=900',
    'https://images.unsplash.com/photo-1558211583-d26f610c1eb1?w=900',
  ],
);
