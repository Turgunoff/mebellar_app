import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/theme/app_fonts.dart';
import '../../../../../shared/models/category_model.dart';
import '../../bloc/add_product_cubit.dart';
import '../../controller/product_form_controllers.dart';
import 'basic_info_section.dart';
import 'category_picker_sheet.dart';
import 'form_kit.dart';
import 'logistics_section.dart';
import 'media_section.dart';
import 'pricing_section.dart';
import 'specs_section.dart';

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
            onAdd: () => _pickImage(context),
            onRemove: cubit.removeImageAt,
          ),
          const SizedBox(height: 20),
          BasicInfoSection(
            nameController: controllers.name,
            descriptionController: controllers.description,
            categoryLabel: cubit.findCategory(state.categoryId)?.name,
            onCategoryTap: () => _openCategorySheet(context),
            onNameChanged: cubit.setName,
            onDescriptionChanged: cubit.setDescription,
          ),
          const SizedBox(height: 20),
          SpecsSection(
            widthController: controllers.width,
            heightController: controllers.height,
            depthController: controllers.depth,
            materialController: controllers.material,
            selectedColor: state.colorSlug,
            onWidthChanged: (v) => cubit.setDimensions(width: v),
            onHeightChanged: (v) => cubit.setDimensions(height: v),
            onDepthChanged: (v) => cubit.setDimensions(depth: v),
            onMaterialChanged: cubit.setMaterial,
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

  Future<void> _pickImage(BuildContext context) async {
    final cubit = context.read<AddProductCubit>();
    if (!cubit.state.canPickMoreImages) return;

    final picked = await picker.pickImage(
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
