import 'dart:io';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/category_model.dart';
import '../../../../shared/models/tariff.dart';
import '../data/add_product_repository.dart';

enum AddProductStatus {
  /// Loading the shop + plan + product count.
  loadingContext,

  /// User can interact with the form.
  ready,

  /// Plan quota reached — UI shows the upgrade prompt.
  tariffBlocked,

  /// Saving in flight (image upload + DB inserts).
  saving,

  /// Save succeeded — UI pops back.
  success,

  /// Last save attempt failed.
  failure,
}

/// Form state for the "Add Product" screen. Holds plain values — the
/// repository / Supabase row shape lives in [AddProductRepository].
class AddProductState extends Equatable {
  const AddProductState({
    this.status = AddProductStatus.loadingContext,
    this.context,
    this.sku = '',
    this.name = '',
    this.description = '',
    this.categoryId,
    this.widthCm,
    this.heightCm,
    this.depthCm,
    this.material = '',
    this.colorSlug,
    this.price = 0,
    this.discountPercent = 0,
    this.productionTimeDays = '3-5',
    this.hasDelivery = false,
    this.deliveryPrice = 0,
    this.hasInstallation = false,
    this.warrantyMonths = 12,
    this.imageFiles = const [],
    this.error,
  });

  final AddProductStatus status;
  final AddProductShopContext? context;
  final String sku;
  final String name;
  final String description;
  final String? categoryId;
  final int? widthCm;
  final int? heightCm;
  final int? depthCm;
  final String material;
  final String? colorSlug;
  final num price;
  final int discountPercent;
  final String productionTimeDays;
  final bool hasDelivery;
  final num deliveryPrice;
  final bool hasInstallation;
  final int warrantyMonths;
  final List<File> imageFiles;
  final String? error;

  /// `-1` means unlimited.
  int get maxImages => context?.maxImages ?? 0;

  bool get canPickMoreImages {
    if (status != AddProductStatus.ready && status != AddProductStatus.failure) {
      return false;
    }
    if (maxImages < 0) return true;
    return imageFiles.length < maxImages;
  }

  /// Form-level validity. Driven by the same rules that gate the bottom CTA.
  bool get canSubmit {
    if (context == null) return false;
    if (status != AddProductStatus.ready && status != AddProductStatus.failure) {
      return false;
    }
    if (imageFiles.isEmpty) return false;
    if (name.trim().isEmpty) return false;
    if (categoryId == null) return false;
    if (price <= 0) return false;
    if (hasDelivery && deliveryPrice < 0) return false;
    return true;
  }

  num get effectivePrice =>
      discountPercent > 0 ? price * (100 - discountPercent) / 100 : price;

  AddProductState copyWith({
    AddProductStatus? status,
    AddProductShopContext? context,
    String? sku,
    String? name,
    String? description,
    String? categoryId,
    bool clearCategory = false,
    int? widthCm,
    int? heightCm,
    int? depthCm,
    String? material,
    String? colorSlug,
    bool clearColor = false,
    num? price,
    int? discountPercent,
    String? productionTimeDays,
    bool? hasDelivery,
    num? deliveryPrice,
    bool? hasInstallation,
    int? warrantyMonths,
    List<File>? imageFiles,
    String? error,
    bool clearError = false,
  }) {
    return AddProductState(
      status: status ?? this.status,
      context: context ?? this.context,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      widthCm: widthCm ?? this.widthCm,
      heightCm: heightCm ?? this.heightCm,
      depthCm: depthCm ?? this.depthCm,
      material: material ?? this.material,
      colorSlug: clearColor ? null : (colorSlug ?? this.colorSlug),
      price: price ?? this.price,
      discountPercent: discountPercent ?? this.discountPercent,
      productionTimeDays: productionTimeDays ?? this.productionTimeDays,
      hasDelivery: hasDelivery ?? this.hasDelivery,
      deliveryPrice: deliveryPrice ?? this.deliveryPrice,
      hasInstallation: hasInstallation ?? this.hasInstallation,
      warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      imageFiles: imageFiles ?? this.imageFiles,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        status,
        context?.shopId,
        context?.activeProductsCount,
        sku,
        name,
        description,
        categoryId,
        widthCm,
        heightCm,
        depthCm,
        material,
        colorSlug,
        price,
        discountPercent,
        productionTimeDays,
        hasDelivery,
        deliveryPrice,
        hasInstallation,
        warrantyMonths,
        imageFiles.length,
        error,
      ];
}

class AddProductCubit extends Cubit<AddProductState> {
  AddProductCubit({required AddProductRepository repository})
      : _repository = repository,
        super(AddProductState(sku: _generateSku()));

  final AddProductRepository _repository;

  /// MH-{YYYY}-{4 digits}. Generated up-front so the user never has to type
  /// it; the variant row carries it through to the warehouse export.
  static String _generateSku() {
    final year = DateTime.now().year;
    final rand = math.Random().nextInt(10000).toString().padLeft(4, '0');
    return 'MH-$year-$rand';
  }

  Future<void> loadContext() async {
    emit(state.copyWith(
      status: AddProductStatus.loadingContext,
      clearError: true,
    ));
    try {
      final ctx = await _repository.loadShopContext();
      if (!ctx.canAddMoreProducts) {
        emit(state.copyWith(
          status: AddProductStatus.tariffBlocked,
          context: ctx,
        ));
        return;
      }
      emit(state.copyWith(status: AddProductStatus.ready, context: ctx));
    } catch (e) {
      emit(state.copyWith(
        status: AddProductStatus.failure,
        error: e.toString(),
      ));
    }
  }

