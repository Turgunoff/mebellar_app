import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../auth/auth_bottom_sheet.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/auth_cubit.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/models/shop_profile.dart';
import '../../../../shared/models/working_hours.dart';
import '../../../../shared/repositories/shop_repository.dart';
import '../../../../shared/sharing/shop_share.dart';
import '../../home/widgets/premium/premium_product_card.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../../favorites/bloc/favorites_bloc.dart';
import '../cubit/shop_profile_cubit.dart';

part 'shop_profile_cards.dart';
part 'shop_profile_badges.dart';

/// `color` is nullable: pass an adaptive `PremiumTokens.of(context).dark` from
/// the call site (it can't be a const default).
TextStyle _ts({
  required double size,
  FontWeight weight = FontWeight.w500,
  Color? color,
  double height = 1.3,
  double letterSpacing = 0,
}) {
  return TextStyle(
    fontFamily: AppFonts.seller,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

String _money(num value) => NumberFormat('#,###', 'uz').format(value);

// ═══════════════════════════════════════════════════════════════════════════
// Customer-native section primitives — replace the seller kit's SectionCard /
// SectionTitle (which read SellerColors). These flip with customer dark mode
// via PremiumTokens. Shared with the `part` file (shop_profile_cards).
// ═══════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, this.accent});

  final String text;

  /// Optional brand accent — draws a small leading bar so each section header
  /// subtly echoes the seller's brand colour.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: PremiumTokens.of(context).dark,
        letterSpacing: -0.2,
        height: 1.2,
      ),
    );
    if (accent == null) return title;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 15,
          margin: const EdgeInsets.only(right: 9),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title,
      ],
    );
  }
}

/// Public seller/shop profile, pushed at `/shop/:id` from the product detail
/// page's seller card.
class ShopProfileScreen extends StatelessWidget {
  const ShopProfileScreen({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ShopProfileCubit(sl<ShopRepository>())..load(shopId),
      child: _ShopProfileView(shopId: shopId),
    );
  }
}

