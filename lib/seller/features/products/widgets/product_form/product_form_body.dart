import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import '../../../../../shared/models/category_model.dart';
import '../../bloc/add_product_cubit.dart';
import '../../controller/product_form_controllers.dart';
import 'basic_info_section.dart';
import 'category_picker_sheet.dart';
import 'dynamic_attributes_section.dart';
import 'form_kit.dart';
import 'logistics_section.dart';
import 'media_section.dart';
import 'pricing_section.dart';
import 'variant_section.dart';

/// Scrollable body of the product form — assembles every section and owns the
/// picker/sheet/dialog interactions that the sections trigger.
class ProductFormBody extends StatelessWidget {
  const ProductFormBody({
    super.key,
    required this.controllers,
    required this.picker,
    required this.state,
  });

  final ProductFormControllers controllers;
  final ImagePicker picker;
  final AddProductState state;

  @override
  Widget build(BuildContext context) {
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
          MediaSection(
            files: state.imageFiles,
            maxImages: state.maxImages,
            onAdd: () => _pickImages(context),
            onRemove: cubit.removeImageAt,
          ),
          const SizedBox(height: 20),
          BasicInfoSection(
            nameController: controllers.name,
            descriptionController: controllers.description,
            categoryLabel: cubit.findCategory(state.categoryId)?.name,
            subcategoryLabel: _subcategoryLabel(cubit, state),
            subcategoryEnabled: _subcategoryEnabled(cubit, state),
            onCategoryTap: () => _openCategorySheet(context),
            onSubcategoryTap: () => _openSubcategorySheet(context),
            onNameChanged: cubit.setName,
            onDescriptionChanged: cubit.setDescription,
          ),
          const SizedBox(height: 20),
          DynamicAttributesSection(
            state: state,
            onChanged: cubit.setAttribute,
          ),
          if (state.attributeSchema.isNotEmpty || state.categoryId != null)
            const SizedBox(height: 20),
          VariantSection(
            selectedColor: state.colorSlug,
            onColorToggle: cubit.selectColor,
          ),
          const SizedBox(height: 20),
          PricingSection(
            priceController: controllers.price,
            discountPercent: state.discountPercent,
            priceValue: state.price.toInt(),
            discountedPrice: state.effectivePrice.toInt(),
            onPriceChanged: cubit.setPrice,
            onDiscountSelected: cubit.setDiscountPercent,
            onCustomTapped: () => _openCustomDiscountDialog(context),
          ),
          const SizedBox(height: 20),
          LogisticsSection(
            productionDaysController: controllers.productionDays,
            deliveryAvailable: state.hasDelivery,
            onDeliveryChanged: cubit.setHasDelivery,
            deliveryPriceController: controllers.deliveryPrice,
            assemblyAvailable: state.hasInstallation,
            onAssemblyChanged: cubit.setHasInstallation,
            warrantyController: controllers.warrantyMonths,
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

  Future<void> _pickImages(BuildContext context) async {
    final cubit = context.read<AddProductCubit>();
    final state = cubit.state;
    if (!state.canPickMoreImages) return;

    final unlimited = state.maxImages < 0;
    final remaining =
        unlimited ? null : state.maxImages - state.imageFiles.length;
    if (!unlimited && (remaining ?? 0) <= 0) return;

    final List<XFile> picked;
    if (remaining == 1) {
      // pickMultiImage requires `limit >= 2` on Android, so fall back to the
      // single-pick API when the user has exactly one slot left.
      final single = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        imageQuality: 92,
      );
      picked = single == null ? const [] : [single];
    } else {
      picked = await picker.pickMultiImage(
        maxWidth: 2048,
        imageQuality: 92,
        limit: remaining,
      );
    }
    if (picked.isEmpty) return;
    final files = [for (final x in picked) File(x.path)];
    final added = cubit.addImages(files);

    if (!context.mounted) return;
    if (added < picked.length) {
      final cap = unlimited ? '∞' : '${state.maxImages}';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Iconsax.info_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tarifingiz bo‘yicha 1 ta mahsulotga $cap ta rasm '
                    'biriktirish mumkin. Faqat $added tasi qo‘shildi.',
                    style: const TextStyle(
                      fontFamily: AppFonts.seller,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    }
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
      builder: (_) => CategoryPickerSheet(
        title: 'Kategoriyani tanlang',
        items: categories,
        accent: primary,
      ),
    );
    if (picked != null) {
      cubit.selectCategory(picked.id);
    }
  }

  Future<void> _openSubcategorySheet(BuildContext context) async {
    final cubit = context.read<AddProductCubit>();
    final state = cubit.state;
    final category = cubit.findCategory(state.categoryId);
    if (category == null || category.subcategories.isEmpty) return;
    final primary = Theme.of(context).colorScheme.primary;

    final picked = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SubcategoryPickerSheet(
        parentName: category.name,
        subcategories: category.subcategories,
        selectedId: state.subcategoryId,
        accent: primary,
      ),
    );
    if (picked == null) return;
    if (isClearSubcategoryResult(picked)) {
      cubit.selectSubcategory(null);
    } else if (picked is SubcategoryModel) {
      cubit.selectSubcategory(picked.id);
    }
  }

  String? _subcategoryLabel(AddProductCubit cubit, AddProductState state) {
    final id = state.subcategoryId;
    if (id == null) return null;
    final category = cubit.findCategory(state.categoryId);
    if (category == null) return null;
    for (final s in category.subcategories) {
      if (s.id == id) return s.name;
    }
    return null;
  }

  bool _subcategoryEnabled(AddProductCubit cubit, AddProductState state) {
    final category = cubit.findCategory(state.categoryId);
    return category != null && category.subcategories.isNotEmpty;
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
            color: kInk,
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
            color: kInk,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: '0',
            suffixText: '%',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kOutline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kOutline),
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
                color: kGrey,
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
}

class _SkuFooter extends StatelessWidget {
  const _SkuFooter({required this.sku});

  final String sku;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const Icon(Iconsax.barcode, size: 14, color: kGreyMid),
          const SizedBox(width: 6),
          Text(
            'SKU: $sku',
            style: const TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kGreyMid,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
