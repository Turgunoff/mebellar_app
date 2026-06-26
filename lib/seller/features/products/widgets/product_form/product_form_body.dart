import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/i18n/i18n.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import '../../../../../shared/models/category_model.dart';
import '../../bloc/add_product_cubit.dart';
import '../../controller/product_form_controllers.dart';
import 'basic_info_section.dart';
import 'category_picker_sheet.dart';
import 'dynamic_attributes_section.dart';
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
            images: state.images,
            maxImages: state.maxImages,
            onAdd: () => _pickImages(context),
            onRemove: cubit.removeImageAt,
            onAiFill: () => _runAiFill(context),
            aiBusy: state.isAiBusy,
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
          DynamicAttributesSection(state: state, onChanged: cubit.setAttribute),
          if (state.attributeSchema.isNotEmpty || state.categoryId != null)
            const SizedBox(height: 20),
          VariantSection(
            selectedColors: state.colorSlugs,
            onColorToggle: cubit.toggleColor,
          ),
          const SizedBox(height: 20),
          PricingSection(
            priceController: controllers.price,
            currency: state.priceCurrency,
            usdRate: state.usdRate,
            discountPercent: state.discountPercent,
            priceValue: state.price.toInt(),
            uzsPrice: state.priceInUzs,
            discountedUzsPrice: state.discountedPriceUzs,
            onPriceChanged: cubit.setPrice,
            onCurrencyChanged: cubit.setPriceCurrency,
            onDiscountSelected: cubit.setDiscountPercent,
            onCustomTapped: () => _openCustomDiscountDialog(context),
          ),
          const SizedBox(height: 20),
          LogisticsSection(
            productionDaysController: controllers.productionDays,
            deliveryAvailable: state.hasDelivery,
            onDeliveryChanged: cubit.setHasDelivery,
            maxDeliveryFee: state.maxDeliveryFee,
            onMaxDeliveryFeeChanged: cubit.setMaxDeliveryFee,
            assemblyAvailable: state.hasInstallation,
            onAssemblyChanged: cubit.setHasInstallation,
            installationPriceController: controllers.installationPrice,
            onInstallationPriceChanged: cubit.setInstallationPrice,
            warrantyController: controllers.warrantyMonths,
            onProductionDaysChanged: cubit.setProductionDays,
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
    final remaining = unlimited ? null : state.maxImages - state.images.length;
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
                    tr(
                      'add_product.image_cap_snackbar',
                      namedArgs: {'cap': cap, 'added': added.toString()},
                    ),
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

  /// Runs the AI "fill from photos" flow, then syncs the name/description text
  /// controllers from the cubit state (the cubit owns the values, but these two
  /// fields are backed by free-standing controllers that won't auto-update).
  Future<void> _runAiFill(BuildContext context) async {
    final cubit = context.read<AddProductCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await cubit.generateFromImages();

    final state = cubit.state;
    if (state.name.isNotEmpty) controllers.name.text = state.name;
    if (state.description.isNotEmpty) {
      controllers.description.text = state.description;
    }

    if (!context.mounted) return;

    // Three outcomes: success, a "different products" warning (still filled
    // from the primary photo), and an "couldn't read" soft failure.
    final bool success = result.available && result.sameProduct;
    final Color background = success
        ? Theme.of(context).colorScheme.primary
        : AppColors.warning;
    final IconData icon = success ? Iconsax.magicpen : Iconsax.info_circle;
    final String message;
    if (success) {
      message = tr('add_product.ai_fill_success');
    } else if (result.available) {
      message = tr('add_product.ai_fill_different_products');
    } else {
      message = tr('add_product.ai_fill_failed');
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
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

  Future<void> _openCategorySheet(BuildContext context) async {
    final cubit = context.read<AddProductCubit>();
    final categories = cubit.state.context?.categories ?? const [];
    if (categories.isEmpty) return;
    final primary = Theme.of(context).colorScheme.primary;

    final picked = await showModalBottomSheet<CategoryModel>(
      context: context,
      backgroundColor: SellerColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CategoryPickerSheet(
        title: tr('add_product.field_category_placeholder'),
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
      backgroundColor: SellerColors.of(context).surface,
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
    final picked = await showDialog<int>(
      context: context,
      builder: (_) =>
          _CustomDiscountDialog(initial: cubit.state.discountPercent),
    );
    if (picked != null) {
      cubit.setDiscountPercent(picked);
    }
  }
}

/// Custom-discount entry dialog. Owns its [TextEditingController] so the
/// framework disposes it on unmount — i.e. AFTER the dialog's exit animation
/// completes. Disposing the controller synchronously after `showDialog`
/// returns (while the autofocused field is still animating out) tears the
/// element tree down mid-flight and trips the framework's
/// `'_dependents.isEmpty'` assertion.
class _CustomDiscountDialog extends StatefulWidget {
  const _CustomDiscountDialog({required this.initial});

  final int initial;

  @override
  State<_CustomDiscountDialog> createState() => _CustomDiscountDialogState();
}

class _CustomDiscountDialogState extends State<_CustomDiscountDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial == 0 ? '' : '${widget.initial}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final v = int.tryParse(_controller.text) ?? 0;
    Navigator.of(context).pop(v.clamp(0, 100));
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        tr('add_product.custom_discount_title'),
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: c.ink,
          letterSpacing: -0.2,
        ),
      ),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        autofocus: true,
        cursorColor: primary,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: c.ink,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: '0',
          suffixText: '%',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primary, width: 1.4),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            tr('add_product.cancel'),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontWeight: FontWeight.w600,
              color: c.grey,
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
          onPressed: _save,
          child: Text(
            tr('add_product.save'),
            style: const TextStyle(
              fontFamily: AppFonts.seller,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SkuFooter extends StatelessWidget {
  const _SkuFooter({required this.sku});

  final String sku;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(Iconsax.barcode, size: 14, color: c.greyMid),
          const SizedBox(width: 6),
          Text(
            tr('add_product.sku_footer', namedArgs: {'sku': sku}),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.greyMid,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
