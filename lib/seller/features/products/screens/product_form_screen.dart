import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/category_model.dart';
import '../../../../shared/models/tariff.dart';
import '../bloc/add_product_cubit.dart';
import '../data/add_product_repository.dart';
import '../widgets/tariff_limit_dialog.dart';

// Local tokens kept on this screen so the form reads top-to-bottom without
// chasing theme indirection. Branded interactive surfaces (the Save CTA,
// chips, toggles, color rings) flow through `colorScheme.primary` so the
// seller's Deep Indigo replaces the customer Terracotta.
const _ink = Color(0xFF1D1D1D);
const _grey = Color(0xFF757575);
const _greyMid = Color(0xFFBDBDBD);
const _divider = Color(0xFFEFEFEF);
const _outline = Color(0xFFE3E3E3);
const _fillSoft = Color(0xFFF7F7F7);

class ProductFormScreen extends StatelessWidget {
  const ProductFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AddProductCubit(
        repository: sl<AddProductRepository>(),
      )..loadContext(),
      child: const _ProductFormView(),
    );
  }
}

class _ProductFormView extends StatefulWidget {
  const _ProductFormView();

  @override
  State<_ProductFormView> createState() => _ProductFormViewState();
}

class _ProductFormViewState extends State<_ProductFormView> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _width;
  late final TextEditingController _height;
  late final TextEditingController _depth;
  late final TextEditingController _material;
  late final TextEditingController _productionDays;
  late final TextEditingController _deliveryPrice;
  late final TextEditingController _warrantyMonths;

  final ImagePicker _picker = ImagePicker();
  bool _tariffPromptShown = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _description = TextEditingController();
    _price = TextEditingController();
    _width = TextEditingController();
    _height = TextEditingController();
    _depth = TextEditingController();
    _material = TextEditingController();
    _productionDays = TextEditingController(text: '3-5');
    _deliveryPrice = TextEditingController();
    _warrantyMonths = TextEditingController(text: '12');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _width.dispose();
    _height.dispose();
    _depth.dispose();
    _material.dispose();
    _productionDays.dispose();
    _deliveryPrice.dispose();
    _warrantyMonths.dispose();
    super.dispose();
  }

  Future<void> _pickImage(BuildContext context) async {
    final cubit = context.read<AddProductCubit>();
    final state = cubit.state;
    if (!state.canPickMoreImages) return;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 92,
    );
    if (picked == null) return;
    cubit.addImage(File(picked.path));
  }

  Future<void> _openCategorySheet(BuildContext context) async {
    final cubit = context.read<AddProductCubit>();
    final categories = cubit.state.context?.categories ?? const [];
    if (categories.isEmpty) return;
    final primary = Theme.of(context).colorScheme.primary;

    final picked = await showModalBottomSheet<CategoryModel>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CategoryPickerSheet(
        title: 'Kategoriyani tanlang',
        items: categories,
        accent: primary,
      ),
    );
    if (picked != null) {
      cubit.selectCategory(picked.id);
    }
  }

  Future<void> _openCustomDiscountDialog(BuildContext context) async {
    final cubit = context.read<AddProductCubit>();
    final primary = Theme.of(context).colorScheme.primary;
    final controller = TextEditingController(
      text: cubit.state.discountPercent == 0
          ? ''
          : '${cubit.state.discountPercent}',
    );
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Maxsus chegirma',
          style: TextStyle(
            fontFamily: AppFonts.seller,
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
          cursorColor: primary,
          style: const TextStyle(
            fontFamily: AppFonts.seller,
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
              borderSide: BorderSide(color: primary, width: 1.4),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Bekor qilish',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontWeight: FontWeight.w600,
                color: _grey,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final v = int.tryParse(controller.text) ?? 0;
              Navigator.of(ctx).pop(v.clamp(0, 100));
            },
            child: const Text(
              'Saqlash',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    if (picked != null) {
      cubit.setDiscountPercent(picked);
    }
  }

  void _handleTariffBlocked(BuildContext context, TariffSnapshot? snap) {
    if (_tariffPromptShown || snap == null) return;
    _tariffPromptShown = true;
    final navigator = Navigator.of(context);
    showTariffLimitDialog(context, snapshot: snap).then((_) {
      if (mounted) navigator.maybePop();
    });
  }

  Future<void> _save(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final cubit = context.read<AddProductCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await cubit.submit();
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: _ink,
          behavior: SnackBarBehavior.floating,
          content: Text(
            "Mahsulot e'lon qilindi",
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
      navigator.maybePop(true);
    } else {
      final err = cubit.state.error;
      if (err != null) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            content: Text(
              err,
              style: const TextStyle(
                fontFamily: AppFonts.seller,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AddProductCubit, AddProductState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == AddProductStatus.tariffBlocked) {
          _handleTariffBlocked(
            context,
            context.read<AddProductCubit>().tariffSnapshot,
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: const _FormAppBar(),
          body: switch (state.status) {
            AddProductStatus.loadingContext => Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            AddProductStatus.tariffBlocked => _TariffBlockedView(
                snapshot:
                    context.read<AddProductCubit>().tariffSnapshot,
              ),
            _ => _buildForm(context, state),
          },
          bottomNavigationBar: state.status == AddProductStatus.loadingContext
              ? null
              : _SaveBottomBar(
                  enabled: state.canSubmit &&
                      state.status != AddProductStatus.saving,
                  busy: state.status == AddProductStatus.saving,
                  onSave: () => _save(context),
                ),
        );
      },
    );
  }

  Widget _buildForm(BuildContext context, AddProductState state) {
    final cubit = context.read<AddProductCubit>();
    return SafeArea(
      top: false,
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          _MediaSection(
            files: state.imageFiles,
            maxImages: state.maxImages,
            onAdd: () => _pickImage(context),
            onRemove: cubit.removeImageAt,
          ),
          const SizedBox(height: 20),
          _BasicInfoSection(
            nameController: _name,
            descriptionController: _description,
            categoryLabel: cubit.findCategory(state.categoryId)?.name,
            onCategoryTap: () => _openCategorySheet(context),
            onNameChanged: cubit.setName,
            onDescriptionChanged: cubit.setDescription,
          ),
          const SizedBox(height: 20),
          _SpecsSection(
            widthController: _width,
            heightController: _height,
            depthController: _depth,
            materialController: _material,
            selectedColor: state.colorSlug,
            onWidthChanged: (v) => cubit.setDimensions(width: v),
            onHeightChanged: (v) => cubit.setDimensions(height: v),
            onDepthChanged: (v) => cubit.setDimensions(depth: v),
            onMaterialChanged: cubit.setMaterial,
            onColorToggle: cubit.selectColor,
          ),
          const SizedBox(height: 20),
          _PricingSection(
            priceController: _price,
            discountPercent: state.discountPercent,
            priceValue: state.price.toInt(),
            discountedPrice: state.effectivePrice.toInt(),
            onPriceChanged: cubit.setPrice,
            onDiscountSelected: cubit.setDiscountPercent,
            onCustomTapped: () => _openCustomDiscountDialog(context),
          ),
          const SizedBox(height: 20),
          _LogisticsSection(
            productionDaysController: _productionDays,
            deliveryAvailable: state.hasDelivery,
            onDeliveryChanged: cubit.setHasDelivery,
            deliveryPriceController: _deliveryPrice,
            assemblyAvailable: state.hasInstallation,
            onAssemblyChanged: cubit.setHasInstallation,
            warrantyController: _warrantyMonths,
            onProductionDaysChanged: cubit.setProductionDays,
            onDeliveryPriceChanged: cubit.setDeliveryPrice,
            onWarrantyChanged: cubit.setWarrantyMonths,
          ),
          const SizedBox(height: 16),
          _SkuFooter(sku: state.sku),
        ],
      ),
    );
  }
}