class _ShopProfileView extends StatelessWidget {
  const _ShopProfileView({required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTokens.of(context).background,
      body: BlocBuilder<ShopProfileCubit, ShopProfileState>(
        builder: (context, state) {
          // The ready screen owns its own scroll-aware top bar (so the shop
          // name can pin on scroll); loading/error just need a static back
          // button over a non-scrolling body.
          return switch (state.status) {
            ShopProfileStatus.ready => _ReadyContent(
              shop: state.shop!,
              products: state.products,
            ),
            ShopProfileStatus.loading => const Stack(
              children: [
                Positioned.fill(child: _LoadingState()),
                _FloatingBackButton(),
              ],
            ),
            ShopProfileStatus.error => Stack(
              children: [
                Positioned.fill(
                  child: _ErrorState(
                    onRetry: () =>
                        context.read<ShopProfileCubit>().load(shopId),
                  ),
                ),
                const _FloatingBackButton(),
              ],
            ),
          };
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Ready content
// ═══════════════════════════════════════════════════════════════════════════

class _ReadyContent extends StatefulWidget {
  const _ReadyContent({required this.shop, required this.products});

  final ShopProfile shop;
  final List<ProductModel> products;

  @override
  State<_ReadyContent> createState() => _ReadyContentState();
}

class _ReadyContentState extends State<_ReadyContent> {
  final ScrollController _scrollController = ScrollController();

  /// 0 → header fully expanded (transparent bar); 1 → collapsed (white bar +
  /// shop-name title). Driven by the scroll offset against the cover height.
  double _collapse = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    // Fade the bar in over the last stretch of the cover collapse, so the
    // title lands just as the in-header name scrolls under the bar.
    const fadeEnd = _ShopHeader._coverH + 8;
    const fadeStart = fadeEnd - 70;
    final offset = _scrollController.offset;
    final double next;
    if (offset <= fadeStart) {
      next = 0;
    } else if (offset >= fadeEnd) {
      next = 1;
    } else {
      next = (offset - fadeStart) / (fadeEnd - fadeStart);
    }
    if ((next - _collapse).abs() > 0.02) {
      setState(() => _collapse = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final shop = widget.shop;
    final products = widget.products;
    // The seller's brand colour drives the accents on this screen: `brand` is
    // the raw fill (contact buttons), `brandInk` a legible-on-surface variant
    // for tints (section bars, stat icons, the today marker). With no brand
    // set both resolve to the terracotta fallback, so the look is unchanged.
    final brand = _brandColor(shop.brandColor);
    final brandInk = _brandAccent(context, brand);
    final cards = <Widget>[
      _StatsCard(shop: shop, accent: brandInk),
      // Trust badges moved up into the header (ShopProfileBadgesRow), filtered
      // to public social-proof milestones — no separate card here anymore.
      if ((shop.description ?? '').isNotEmpty)
        _AboutCard(text: shop.description!, accent: brandInk),
      if (shop.hasPhone || shop.hasTelegram)
        _ContactCard(shop: shop, brand: brand),
      if (shop.hasAddress || shop.hasLocation)
        _LocationCard(shop: shop, accent: brandInk),
      if (shop.workingHours.hasAnyOpenDay)
        _HoursCard(hours: shop.workingHours, accent: brandInk),
    ];

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _ShopHeader(shop: shop)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final card in cards) ...[
                      card,
                      const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          tr('shop.products_section_title'),
                          style: _ts(
                            size: 17,
                            weight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: pt.dark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (products.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: brandInk.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${products.length}',
                              style: _ts(
                                size: 12.5,
                                weight: FontWeight.w800,
                                color: brandInk,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            if (products.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _EmptyProducts(),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    // 0.65 matches the favourites/search grids — the value
                    // PremiumProductCard's fixed layout needs to avoid overflow.
                    childAspectRatio: 0.60,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, i) =>
                      _ShopProductCard(product: products[i]),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
        _TopBar(shopId: shop.id, name: shop.name, collapse: _collapse),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Header — cover, logo, name, verified/join subtitle
// ═══════════════════════════════════════════════════════════════════════════

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.shop});

  final ShopProfile shop;

  static const double _coverH = 168;
  static const double _logoD = 92;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final brand = _brandColor(shop.brandColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _coverH + topPad,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              _cover(brand),
              // Bottom scrim keeps the hanging logo + any light cover legible.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x22000000)],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                bottom: -_logoD / 2,
                child: _Logo(shop: shop, brand: brand, size: _logoD),
              ),
            ],
          ),
        ),
        SizedBox(height: _logoD / 2 + 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shop.name,
                style: _ts(
                  size: 22,
                  weight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.2,
                  color: pt.dark,
                ),
              ),
              const SizedBox(height: 6),
              _SubtitleLine(shop: shop),
              // Trust badges sit between the verified subtitle and the stats
              // card; the widget self-hides (and drops its top padding) when the
              // seller has earned no public milestones.
              ShopProfileBadgesRow(achievements: shop.unlockedAchievements),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cover(Color brand) {
    if (shop.coverUrl != null) {
      return CachedNetworkImage(
        imageUrl: shop.coverUrl!,
        fit: BoxFit.cover,
        memCacheWidth: 1080,
        placeholder: (_, _) => Container(color: brand.withValues(alpha: 0.18)),
        errorWidget: (_, _, _) => _gradient(brand),
      );
    }
    return _gradient(brand);
  }

  Widget _gradient(Color brand) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            brand.withValues(alpha: 0.85),
            brand.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Iconsax.shop,
          size: 56,
          color: Colors.white.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _SubtitleLine extends StatelessWidget {
  const _SubtitleLine({required this.shop});

  final ShopProfile shop;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final parts = <String>[
      if (shop.isVerified) tr('shop.verified'),
      if (shop.createdAt != null)
        tr(
          'shop.since_year',
          namedArgs: {'year': shop.createdAt!.year.toString()},
        ),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        if (shop.isVerified) ...[
          Icon(Iconsax.verify, size: 15, color: pt.success),
          const SizedBox(width: 5),
        ],
        Expanded(
          child: Text(
            parts.join(' · '),
            style: _ts(
              size: 12.5,
              weight: FontWeight.w600,
              color: shop.isVerified ? pt.success : pt.grey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.shop, required this.brand, required this.size});

  final ShopProfile shop;
  final Color brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: shop.logoUrl != null
            ? CachedNetworkImage(
                imageUrl: shop.logoUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 240,
                placeholder: (_, _) =>
                    Container(color: brand.withValues(alpha: 0.12)),
                errorWidget: (_, _, _) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: brand.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Icon(Iconsax.shop, size: size * 0.4, color: brand),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Stats card — product count · rating · review count
// ═══════════════════════════════════════════════════════════════════════════

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.shop, required this.accent});

  final ShopProfile shop;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        children: [
          _Stat(
            value: '${shop.productCount}',
            label: tr('shop.stat_products'),
            icon: Iconsax.box,
            accent: accent,
          ),
          const _StatDivider(),
          _Stat(
            value: shop.hasRating ? shop.rating!.toStringAsFixed(1) : '—',
            label: tr('shop.stat_rating'),
            icon: Iconsax.star_1,
            accent: shop.hasRating ? const Color(0xFFE8A33D) : null,
          ),
          const _StatDivider(),
          _Stat(
            value: '${shop.reviewCount}',
            label: tr('shop.stat_reviews'),
            icon: Iconsax.message_text_1,
            accent: accent,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    this.accent,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: accent ?? PremiumTokens.accent),
          const SizedBox(height: 7),
          Text(
            value,
            style: _ts(
              size: 18,
              weight: FontWeight.w800,
              letterSpacing: -0.4,
              color: pt.dark,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: _ts(size: 11.5, color: pt.grey)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      color: PremiumTokens.of(context).divider,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Contact card — call + Telegram
// ═══════════════════════════════════════════════════════════════════════════

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.shop, required this.brand});

  final ShopProfile shop;
  final Color brand;

  /// Guests browse the whole profile freely, but contacting a seller needs an
  /// account — it captures the lead (phone), keeps the seller's contacts off
  /// scrapers, and keeps deals on-platform. Records the tap (with whether it
  /// was gated) and, for a guest, opens the login flow; returns `true` once
  /// the caller may proceed (already signed in, or a fresh sign-in succeeded
  /// and the screen is still mounted) so the action resumes automatically.
  Future<bool> _passContactGate(BuildContext context, String channel) async {
    final isGuest = context.read<AuthCubit>().state is AppAuthUnauthenticated;
    unawaited(
      sl<AnalyticsService>().sellerContacted(
        shopId: shop.id,
        channel: channel,
        gated: isGuest,
      ),
    );
    if (!isGuest) return true;
    final ok = await showAuthScreen(context);
    return ok && context.mounted;
  }

  Future<void> _call(BuildContext context) async {
    if (!await _passContactGate(context, 'call')) return;
    final phone = shop.contactPhone;
    if (phone == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Clipboard.setData(ClipboardData(text: phone));
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('shop.phone_copied_2', namedArgs: {'phone': phone})),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _telegram(BuildContext context) async {
    if (!await _passContactGate(context, 'telegram')) return;
    final username = shop.telegramUsername;
    if (username == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final handle = username.replaceFirst(RegExp(r'^@'), '');
    final ok = await launchUrl(
      Uri.parse('https://t.me/$handle'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('shop.telegram_open_failed')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The Call button is the brand-coloured primary CTA (contrast-aware label).
    // Telegram keeps its native blue + white so it stays instantly recognisable
    // rather than blending into the seller's brand.
    final pt = PremiumTokens.of(context);
    return _SectionCard(
      child: Row(
        children: [
          if (shop.hasPhone)
            Expanded(
              child: _ContactButton(
                icon: Iconsax.call,
                label: tr('shop.contact_call'),
                background: brand,
                foreground: _onBrand(brand),
                onTap: () => _call(context),
              ),
            ),
          if (shop.hasPhone && shop.hasTelegram) const SizedBox(width: 10),
          if (shop.hasTelegram)
            Expanded(
              child: _ContactButton(
                icon: Iconsax.send_2,
                label: tr('shop.telegram'),
                background: pt.telegram,
                foreground: pt.onTelegram,
                onTap: () => _telegram(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        splashColor: foreground.withValues(alpha: 0.12),
        highlightColor: foreground.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Text(
                label,
                style: _ts(
                  size: 14,
                  weight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// About card
// ═══════════════════════════════════════════════════════════════════════════

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(text: tr('shop.about_shop'), accent: accent),
          const SizedBox(height: 12),
          Text(text, style: _ts(size: 13.5, color: pt.dark, height: 1.5)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Location card
// ═══════════════════════════════════════════════════════════════════════════

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.shop, required this.accent});

  final ShopProfile shop;
  final Color accent;

  Future<void> _openMap(BuildContext context) async {
    final lat = shop.latitude, lon = shop.longitude;
    if (lat == null || lon == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final label = shop.name.isNotEmpty
        ? ' (${Uri.encodeComponent(shop.name)})'
        : '';
    final geo = Uri.parse('geo:$lat,$lon?q=$lat,$lon$label');
    if (await canLaunchUrl(geo)) {
      await launchUrl(geo, mode: LaunchMode.externalApplication);
      return;
    }
    final web = Uri.parse(
      'https://yandex.com/maps/?ll=$lon,$lat&z=16&pt=$lon,$lat',
    );
    final ok = await launchUrl(web, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('shop.map_open_failed')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(text: tr('shop.address_section_title'), accent: accent),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Iconsax.location, size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  shop.hasAddress ? shop.address! : tr('shop.marked_on_map'),
                  style: _ts(size: 13.5, color: pt.dark, height: 1.4),
                ),
              ),
            ],
          ),
          if (shop.hasLocation) ...[
            const SizedBox(height: 14),
            Material(
              color: pt.background,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _openMap(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.map_1, size: 17, color: pt.dark),
                      const SizedBox(width: 8),
                      Text(
                        tr('shop.view_on_map'),
                        style: _ts(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: pt.dark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Working hours card
// ═══════════════════════════════════════════════════════════════════════════

Map<DayOfWeek, String> get _dayNamesUz => {
  DayOfWeek.monday: tr('shop.day_monday'),
  DayOfWeek.tuesday: tr('shop.day_tuesday'),
  DayOfWeek.wednesday: tr('shop.day_wednesday'),
  DayOfWeek.thursday: tr('shop.day_thursday'),
  DayOfWeek.friday: tr('shop.day_friday'),
  DayOfWeek.saturday: tr('shop.day_saturday'),
  DayOfWeek.sunday: tr('shop.day_sunday'),
};

class _HoursCard extends StatelessWidget {
  const _HoursCard({required this.hours, required this.accent});

  final WeeklyHours hours;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final now = DateTime.now();
    final today = DayOfWeek.values[now.weekday - 1];
    final openNow = _isOpenNow(hours, now);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionTitle(
                text: tr('shop.working_hours_title'),
                accent: accent,
              ),
              const Spacer(),
              _CallStatusPill(openNow: openNow),
            ],
          ),
          const SizedBox(height: 8),
          _OnlineOrdersHint(),
          const SizedBox(height: 12),
          for (final day in DayOfWeek.values) ...[
            _HoursRow(
              name: _dayNamesUz[day]!,
              hours: hours[day],
              isToday: day == today,
              accent: accent,
            ),
            if (day != DayOfWeek.sunday)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Divider(height: 1, thickness: 1, color: pt.divider),
              ),
          ],
        ],
      ),
    );
  }
}

class _CallStatusPill extends StatelessWidget {
  const _CallStatusPill({required this.openNow});

  final bool openNow;

  @override
  Widget build(BuildContext context) {
    final color = openNow
        ? PremiumTokens.of(context).success
        : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            openNow ? tr('shop.call_open_now') : tr('shop.call_closed_now'),
            style: _ts(size: 11.5, weight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _OnlineOrdersHint extends StatelessWidget {
  const _OnlineOrdersHint();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Row(
      children: [
        Icon(Iconsax.shopping_bag, size: 14, color: pt.success),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            tr('shop.online_orders_always'),
            style: _ts(size: 12, weight: FontWeight.w500, color: pt.greyLight),
          ),
        ),
      ],
    );
  }
}

class _HoursRow extends StatelessWidget {
  const _HoursRow({
    required this.name,
    required this.hours,
    required this.isToday,
    required this.accent,
  });

  final String name;
  final DayHours hours;
  final bool isToday;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final String value;
    if (hours.closed || hours.open == null || hours.close == null) {
      value = tr('shop.day_off');
    } else if (hours.isOpen24h) {
      value = tr('shop.open_24h');
    } else {
      value = '${hours.open} – ${hours.close}';
    }
    final weight = isToday ? FontWeight.w700 : FontWeight.w500;
    final color = (hours.closed || hours.open == null) ? pt.greyLight : pt.dark;
    return Row(
      children: [
        if (isToday) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          name,
          style: _ts(
            size: 13,
            weight: weight,
            color: isToday ? accent : pt.dark,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: _ts(size: 13, weight: weight, color: color),
        ),
      ],
    );
  }
}