  void setName(String value) => emit(state.copyWith(name: value));
  void setDescription(String value) =>
      emit(state.copyWith(description: value));
  void setMaterial(String value) => emit(state.copyWith(material: value));
  void setProductionDays(String value) =>
      emit(state.copyWith(productionTimeDays: value));

  void selectCategory(String? id) {
    if (id == null) {
      emit(state.copyWith(clearCategory: true));
    } else {
      emit(state.copyWith(categoryId: id));
    }
  }

  void setDimensions({int? width, int? height, int? depth}) {
    emit(state.copyWith(
      widthCm: width ?? state.widthCm,
      heightCm: height ?? state.heightCm,
      depthCm: depth ?? state.depthCm,
    ));
  }

  void selectColor(String? slug) {
    if (slug == null || state.colorSlug == slug) {
      emit(state.copyWith(clearColor: true));
    } else {
      emit(state.copyWith(colorSlug: slug));
    }
  }

  void setPrice(num value) => emit(state.copyWith(price: value));
  void setDiscountPercent(int value) =>
      emit(state.copyWith(discountPercent: value.clamp(0, 100)));

  void setHasDelivery(bool value) {
    emit(state.copyWith(
      hasDelivery: value,
      // Reset price when delivery is turned off so we never persist a stale
      // non-zero value behind the disabled toggle.
      deliveryPrice: value ? state.deliveryPrice : 0,
    ));
  }

  void setDeliveryPrice(num value) =>
      emit(state.copyWith(deliveryPrice: value));

  void setHasInstallation(bool value) =>
      emit(state.copyWith(hasInstallation: value));

  void setWarrantyMonths(int value) =>
      emit(state.copyWith(warrantyMonths: value.clamp(0, 120)));

  void addImage(File file) {
    if (!state.canPickMoreImages) return;
    emit(state.copyWith(imageFiles: [...state.imageFiles, file]));
  }

  void removeImageAt(int index) {
    if (index < 0 || index >= state.imageFiles.length) return;
    final next = [...state.imageFiles]..removeAt(index);
    emit(state.copyWith(imageFiles: next));
  }

  void regenerateSku() => emit(state.copyWith(sku: _generateSku()));

  /// Triggers the upload + 3-row insert. Returns `true` on success so the
  /// screen can pop after the snackbar.
  Future<bool> submit() async {
    final ctx = state.context;
    if (ctx == null) return false;
    if (!ctx.canAddMoreProducts) {
      emit(state.copyWith(status: AddProductStatus.tariffBlocked));
      return false;
    }
    if (!state.canSubmit) return false;

    emit(state.copyWith(status: AddProductStatus.saving, clearError: true));
    try {
      await _repository.createProduct(
        AddProductInput(
          sellerId: ctx.sellerId,
          shopId: ctx.shopId,
          name: state.name.trim(),
          description: state.description.trim(),
          categoryId: state.categoryId!,
          price: state.price,
          discountPercent: state.discountPercent,
          sku: state.sku,
          colorName: _colorNameFor(state.colorSlug),
          widthCm: state.widthCm,
          heightCm: state.heightCm,
          depthCm: state.depthCm,
          material: state.material.trim().isEmpty ? null : state.material.trim(),
          productionTimeDays: state.productionTimeDays.trim().isEmpty
              ? null
              : state.productionTimeDays.trim(),
          hasDelivery: state.hasDelivery,
          deliveryPrice: state.deliveryPrice,
          hasInstallation: state.hasInstallation,
          warrantyMonths: state.warrantyMonths,
          imageFiles: state.imageFiles,
        ),
      );
      emit(state.copyWith(status: AddProductStatus.success));
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: AddProductStatus.failure,
        error: e.toString(),
      ));
      return false;
    }
  }

  /// Human-readable color name persisted on the variant row. We keep the slug
  /// in the form state for cheap equality checks, then map it to the
  /// localised display name at save time.
  String? _colorNameFor(String? slug) {
    if (slug == null) return null;
    return kAddProductColorOptions
        .firstWhere(
          (c) => c.slug == slug,
          orElse: () => const AddProductColorOption(
            slug: '',
            label: '',
            swatch: 0xFF000000,
          ),
        )
        .label;
  }

  CategoryModel? findCategory(String? id) {
    if (id == null) return null;
    final ctx = state.context;
    if (ctx == null) return null;
    for (final c in ctx.categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  TariffSnapshot? get tariffSnapshot => state.context?.tariffSnapshot;
}

/// Compact value the UI iterates over to render the horizontal color row.
/// Slugs survive locale changes; the human label is persisted to the
/// variant row when the user saves.
class AddProductColorOption {
  const AddProductColorOption({
    required this.slug,
    required this.label,
    required this.swatch,
  });

  final String slug;
  final String label;
  final int swatch;
}

const kAddProductColorOptions = <AddProductColorOption>[
  AddProductColorOption(slug: 'white', label: 'Oq', swatch: 0xFFFFFFFF),
  AddProductColorOption(slug: 'black', label: 'Qora', swatch: 0xFF1D1D1D),
  AddProductColorOption(slug: 'grey', label: 'Kulrang', swatch: 0xFF9CA3AF),
  AddProductColorOption(slug: 'brown', label: 'Jigarrang', swatch: 0xFF8B5E3C),
  AddProductColorOption(slug: 'beige', label: 'Bej', swatch: 0xFFE9DCC4),
  AddProductColorOption(slug: 'green', label: 'Yashil', swatch: 0xFF4F7A52),
  AddProductColorOption(slug: 'blue', label: "Ko'k", swatch: 0xFF3B6CB5),
  AddProductColorOption(slug: 'yellow', label: 'Sariq', swatch: 0xFFE6C25C),
];
