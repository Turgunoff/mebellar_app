import 'dart:io';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/logging/talker.dart';
import '../../../../shared/models/attribute_definition.dart';
import '../../../../shared/models/category_model.dart';
import '../../../../shared/models/tariff.dart';
import '../data/add_product_repository.dart';
import '../data/attributes_repository.dart';

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
    this.subcategoryId,
    this.attributeSchema = const [],
    this.attributes = const {},
    this.isLoadingSchema = false,
    this.colorSlugs = const <String>{},
    this.price = 0,
    this.discountPercent = 0,
    this.productionTimeDays = '3-5',
    this.hasDelivery = false,
    this.deliveryPrice = 0,
    this.hasInstallation = false,
    this.installationPrice = 0,
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
  final String? subcategoryId;
  final List<AttributeDefinition> attributeSchema;
  final Map<String, dynamic> attributes;
  final bool isLoadingSchema;
  final Set<String> colorSlugs;
  final num price;
  final int discountPercent;
  final String productionTimeDays;
  final bool hasDelivery;
  final num deliveryPrice;
  final bool hasInstallation;
  final num installationPrice;
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

  /// True when every `is_required` definition in [attributeSchema] has a
  /// non-empty value in [attributes]. An empty schema (no category-specific
  /// attrs) is treated as valid.
  bool get hasAllRequiredAttributes {
    for (final def in attributeSchema) {
      if (!def.isRequired) continue;
      final value = attributes[def.key];
      if (value == null) return false;
      if (value is String && value.trim().isEmpty) return false;
      if (value is List && value.isEmpty) return false;
    }
    return true;
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
    if (!hasAllRequiredAttributes) return false;
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
    String? subcategoryId,
    bool clearSubcategory = false,
    List<AttributeDefinition>? attributeSchema,
    Map<String, dynamic>? attributes,
    bool? isLoadingSchema,
    Set<String>? colorSlugs,
    num? price,
    int? discountPercent,
    String? productionTimeDays,
    bool? hasDelivery,
    num? deliveryPrice,
    bool? hasInstallation,
    num? installationPrice,
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
      subcategoryId:
          clearSubcategory ? null : (subcategoryId ?? this.subcategoryId),
      attributeSchema: attributeSchema ?? this.attributeSchema,
      attributes: attributes ?? this.attributes,
      isLoadingSchema: isLoadingSchema ?? this.isLoadingSchema,
      colorSlugs: colorSlugs ?? this.colorSlugs,
      price: price ?? this.price,
      discountPercent: discountPercent ?? this.discountPercent,
      productionTimeDays: productionTimeDays ?? this.productionTimeDays,
      hasDelivery: hasDelivery ?? this.hasDelivery,
      deliveryPrice: deliveryPrice ?? this.deliveryPrice,
      hasInstallation: hasInstallation ?? this.hasInstallation,
      installationPrice: installationPrice ?? this.installationPrice,
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
        subcategoryId,
        attributeSchema,
        attributes,
        isLoadingSchema,
        colorSlugs,
        price,
        discountPercent,
        productionTimeDays,
        hasDelivery,
        deliveryPrice,
        hasInstallation,
        installationPrice,
        warrantyMonths,
        imageFiles.length,
        error,
      ];
}

class AddProductCubit extends Cubit<AddProductState> {
  AddProductCubit({
    required AddProductRepository repository,
    required AttributesRepository attributesRepository,
  })  : _repository = repository,
        _attributesRepository = attributesRepository,
        super(AddProductState(sku: _generateSku()));

  final AddProductRepository _repository;
  final AttributesRepository _attributesRepository;

  /// Increments on every category/subcategory change. Stale responses from
  /// the attributes repository are discarded by comparing against the
  /// in-flight token so rapid taps don't paint the wrong schema.
  int _schemaRequestId = 0;

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
  void setProductionDays(String value) =>
      emit(state.copyWith(productionTimeDays: value));

  /// Selecting a (new) category wipes the entire [attributes] map and triggers
  /// a fresh schema load. Subcategory is also cleared because it's scoped
  /// inside the previous category.
  void selectCategory(String? id) {
    if (id == null) {
      talker.info('[add-product-cubit] selectCategory cleared');
      emit(state.copyWith(
        clearCategory: true,
        clearSubcategory: true,
        attributeSchema: const [],
        attributes: const {},
      ));
      return;
    }
    if (state.categoryId == id) return;
    talker.info(
      '[add-product-cubit] selectCategory id=$id (was ${state.categoryId})',
    );
    emit(state.copyWith(
      categoryId: id,
      clearSubcategory: true,
      attributeSchema: const [],
      attributes: const {},
    ));
    _reloadSchema();
  }

  /// Selecting (or clearing) the subcategory keeps the category-scoped values
  /// intact but drops anything that was tied to the previously-selected
  /// subcategory so we don't ship orphan keys into JSONB.
  void selectSubcategory(String? id) {
    if (id == state.subcategoryId) return;
    talker.info(
      '[add-product-cubit] selectSubcategory id=$id (was ${state.subcategoryId})',
    );
    final pruned = _pruneSubcategoryAttributes(state.attributes, state.attributeSchema);
    emit(state.copyWith(
      subcategoryId: id,
      clearSubcategory: id == null,
      attributes: pruned,
    ));
    _reloadSchema();
  }

