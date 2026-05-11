import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/seller_product.dart';

// Local tokens — kept here so the screen reads top-to-bottom without
// chasing theme indirection. Plus Jakarta Sans is applied to every
// `Text` explicitly via `GoogleFonts.plusJakartaSans` so the surface
// is immune to the M3 surface tint that the teal seller seed otherwise
// bleeds onto neutral backgrounds.
const _ink = Color(0xFF1D1D1D);
const _grey = Color(0xFF757575);
const _greyMid = Color(0xFFBDBDBD);
const _divider = Color(0xFFEFEFEF);
const _outline = Color(0xFFE3E3E3);
const _fillSoft = Color(0xFFF7F7F7);
const _terracottaTint = Color(0x14C27A5F);

const int _kMaxPhotos = 10;

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.existing});

  final SellerProduct? existing;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  // Text controllers ---------------------------------------------------------
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _width;   // Eni
  late final TextEditingController _length;  // Bo'yi
  late final TextEditingController _depth;   // Chuqurligi
  late final TextEditingController _material;
  late final TextEditingController _productionDays;
  late final TextEditingController _deliveryPrice;
  late final TextEditingController _assemblyPrice;
  late final TextEditingController _warrantyMonths;

  // Selection state ----------------------------------------------------------
  String? _categorySlug;
  String? _subCategorySlug;
  final Set<String> _selectedColors = {};
  int _discountPercent = 0;

  // Toggles ------------------------------------------------------------------
  bool _deliveryAvailable = true;
  bool _assemblyAvailable = false;

  // Mock images: monotonically increasing IDs so each thumbnail can be
  // keyed and removed independently. The IDs themselves are arbitrary;
  // the count drives the (n / max) caption.
  final List<int> _images = [];
  int _nextImageId = 1;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name.get('uz') ?? '');
    _description = TextEditingController(
      text: existing?.description.get('uz') ?? '',
    );
    _price = TextEditingController(
      text: existing == null || existing.price == 0
          ? ''
          : _formatThousands(existing.price.toInt()),
    );
    _width = TextEditingController(
      text: existing?.widthCm?.toString() ?? '',
    );
    _length = TextEditingController(
      text: existing?.lengthCm?.toString() ?? '',
    );
    _depth = TextEditingController(
      text: existing?.heightCm?.toString() ?? '',
    );
    _material = TextEditingController();
    _productionDays = TextEditingController(text: '3-5');
    _deliveryPrice = TextEditingController();
    _assemblyPrice = TextEditingController();
    _warrantyMonths = TextEditingController(text: '12');
    _categorySlug = existing?.categorySlug;
    _price.addListener(_onPriceChanged);
  }

  @override
  void dispose() {
    _price.removeListener(_onPriceChanged);
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _width.dispose();
    _length.dispose();
    _depth.dispose();
    _material.dispose();
    _productionDays.dispose();
    _deliveryPrice.dispose();
    _assemblyPrice.dispose();
    _warrantyMonths.dispose();
    super.dispose();
  }

  void _onPriceChanged() {
    // Calculated discount line below the chips depends on the live price
    // value; rebuild so the UZS amount tracks every keystroke.
    setState(() {});
  }

  // Image picker actions -----------------------------------------------------
  void _addImage() {
    if (_images.length >= _kMaxPhotos) return;
    setState(() {
      _images.add(_nextImageId);
      _nextImageId++;
    });
  }

  void _removeImage(int id) {
    setState(() => _images.remove(id));
  }

  // Category sheets ----------------------------------------------------------
  void _openCategorySheet() async {
    final picked = await showModalBottomSheet<_FurnitureCategory>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CategoryPickerSheet(
        title: 'Kategoriyani tanlang',
        items: _kFurnitureCategories
            .map(
              (c) => _PickerEntry(
                slug: c.slug,
                label: c.label,
                icon: c.icon,
                payload: c,
              ),
            )
            .toList(),
      ),
    );
    if (picked != null) {
      setState(() {
        _categorySlug = picked.slug;
        _subCategorySlug = null;
      });
    }
  }

  void _openSubCategorySheet() async {
    final cat = _categoryBySlug(_categorySlug);
    if (cat == null) return;
    final picked = await showModalBottomSheet<_SubCategory>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CategoryPickerSheet(
        title: cat.label,
        items: cat.subs
            .map(
              (s) => _PickerEntry(
                slug: s.slug,
                label: s.label,
                icon: cat.icon,
                payload: s,
              ),
            )
            .toList(),
      ),
    );
    if (picked != null) {
      setState(() => _subCategorySlug = picked.slug);
    }
  }

  // Discount chips -----------------------------------------------------------
  Future<void> _openCustomDiscountDialog() async {
    final controller = TextEditingController(
      text: _discountPercent == 0 ? '' : '$_discountPercent',
    );
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Maxsus chegirma',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _ink,
            letterSpacing: -0.2,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          cursorColor: AppColors.terracotta,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: '0',
            suffixText: '%',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.terracotta,
                width: 1.4,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Bekor qilish',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: _grey,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.terracotta,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final v = int.tryParse(controller.text) ?? 0;
              Navigator.of(ctx).pop(v.clamp(0, 100));
            },
            child: Text(
              'Saqlash',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    if (picked != null) {
      setState(() => _discountPercent = picked);
    }
  }

  void _save() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _ink,
        behavior: SnackBarBehavior.floating,
        content: Text(
          "Mahsulot e'lon qilindi",
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
    Navigator.of(context).maybePop();
  }

  // Derived values -----------------------------------------------------------
  int get _priceValue => _parseAmount(_price.text);
  int get _discountedPrice =>
      (_priceValue * (100 - _discountPercent) / 100).round();

  @override
  Widget build(BuildContext context) {
    final cat = _categoryBySlug(_categorySlug);
    final sub = cat == null ? null : _subBySlug(cat, _subCategorySlug);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: _FormAppBar(isEdit: widget.existing != null),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            _MediaSection(
              images: _images,
              onAdd: _addImage,
              onRemove: _removeImage,
            ),
            const SizedBox(height: 20),
            _BasicInfoSection(
              nameController: _name,
              descriptionController: _description,
              categoryLabel: cat?.label,
              subCategoryLabel: sub?.label,
              onCategoryTap: _openCategorySheet,
              onSubCategoryTap:
                  _categorySlug == null ? null : _openSubCategorySheet,
            ),
            const SizedBox(height: 20),
            _SpecsSection(
              widthController: _width,
              lengthController: _length,
              depthController: _depth,
              materialController: _material,
              selectedColors: _selectedColors,
              onColorToggle: (slug) => setState(() {
                if (!_selectedColors.add(slug)) {
                  _selectedColors.remove(slug);
                }
              }),
            ),
            const SizedBox(height: 20),
            _PricingSection(
              priceController: _price,
              discountPercent: _discountPercent,
              onDiscountSelected: (v) =>
                  setState(() => _discountPercent = v),
              onCustomTapped: _openCustomDiscountDialog,
              priceValue: _priceValue,
              discountedPrice: _discountedPrice,
            ),
            const SizedBox(height: 20),
            _LogisticsSection(
              productionDaysController: _productionDays,
              deliveryAvailable: _deliveryAvailable,
              onDeliveryChanged: (v) =>
                  setState(() => _deliveryAvailable = v),
              deliveryPriceController: _deliveryPrice,
              assemblyAvailable: _assemblyAvailable,
              onAssemblyChanged: (v) =>
                  setState(() => _assemblyAvailable = v),
              assemblyPriceController: _assemblyPrice,
              warrantyController: _warrantyMonths,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _SaveBottomBar(onSave: _save),
    );
  }
}