// =============================================================================
// App bar
// =============================================================================
class _FormAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _FormAppBar();

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
      title: const Text(
        "Mahsulot qo'shish",
        style: TextStyle(
          fontFamily: AppFonts.seller,
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
// Section title + form card
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
        style: const TextStyle(
          fontFamily: AppFonts.seller,
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
// Media section
// =============================================================================
class _MediaSection extends StatelessWidget {
  const _MediaSection({
    required this.files,
    required this.maxImages,
    required this.onAdd,
    required this.onRemove,
  });

  final List<File> files;
  final int maxImages;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final unlimited = maxImages < 0;
    final isFull = !unlimited && files.length >= maxImages;
    final caption = unlimited ? '∞' : '$maxImages';
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
                    countLabel: '${files.length}/$caption',
                    enabled: !isFull,
                    onTap: onAdd,
                  ),
                  for (var i = 0; i < files.length; i++) ...[
                    const SizedBox(width: 10),
                    _ImageThumbnail(
                      key: ValueKey('product-image-$i-${files[i].path}'),
                      file: files[i],
                      isPrimary: i == 0,
                      onRemove: () => onRemove(i),
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
    required this.countLabel,
    required this.enabled,
    required this.onTap,
  });

  final String countLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final accent = enabled ? primary : _greyMid;
    final tint = enabled
        ? primary.withValues(alpha: 0.08)
        : _fillSoft;
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
              color: tint,
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
                    "Rasm qo'shish",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: -0.1,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '($countLabel)',
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? primary.withValues(alpha: 0.8)
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
    required this.file,
    required this.isPrimary,
    required this.onRemove,
  });

  final File file;
  final bool isPrimary;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
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
              color: _fillSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: primary.withValues(alpha: 0.25),
                width: 1.2,
              ),
              image: DecorationImage(
                image: FileImage(file),
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (isPrimary)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Asosiy',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
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
// Basic info
// =============================================================================
class _BasicInfoSection extends StatelessWidget {
  const _BasicInfoSection({
    required this.nameController,
    required this.descriptionController,
    required this.categoryLabel,
    required this.onCategoryTap,
    required this.onNameChanged,
    required this.onDescriptionChanged,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final String? categoryLabel;
  final VoidCallback onCategoryTap;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onDescriptionChanged;

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
                onChanged: onNameChanged,
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
              _FormField(
                controller: descriptionController,
                label: 'Mahsulot tavsifi',
                hint: "Mahsulot haqida qisqacha ma'lumot",
                minLines: 3,
                maxLines: 6,
                onChanged: onDescriptionChanged,
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
            style: const TextStyle(
              fontFamily: AppFonts.seller,
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
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
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
                  color: disabled
                      ? _greyMid.withValues(alpha: 0.5)
                      : _greyMid,
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
// Specs
// =============================================================================
class _SpecsSection extends StatelessWidget {
  const _SpecsSection({
    required this.widthController,
    required this.heightController,
    required this.depthController,
    required this.materialController,
    required this.selectedColor,
    required this.onWidthChanged,
    required this.onHeightChanged,
    required this.onDepthChanged,
    required this.onMaterialChanged,
    required this.onColorToggle,
  });

  final TextEditingController widthController;
  final TextEditingController heightController;
  final TextEditingController depthController;
  final TextEditingController materialController;
  final String? selectedColor;
  final ValueChanged<int?> onWidthChanged;
  final ValueChanged<int?> onHeightChanged;
  final ValueChanged<int?> onDepthChanged;
  final ValueChanged<String> onMaterialChanged;
  final ValueChanged<String?> onColorToggle;

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
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                  "O'lchamlari (sm)",
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
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
                      onChanged: (v) => onWidthChanged(int.tryParse(v)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DimensionField(
                      controller: heightController,
                      label: "Bo'yi",
                      onChanged: (v) => onHeightChanged(int.tryParse(v)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DimensionField(
                      controller: depthController,
                      label: 'Chuqurligi',
                      onChanged: (v) => onDepthChanged(int.tryParse(v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _FormField(
                controller: materialController,
                label: 'Material',
                hint: "MDF, LDSP, Yog'och",
                onChanged: onMaterialChanged,
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                  'Rangi',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _grey,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kAddProductColorOptions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final c = kAddProductColorOptions[i];
                    return _ColorChip(
                      label: c.label,
                      swatch: Color(c.swatch),
                      selected: selectedColor == c.slug,
                      onTap: () => onColorToggle(c.slug),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DimensionField extends StatelessWidget {
  const _DimensionField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _outline),
    );
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      cursorColor: primary,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: AppFonts.seller,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _ink,
        letterSpacing: -0.1,
      ),
      onChanged: onChanged,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 12,
        ),
        hintText: label,
        hintStyle: const TextStyle(
          fontFamily: AppFonts.seller,
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
          borderSide: BorderSide(color: primary, width: 1.4),
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
    final primary = Theme.of(context).colorScheme.primary;
    final tint = primary.withValues(alpha: 0.08);
    return Material(
      color: selected ? tint : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? primary : _outline,
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
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? primary : _ink,
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
// Pricing
// =============================================================================
class _PricingSection extends StatelessWidget {
  const _PricingSection({
    required this.priceController,
    required this.discountPercent,
    required this.priceValue,
    required this.discountedPrice,
    required this.onPriceChanged,
    required this.onDiscountSelected,
    required this.onCustomTapped,
  });

  final TextEditingController priceController;
  final int discountPercent;
  final int priceValue;
  final int discountedPrice;
  final ValueChanged<num> onPriceChanged;
  final ValueChanged<int> onDiscountSelected;
  final VoidCallback onCustomTapped;

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
                onChanged: (v) {
                  final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                  onPriceChanged(int.tryParse(digits) ?? 0);
                },
              ),
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                  'Chegirma foizi',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
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
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? primary : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? primary : _outline,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.seller,
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
    final primary = Theme.of(context).colorScheme.primary;
    final hasPrice = priceValue > 0;
    final hasDiscount = discountPercent > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hasPrice && hasDiscount
            ? primary.withValues(alpha: 0.08)
            : _fillSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPrice && hasDiscount
              ? primary.withValues(alpha: 0.35)
              : _outline,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasDiscount ? Iconsax.discount_shape : Iconsax.tag,
            size: 18,
            color: hasPrice && hasDiscount ? primary : _greyMid,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasDiscount ? 'Chegirma bilan' : 'Chegirmasiz',
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
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
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: hasPrice && hasDiscount ? primary : _ink,
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
                color: primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '-$discountPercent%',
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
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
// Logistics
// =============================================================================
class _LogisticsSection extends StatelessWidget {
  const _LogisticsSection({
    required this.productionDaysController,
    required this.deliveryAvailable,
    required this.onDeliveryChanged,
    required this.deliveryPriceController,
    required this.assemblyAvailable,
    required this.onAssemblyChanged,
    required this.warrantyController,
    required this.onProductionDaysChanged,
    required this.onDeliveryPriceChanged,
    required this.onWarrantyChanged,
  });

  final TextEditingController productionDaysController;
  final bool deliveryAvailable;
  final ValueChanged<bool> onDeliveryChanged;
  final TextEditingController deliveryPriceController;
  final bool assemblyAvailable;
  final ValueChanged<bool> onAssemblyChanged;
  final TextEditingController warrantyController;
  final ValueChanged<String> onProductionDaysChanged;
  final ValueChanged<num> onDeliveryPriceChanged;
  final ValueChanged<int> onWarrantyChanged;

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
                onChanged: onProductionDaysChanged,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, thickness: 1, color: _divider),
              ),
              _ToggleRow(
                icon: Iconsax.truck_fast,
                title: 'Yetkazib berish mavjud',
                subtitle: 'Sotib oluvchiga yetkazib beriladi',
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
                  onChanged: (v) {
                    final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                    onDeliveryPriceChanged(int.tryParse(digits) ?? 0);
                  },
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) => onWarrantyChanged(int.tryParse(v) ?? 0),
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
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
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
          activeTrackColor: primary,
        ),
      ],
    );
  }
}

// =============================================================================
// Form field
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
    this.onChanged,
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
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
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
            style: const TextStyle(
              fontFamily: AppFonts.seller,
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
          cursorColor: primary,
          onChanged: onChanged,
          style: const TextStyle(
            fontFamily: AppFonts.seller,
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
            hintStyle: const TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _greyMid,
            ),
            suffixText: suffix,
            suffixStyle: const TextStyle(
              fontFamily: AppFonts.seller,
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
              borderSide: BorderSide(color: primary, width: 1.4),
            ),
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              helper!,
              style: const TextStyle(
                fontFamily: AppFonts.seller,
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
// SKU footer + Save bar + tariff blocked view
// =============================================================================
class _SkuFooter extends StatelessWidget {
  const _SkuFooter({required this.sku});
  final String sku;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const Icon(Iconsax.barcode, size: 14, color: _greyMid),
          const SizedBox(width: 6),
          Text(
            'SKU: $sku',
            style: const TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _greyMid,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveBottomBar extends StatelessWidget {
  const _SaveBottomBar({
    required this.enabled,
    required this.busy,
    required this.onSave,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
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
              onPressed: enabled && !busy ? onSave : null,
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: primary.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Saqlash va e'lon qilish"),
            ),
          ),
        ),
      ),
    );
  }
}

class _TariffBlockedView extends StatelessWidget {
  const _TariffBlockedView({required this.snapshot});
  final TariffSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, color: primary, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Tarif chegarasi tugadi',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            if (snapshot != null) ...[
              const SizedBox(height: 6),
              Text(
                'Mahsulotlar: ${snapshot!.activeProductsCount} / '
                '${snapshot!.plan.isUnlimited ? '∞' : snapshot!.plan.maxActiveProducts}',
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Category picker sheet
// =============================================================================
class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({
    required this.title,
    required this.items,
    required this.accent,
  });

  final String title;
  final List<CategoryModel> items;
  final Color accent;

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
              style: const TextStyle(
                fontFamily: AppFonts.seller,
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
                itemBuilder: (_, i) => _CategoryTile(
                  category: items[i],
                  accent: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.accent});

  final CategoryModel category;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(category),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(Iconsax.category, size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.name,
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
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
// Number formatting helpers
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