  Map<String, dynamic> _pruneSubcategoryAttributes(
    Map<String, dynamic> values,
    List<AttributeDefinition> schema,
  ) {
    final subKeys = {
      for (final def in schema)
        if (def.isSubcategoryScoped) def.key,
    };
    if (subKeys.isEmpty) return values;
    return {
      for (final entry in values.entries)
        if (!subKeys.contains(entry.key)) entry.key: entry.value,
    };
  }

  Future<void> _reloadSchema() async {
    final categoryId = state.categoryId;
    if (categoryId == null) return;
    final token = ++_schemaRequestId;
    emit(state.copyWith(isLoadingSchema: true));
    try {
      final schema = await _attributesRepository.loadForCategory(
        categoryId: categoryId,
        subcategoryId: state.subcategoryId,
      );
      if (token != _schemaRequestId) return; // stale response
      emit(state.copyWith(
        attributeSchema: schema,
        isLoadingSchema: false,
      ));
    } catch (e) {
      if (token != _schemaRequestId) return;
      emit(state.copyWith(
        isLoadingSchema: false,
        error: e.toString(),
      ));
    }
  }

  /// Writes a single attribute value. Passing `null` removes the key — the
  /// form binds optional-clear chips this way.
  void setAttribute(String key, dynamic value) {
    final next = Map<String, dynamic>.from(state.attributes);
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    emit(state.copyWith(attributes: next));
  }

  /// Adds or removes [slug] from the current selection. The form supports
  /// multi-colour — one product can ship in several colours — so this is a
  /// toggle, not a single-select replacement.
  void toggleColor(String slug) {
    final next = {...state.colorSlugs};
    if (!next.remove(slug)) next.add(slug);
    emit(state.copyWith(colorSlugs: next));
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

  void setHasInstallation(bool value) {
    emit(state.copyWith(
      hasInstallation: value,
      // Same defensive reset as delivery — toggle off, price goes to zero so
      // the disabled state never carries a stale value.
      installationPrice: value ? state.installationPrice : 0,
    ));
  }

  void setInstallationPrice(num value) =>
      emit(state.copyWith(installationPrice: value));

  void setWarrantyMonths(int value) =>
      emit(state.copyWith(warrantyMonths: value.clamp(0, 120)));

  void addImage(File file) {
    if (!state.canPickMoreImages) return;
    emit(state.copyWith(imageFiles: [...state.imageFiles, file]));
  }

  /// Append multiple images, trimming the input to whatever quota remains.
  /// Returns the number actually added so the UI can warn when the picker
  /// returned more than the tariff allows.
  int addImages(List<File> files) {
    if (files.isEmpty || !state.canPickMoreImages) return 0;
    final List<File> accepted;
    if (state.maxImages < 0) {
      accepted = files;
    } else {
      final remaining = state.maxImages - state.imageFiles.length;
      if (remaining <= 0) return 0;
      accepted = files.length <= remaining ? files : files.sublist(0, remaining);
    }
    emit(state.copyWith(imageFiles: [...state.imageFiles, ...accepted]));
    return accepted.length;
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
    if (ctx == null) {
      talker.warning('[add-product-cubit] submit aborted — no shop context');
      return false;
    }
    if (!ctx.canAddMoreProducts) {
      talker.warning(
        '[add-product-cubit] submit blocked by tariff '
        'plan=${ctx.plan.code} active=${ctx.activeProductsCount}',
      );
      emit(state.copyWith(status: AddProductStatus.tariffBlocked));
      return false;
    }
    if (!state.canSubmit) {
      talker.warning(
        '[add-product-cubit] submit blocked by validation '
        'name=${state.name.isNotEmpty} category=${state.categoryId != null} '
        'price=${state.price} images=${state.imageFiles.length} '
        'requiredAttrsOk=${state.hasAllRequiredAttributes}',
      );
      return false;
    }

    talker.info(
      '[add-product-cubit] submit start sku=${state.sku} '
      'category=${state.categoryId} sub=${state.subcategoryId} '
      'images=${state.imageFiles.length} attributes=${state.attributes.length}',
    );
    emit(state.copyWith(status: AddProductStatus.saving, clearError: true));
    try {
      await _repository.createProduct(
        AddProductInput(
          sellerId: ctx.sellerId,
          shopId: ctx.shopId,
          name: state.name.trim(),
          description: state.description.trim(),
          categoryId: state.categoryId!,
          subcategoryId: state.subcategoryId,
          price: state.price,
          discountPercent: state.discountPercent,
          sku: state.sku,
          colorSlugs: state.colorSlugs.toList(),
          colorNames: [
            for (final slug in state.colorSlugs)
              _colorNameFor(slug) ?? slug,
          ],
          attributes: Map<String, dynamic>.from(state.attributes),
          productionTimeDays: state.productionTimeDays.trim().isEmpty
              ? null
              : state.productionTimeDays.trim(),
          hasDelivery: state.hasDelivery,
          deliveryPrice: state.deliveryPrice,
          hasInstallation: state.hasInstallation,
          installationPrice: state.installationPrice,
          warrantyMonths: state.warrantyMonths,
          imageFiles: state.imageFiles,
        ),
      );
      emit(state.copyWith(status: AddProductStatus.success));
      talker.info('[add-product-cubit] submit ok sku=${state.sku}');
      return true;
    } catch (e, st) {
      talker.handle(e, st,
          '[add-product-cubit] submit failed sku=${state.sku}');
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