// =============================================================================
// 1. App bar — back arrow + bold title, no step indicator, no language tabs
// =============================================================================
class _FormAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _FormAppBar({required this.isEdit});

  final bool isEdit;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.lightBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: _ink,
      leading: IconButton(
        icon: const Icon(Iconsax.arrow_left_2, size: 22, color: _ink),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        isEdit ? 'Mahsulotni tahrirlash' : "Mahsulot qo'shish",
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _ink,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

// =============================================================================
// 2. Section title — bold Jakarta header above each card
// =============================================================================
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _ink,
          letterSpacing: -0.2,
          height: 1.2,
        ),
      ),
    );
  }
}

// =============================================================================
// 3. Form card — pure white, 16px radius, soft shadow
// =============================================================================
class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// =============================================================================
// 4. Media — horizontally scrollable, dashed Add tile + thumbnails (max 10)
// =============================================================================
class _MediaSection extends StatelessWidget {
  const _MediaSection({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  final List<int> images;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final isFull = images.length >= _kMaxPhotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Mahsulot rasmlari'),
        _FormCard(
          child: SizedBox(
            height: 110,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _AddPhotoTile(
                    count: images.length,
                    max: _kMaxPhotos,
                    enabled: !isFull,
                    onTap: onAdd,
                  ),
                  for (var i = 0; i < images.length; i++) ...[
                    const SizedBox(width: 10),
                    _ImageThumbnail(
                      key: ValueKey(images[i]),
                      index: i + 1,
                      onRemove: () => onRemove(images[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({
    required this.count,
    required this.max,
    required this.enabled,
    required this.onTap,
  });

  final int count;
  final int max;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = enabled ? AppColors.terracotta : _greyMid;
    return SizedBox(
      width: 110,
      height: 110,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: accent,
            radius: 14,
            strokeWidth: 1.4,
            dashLength: 6,
            gapLength: 4,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: enabled ? _terracottaTint : _fillSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.add_square, size: 26, color: accent),
                  const SizedBox(height: 6),
                  Text(
                    'Rasm qo\'shish',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: -0.1,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '($count/$max)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? AppColors.terracotta.withValues(alpha: 0.8)
                          : _greyMid,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({
    super.key,
    required this.index,
    required this.onRemove,
  });

  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: _terracottaTint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.terracotta.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Iconsax.gallery,
                  size: 22,
                  color: AppColors.terracotta,
                ),
                const SizedBox(height: 4),
                Text(
                  'Rasm $index',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.terracotta,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          if (index == 1)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.terracotta,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Asosiy',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              shadowColor: Colors.black26,
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _outline, width: 1),
                  ),
                  child: const Icon(
                    Iconsax.close_square,
                    size: 13,
                    color: _ink,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for the rounded-rect dashed border on the Add tile.
// Implemented inline to avoid pulling a `dotted_border` dependency for
// a single ornament. Walks the perimeter via `PathMetric.extractPath`
// drawing alternating dash + gap segments.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength;
}

// =============================================================================
// 5. Basics — name + cascading category fields + multi-line description
// =============================================================================
class _BasicInfoSection extends StatelessWidget {
  const _BasicInfoSection({
    required this.nameController,
    required this.descriptionController,
    required this.categoryLabel,
    required this.subCategoryLabel,
    required this.onCategoryTap,
    required this.onSubCategoryTap,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final String? categoryLabel;
  final String? subCategoryLabel;
  final VoidCallback onCategoryTap;
  final VoidCallback? onSubCategoryTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle("Ma'lumotlar"),
        _FormCard(
          child: Column(
            children: [
              _FormField(
                controller: nameController,
                label: 'Mahsulot nomi',
                hint: "Masalan, Burchakli divan «Roma»",
              ),
              const SizedBox(height: 14),
              _PickerField(
                label: 'Kategoriya',
                value: categoryLabel,
                placeholder: 'Kategoriyani tanlang',
                leadingIcon: Iconsax.category,
                onTap: onCategoryTap,
              ),
              const SizedBox(height: 14),
              _PickerField(
                label: 'Sub-kategoriya',
                value: subCategoryLabel,
                placeholder: onSubCategoryTap == null
                    ? 'Avval kategoriyani tanlang'
                    : 'Sub-kategoriyani tanlang',
                leadingIcon: Iconsax.category_2,
                onTap: onSubCategoryTap,
              ),
              const SizedBox(height: 14),
              _FormField(
                controller: descriptionController,
                label: 'Mahsulot tavsifi',
                hint: "Mahsulot haqida qisqacha ma'lumot",
                minLines: 3,
                maxLines: 6,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.leadingIcon,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String placeholder;
  final IconData leadingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final disabled = onTap == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _grey,
              letterSpacing: 0.1,
            ),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: disabled ? _fillSoft : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _outline, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  leadingIcon,
                  size: 20,
                  color: disabled ? _greyMid : _grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasValue ? value! : placeholder,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasValue ? _ink : _greyMid,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                Icon(
                  Iconsax.arrow_down_1,
                  size: 18,
                  color: disabled ? _greyMid.withValues(alpha: 0.5) : _greyMid,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 6. Specs — dimensions row + material + multi-select color chips
// =============================================================================
class _SpecsSection extends StatelessWidget {
  const _SpecsSection({
    required this.widthController,
    required this.lengthController,
    required this.depthController,
    required this.materialController,
    required this.selectedColors,
    required this.onColorToggle,
  });

  final TextEditingController widthController;
  final TextEditingController lengthController;
  final TextEditingController depthController;
  final TextEditingController materialController;
  final Set<String> selectedColors;
  final ValueChanged<String> onColorToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Xususiyatlar'),
        _FormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                  "O'lchamlari (sm)",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _grey,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _DimensionField(
                      controller: widthController,
                      label: 'Eni',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DimensionField(
                      controller: lengthController,
                      label: "Bo'yi",
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DimensionField(
                      controller: depthController,
                      label: 'Chuqurligi',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _FormField(
                controller: materialController,
                label: 'Material',
                hint: "MDF, LDSP, Yog'och",
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                  'Rangi',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _grey,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _kColors)
                    _ColorChip(
                      label: c.label,
                      swatch: c.swatch,
                      selected: selectedColors.contains(c.slug),
                      onTap: () => onColorToggle(c.slug),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DimensionField extends StatelessWidget {
  const _DimensionField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _outline),
    );
    return TextField(
      controller: controller,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      cursorColor: AppColors.terracotta,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _ink,
        letterSpacing: -0.1,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 12,
        ),
        hintText: label,
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _greyMid,
        ),
        filled: true,
        fillColor: Colors.white,
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.terracotta,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.label,
    required this.swatch,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color swatch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _terracottaTint : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.terracotta : _outline,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                  border: Border.all(color: _outline, width: 1),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.terracotta : _ink,
                  letterSpacing: -0.1,
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
// 7. Pricing — formatted price + discount chips + live calculated total
// =============================================================================
class _PricingSection extends StatelessWidget {
  const _PricingSection({
    required this.priceController,
    required this.discountPercent,
    required this.onDiscountSelected,
    required this.onCustomTapped,
    required this.priceValue,
    required this.discountedPrice,
  });

  final TextEditingController priceController;
  final int discountPercent;
  final ValueChanged<int> onDiscountSelected;
  final VoidCallback onCustomTapped;
  final int priceValue;
  final int discountedPrice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Narx va chegirma'),
        _FormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FormField(
                controller: priceController,
                label: 'Asosiy narx',
                hint: '0',
                suffix: 'UZS',
                keyboardType: TextInputType.number,
                inputFormatters: const [_ThousandsSpaceFormatter()],
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                  'Chegirma foizi',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _grey,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              _DiscountChipRow(
                value: discountPercent,
                onSelected: onDiscountSelected,
                onCustomTapped: onCustomTapped,
              ),
              const SizedBox(height: 14),
              _DiscountSummary(
                priceValue: priceValue,
                discountPercent: discountPercent,
                discountedPrice: discountedPrice,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiscountChipRow extends StatelessWidget {
  const _DiscountChipRow({
    required this.value,
    required this.onSelected,
    required this.onCustomTapped,
  });

  final int value;
  final ValueChanged<int> onSelected;
  final VoidCallback onCustomTapped;

  static const _presets = [0, 10, 20, 30];

  @override
  Widget build(BuildContext context) {
    final isCustom = !_presets.contains(value);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in _presets)
          _DiscountChip(
            label: '$p%',
            selected: !isCustom && value == p,
            onTap: () => onSelected(p),
          ),
        _DiscountChip(
          label: isCustom ? '$value% (Custom)' : 'Custom',
          selected: isCustom,
          onTap: onCustomTapped,
        ),
      ],
    );
  }
}

class _DiscountChip extends StatelessWidget {
  const _DiscountChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.terracotta : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.terracotta : _outline,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : _ink,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscountSummary extends StatelessWidget {
  const _DiscountSummary({
    required this.priceValue,
    required this.discountPercent,
    required this.discountedPrice,
  });

  final int priceValue;
  final int discountPercent;
  final int discountedPrice;

  @override
  Widget build(BuildContext context) {
    final hasPrice = priceValue > 0;
    final hasDiscount = discountPercent > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hasPrice && hasDiscount ? _terracottaTint : _fillSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPrice && hasDiscount
              ? AppColors.terracotta.withValues(alpha: 0.35)
              : _outline,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasDiscount ? Iconsax.discount_shape : Iconsax.tag,
            size: 18,
            color: hasPrice && hasDiscount
                ? AppColors.terracotta
                : _greyMid,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasDiscount ? 'Chegirma bilan' : 'Chegirmasiz',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _grey,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasPrice
                      ? '${_formatThousands(discountedPrice)} UZS'
                      : '— UZS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: hasPrice && hasDiscount
                        ? AppColors.terracotta
                        : _ink,
                    letterSpacing: -0.2,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          if (hasDiscount && hasPrice)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.terracotta,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '-$discountPercent%',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// 8. Logistics — production days + delivery (with conditional price) +
//    free assembly + warranty months
// =============================================================================
class _LogisticsSection extends StatelessWidget {
  const _LogisticsSection({
    required this.productionDaysController,
    required this.deliveryAvailable,
    required this.onDeliveryChanged,
    required this.deliveryPriceController,
    required this.assemblyAvailable,
    required this.onAssemblyChanged,
    required this.assemblyPriceController,
    required this.warrantyController,
  });

  final TextEditingController productionDaysController;
  final bool deliveryAvailable;
  final ValueChanged<bool> onDeliveryChanged;
  final TextEditingController deliveryPriceController;
  final bool assemblyAvailable;
  final ValueChanged<bool> onAssemblyChanged;
  final TextEditingController assemblyPriceController;
  final TextEditingController warrantyController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Yetkazib berish va kafolat'),
        _FormCard(
          child: Column(
            children: [
              _FormField(
                controller: productionDaysController,
                label: 'Tayyorlash / Yetkazish muddati (kun)',
                hint: '3-5',
                suffix: 'kun',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, thickness: 1, color: _divider),
              ),
              _ToggleRow(
                icon: Iconsax.truck_fast,
                title: 'Yetkazib berish mavjud',
                subtitle: "Sotib oluvchiga yetkazib beriladi",
                value: deliveryAvailable,
                onChanged: onDeliveryChanged,
              ),
              if (deliveryAvailable) ...[
                const SizedBox(height: 14),
                _FormField(
                  controller: deliveryPriceController,
                  label: 'Yetkazish narxi',
                  hint: 'Bepul uchun 0 kiriting',
                  suffix: 'UZS',
                  keyboardType: TextInputType.number,
                  inputFormatters: const [_ThousandsSpaceFormatter()],
                  helper: 'Faqat Toshkent shahri va viloyati uchun',
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, thickness: 1, color: _divider),
              ),
              _ToggleRow(
                icon: Iconsax.setting_4,
                title: "O'rnatib berish mavjud",
                subtitle: "Mahsulot xaridor manzilida yig'iladi",
                value: assemblyAvailable,
                onChanged: onAssemblyChanged,
              ),
              if (assemblyAvailable) ...[
                const SizedBox(height: 14),
                _FormField(
                  controller: assemblyPriceController,
                  label: "O'rnatish narxi",
                  hint: 'Bepul uchun 0 kiriting',
                  suffix: 'UZS',
                  keyboardType: TextInputType.number,
                  inputFormatters: const [_ThousandsSpaceFormatter()],
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, thickness: 1, color: _divider),
              ),
              _FormField(
                controller: warrantyController,
                label: 'Kafolat (oy)',
                hint: '0',
                suffix: 'oy',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _terracottaTint,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.terracotta),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _grey,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.terracotta,
        ),
      ],
    );
  }
}

// =============================================================================
// 9. Form field — label above outlined input with optional helper text
// =============================================================================
class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    this.hint,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.minLines,
    this.maxLines = 1,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? minLines;
  final int? maxLines;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _outline, width: 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _grey,
              letterSpacing: 0.1,
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          minLines: minLines,
          maxLines: maxLines,
          cursorColor: AppColors.terracotta,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _ink,
            letterSpacing: -0.1,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _greyMid,
            ),
            suffixText: suffix,
            suffixStyle: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _greyMid,
              letterSpacing: 0.2,
            ),
            filled: true,
            fillColor: Colors.white,
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.terracotta,
                width: 1.4,
              ),
            ),
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              helper!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _grey,
                height: 1.3,
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// 10. Bottom bar — fixed terracotta save button with safe-area + top divider
// =============================================================================
class _SaveBottomBar extends StatelessWidget {
  const _SaveBottomBar({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: FilledButton(
              onPressed: onSave,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.terracotta,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              child: const Text("Saqlash va e'lon qilish"),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 11. Picker bottom sheet — single-tap selector, reused for category + sub
// =============================================================================
class _PickerEntry<T> {
  _PickerEntry({
    required this.slug,
    required this.label,
    required this.icon,
    required this.payload,
  });

  final String slug;
  final String label;
  final IconData icon;
  final T payload;
}

class _CategoryPickerSheet<T> extends StatelessWidget {
  const _CategoryPickerSheet({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_PickerEntry<T>> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ink,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: _divider),
                itemBuilder: (_, i) => _PickerTile(entry: items[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerTile<T> extends StatelessWidget {
  const _PickerTile({required this.entry});

  final _PickerEntry<T> entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(entry.payload),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _terracottaTint,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                entry.icon,
                size: 18,
                color: AppColors.terracotta,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            const Icon(
              Iconsax.arrow_right_3,
              size: 18,
              color: _greyMid,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 12. Number formatting — TextInputFormatter + helpers
// =============================================================================
class _ThousandsSpaceFormatter extends TextInputFormatter {
  const _ThousandsSpaceFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final formatted = _formatThousands(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatThousands(int value) {
  if (value == 0) return '0';
  final s = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return value.isNegative ? '-${buf.toString()}' : buf.toString();
}

int _parseAmount(String text) {
  final digits = text.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return 0;
  return int.tryParse(digits) ?? 0;
}

// =============================================================================
// 13. Furniture taxonomy — mock category + sub-category data
// =============================================================================
@immutable
class _FurnitureCategory {
  const _FurnitureCategory({
    required this.slug,
    required this.label,
    required this.icon,
    required this.subs,
  });

  final String slug;
  final String label;
  final IconData icon;
  final List<_SubCategory> subs;
}

@immutable
class _SubCategory {
  const _SubCategory({required this.slug, required this.label});

  final String slug;
  final String label;
}

const _kFurnitureCategories = <_FurnitureCategory>[
  _FurnitureCategory(
    slug: 'soft',
    label: 'Yumshoq mebel',
    icon: Iconsax.home_2,
    subs: [
      _SubCategory(slug: 'sofa', label: 'Divanlar'),
      _SubCategory(slug: 'corner_sofa', label: 'Burchakli divanlar'),
      _SubCategory(slug: 'armchair', label: 'Kreslolar'),
      _SubCategory(slug: 'pouf', label: 'Pufiklar'),
    ],
  ),
  _FurnitureCategory(
    slug: 'tables_chairs',
    label: 'Stol va stullar',
    icon: Iconsax.element_3,
    subs: [
      _SubCategory(slug: 'dining_table', label: 'Yemak stoli'),
      _SubCategory(slug: 'coffee_table', label: 'Jurnal stoli'),
      _SubCategory(slug: 'chair', label: 'Stullar'),
      _SubCategory(slug: 'bar_stool', label: 'Bar stullari'),
    ],
  ),
  _FurnitureCategory(
    slug: 'bedroom',
    label: 'Yotoq xonasi',
    icon: Iconsax.moon,
    subs: [
      _SubCategory(slug: 'bed', label: 'Krovatlar'),
      _SubCategory(slug: 'wardrobe', label: 'Shkaflar'),
      _SubCategory(slug: 'commode', label: 'Komodlar'),
      _SubCategory(slug: 'nightstand', label: 'Tumbalar'),
    ],
  ),
  _FurnitureCategory(
    slug: 'kitchen',
    label: 'Oshxona mebellari',
    icon: Iconsax.cup,
    subs: [
      _SubCategory(slug: 'kitchen_set', label: 'Oshxona garnituri'),
      _SubCategory(slug: 'kitchen_bar', label: 'Bar stoli'),
      _SubCategory(slug: 'shelves', label: 'Polkalar'),
    ],
  ),
];

_FurnitureCategory? _categoryBySlug(String? slug) {
  if (slug == null) return null;
  for (final c in _kFurnitureCategories) {
    if (c.slug == slug) return c;
  }
  return null;
}

_SubCategory? _subBySlug(_FurnitureCategory cat, String? slug) {
  if (slug == null) return null;
  for (final s in cat.subs) {
    if (s.slug == slug) return s;
  }
  return null;
}

// =============================================================================
// 14. Color swatch palette — used by `_ColorChip` in the specs section
// =============================================================================
@immutable
class _ColorOption {
  const _ColorOption({
    required this.slug,
    required this.label,
    required this.swatch,
  });

  final String slug;
  final String label;
  final Color swatch;
}

const _kColors = <_ColorOption>[
  _ColorOption(slug: 'white', label: 'Oq', swatch: Color(0xFFFFFFFF)),
  _ColorOption(slug: 'black', label: 'Qora', swatch: Color(0xFF1D1D1D)),
  _ColorOption(slug: 'grey', label: 'Kulrang', swatch: Color(0xFF9CA3AF)),
  _ColorOption(slug: 'brown', label: 'Jigarrang', swatch: Color(0xFF8B5E3C)),
  _ColorOption(slug: 'beige', label: 'Bej', swatch: Color(0xFFE9DCC4)),
  _ColorOption(slug: 'green', label: 'Yashil', swatch: Color(0xFF4F7A52)),
  _ColorOption(slug: 'blue', label: 'Ko\'k', swatch: Color(0xFF3B6CB5)),
  _ColorOption(slug: 'yellow', label: 'Sariq', swatch: Color(0xFFE6C25C)),
];
