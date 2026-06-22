import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/seller_product.dart';
import '../../../../shared/repositories/seller_product_repository.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../../shared/widgets/error_state.dart';
import '../data/seller_set_repository.dart';

/// Create-a-set flow: name field + a multi-select list of the seller's OWN
/// products. Saving POSTs `/seller/sets` and pops `true` so the list refreshes.
///
/// Seller mode is Uzbek-only with seller tokens (`SellerColors.of(context)`,
/// `AppFonts.seller`) — no `tr()` / customer tokens here.
class SellerSetEditorScreen extends StatefulWidget {
  const SellerSetEditorScreen({super.key});

  @override
  State<SellerSetEditorScreen> createState() => _SellerSetEditorScreenState();
}

class _SellerSetEditorScreenState extends State<SellerSetEditorScreen> {
  final _nameCtrl = TextEditingController();
  final _setRepo = sl<WoodySellerSetRepository>();
  final _productRepo = sl<SellerProductRepository>();

  /// Member order matters server-side, so selection is an ordered list keyed
  /// by product id — first ticked is the first member.
  final List<String> _selected = [];

  List<SellerProduct> _products = const [];
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
    _loadProducts();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      // A garnitur groups sellable items, so only approved products are
      // offered as candidates — pulling a big page keeps it single-shot.
      final page = await _productRepo.list(
        filter: const SellerProductFilter(
          statuses: {SellerProductStatus.approved},
        ),
        perPage: 100,
      );
      if (!mounted) return;
      setState(() {
        _products = page.items;
        _loading = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message ?? 'Mahsulotlarni yuklab bo\'lmadi';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Mahsulotlarni yuklab bo\'lmadi';
        _loading = false;
      });
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty && _selected.length >= 2 && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      await _setRepo.createSet(
        name: _nameCtrl.text.trim(),
        productIds: List<String>.from(_selected),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(_messageFor(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError('Setni saqlab bo\'lmadi. Qayta urinib ko\'ring.');
    }
  }

  String _messageFor(ApiError e) {
    if (e.code == 'product_not_in_shop') {
      return 'Tanlangan mahsulotlardan biri sizga tegishli emas.';
    }
    if (e.isValidation) {
      return 'Kamida bitta mahsulot tanlang.';
    }
    return e.message ?? 'Setni saqlab bo\'lmadi. Qayta urinib ko\'ring.';
  }

  void _showError(String message) {
    final c = SellerColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: c.negative,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: AppFonts.seller,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        iconTheme: IconThemeData(color: c.ink),
        title: Text(
          'Yangi set',
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: c.ink,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: _buildBody(c),
      bottomNavigationBar: _SaveBar(
        enabled: _canSave,
        saving: _saving,
        selectedCount: _selected.length,
        onSave: _save,
      ),
    );
  }

  Widget _buildBody(SellerColors c) {
    if (_loading) {
      return const Center(child: BrandLoadingIndicator());
    }
    if (_loadError != null && _products.isEmpty) {
      return ErrorState(message: _loadError, onRetry: _loadProducts);
    }
    return BrandRefreshIndicator(
      color: AppColors.sellerPrimary,
      onRefresh: _loadProducts,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _NameField(controller: _nameCtrl),
          const SizedBox(height: 20),
          Text(
            'Mahsulotlar',
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: c.ink,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Setga kamida 2 ta mahsulot qo\'shing',
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: c.grey,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          if (_products.isEmpty)
            _NoProductsHint(c: c)
          else
            ..._products.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProductPickTile(
                  product: p,
                  selected: _selected.contains(p.id),
                  order: _selected.indexOf(p.id),
                  onTap: () => _toggle(p.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set nomi',
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: c.ink,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          cursorColor: AppColors.sellerPrimary,
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: c.ink,
          ),
          decoration: InputDecoration(
            hintText: 'Masalan: Yotoqxona garnituri',
            hintStyle: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: c.greyMid,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 14,
            ),
            filled: true,
            fillColor: c.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: c.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: c.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.sellerPrimary.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductPickTile extends StatelessWidget {
  const _ProductPickTile({
    required this.product,
    required this.selected,
    required this.order,
    required this.onTap,
  });

  final SellerProduct product;
  final bool selected;

  /// 0-based membership index when selected (-1 when not) — shown as a 1-based
  /// order badge so the seller sees the resulting member order.
  final int order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Material(
      color: selected ? c.primarySoft : c.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.sellerPrimary.withValues(alpha: 0.5)
                  : c.divider,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _Thumb(hero: product.heroImage, order: selected ? order : -1),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    product.name.uz ?? product.name.get('uz'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                      height: 1.25,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected ? Iconsax.tick_circle : Iconsax.add_circle,
                  size: 24,
                  color: selected ? AppColors.sellerPrimary : c.greyMid,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.hero, required this.order});

  final String? hero;

  /// 0-based member position when selected, -1 otherwise.
  final int order;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final placeholder = Container(
      color: c.imageBg,
      alignment: Alignment.center,
      child: Icon(Iconsax.image, size: 20, color: c.greyMid),
    );
    final image = hero == null || hero!.isEmpty
        ? placeholder
        : (hero!.startsWith('http')
              ? CachedNetworkImage(
                  imageUrl: hero!,
                  memCacheWidth: 240,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => placeholder,
                  errorWidget: (_, _, _) => placeholder,
                )
              : Image.asset(
                  hero!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                ));
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (order >= 0)
              Positioned(
                top: 3,
                left: 3,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.sellerPrimary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${order + 1}',
                    style: const TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoProductsHint extends StatelessWidget {
  const _NoProductsHint({required this.c});

  final SellerColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.fillSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'Set yaratish uchun avval tasdiqlangan mahsulotlaringiz bo\'lishi kerak.',
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: c.grey,
          height: 1.4,
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.enabled,
    required this.saving,
    required this.selectedCount,
    required this.onSave,
  });

  final bool enabled;
  final bool saving;
  final int selectedCount;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: enabled ? onSave : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.sellerPrimary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: c.fillSoft,
            disabledForegroundColor: c.greyMid,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(
                  selectedCount > 0 ? 'Saqlash ($selectedCount)' : 'Saqlash',
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
