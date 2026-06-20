import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/logging/talker.dart';
import '../../../../core/network/api_error.dart';
import '../../../../shared/constants/product_colors.dart';
import '../../../../shared/models/attribute_definition.dart';
import '../../../../shared/models/category_model.dart';
import '../../../../shared/models/seller_product.dart';
import '../../../../shared/models/tariff.dart';
import '../data/add_product_repository.dart';
import '../data/attributes_repository.dart';
import '../data/exchange_rate_service.dart';

/// Currency the seller types the base price in. Input convenience only —
/// the backend speaks UZS exclusively, so USD is converted with the cached
/// CBU rate before `submit` builds the request.
enum PriceCurrency { uzs, usd }

enum AddProductStatus {
  /// Loading the shop + plan + product count.
  loadingContext,

  /// User can interact with the form.
  ready,

  /// Plan quota reached — UI shows the upgrade prompt.
  tariffBlocked,

  /// Shop frozen for unpaid debt — adding products is disabled until the
  /// seller clears the balance (the backend 403s the create anyway).
  walletSuspended,

  /// Saving in flight (image upload + DB inserts).
  saving,

  /// Save succeeded — UI pops back.
  success,

  /// Last save attempt failed.
  failure,
}

/// Form state for the "Add Product" screen (also reused in edit mode — see
/// [AddProductState.editingProductId]). Holds plain values — the repository /
/// backend row shape lives in [AddProductRepository].
class AddProductState extends Equatable {
  const AddProductState({
    this.status = AddProductStatus.loadingContext,
    this.context,
    this.editingProductId,
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
    this.priceCurrency = PriceCurrency.uzs,
    this.usdRate,
    this.discountPercent = 0,
    this.productionTimeDays = '3-5',
    this.hasDelivery = false,
    this.deliveryPrice = 0,
    this.hasInstallation = false,
    this.installationPrice = 0,
    this.warrantyMonths = 12,
    this.images = const [],
    this.isAiBusy = false,
    this.error,
    this.duplicateMatch,
  });

  final AddProductStatus status;
  final AddProductShopContext? context;

  /// Non-null when the form edits an existing product instead of creating a
  /// new one. Editing PATCHes the row (no new tariff slot is consumed), so
  /// the quota gate is skipped in this mode.
  final String? editingProductId;

  final String sku;
  final String name;
  final String description;
  final String? categoryId;
  final String? subcategoryId;
  final List<AttributeDefinition> attributeSchema;
  final Map<String, dynamic> attributes;
  final bool isLoadingSchema;
  final Set<String> colorSlugs;

  /// Raw value as typed, in [priceCurrency]. Switching currency keeps the
  /// number and reinterprets it — the UZS view of it is [priceInUzs].
  final num price;
  final PriceCurrency priceCurrency;

  /// Cached CBU USD→UZS rate; null until the background fetch lands (or if
  /// it failed). The USD toggle stays disabled while null.
  final double? usdRate;
  final int discountPercent;
  final String productionTimeDays;
  final bool hasDelivery;
  final num deliveryPrice;
  final bool hasInstallation;
  final num installationPrice;
  final int warrantyMonths;

  /// Gallery strip in display order — local picks and (in edit mode) the
  /// product's existing remote images, mixed.
  final List<FormImage> images;

  /// True while an AI "fill from photos" request is in flight. Drives the
  /// button spinner + disables the form so applied fields don't fight a tap.
  final bool isAiBusy;
  final String? error;

  /// Set after a save was rejected with 409 DUPLICATE_DETECTED — the seller's
  /// existing product the new one resembles. The form shows a soft warning
  /// sheet; a "save anyway" re-submits with force_create. Cleared on the next
  /// submit. Non-null only transiently alongside [AddProductStatus.failure].
  final DuplicateProductMatch? duplicateMatch;

  bool get isEditing => editingProductId != null;

  /// `-1` means unlimited.
  int get maxImages => context?.maxImages ?? 0;

  bool get canPickMoreImages {
    if (status != AddProductStatus.ready &&
        status != AddProductStatus.failure) {
      return false;
    }
    if (maxImages < 0) return true;
    return images.length < maxImages;
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
    if (status != AddProductStatus.ready &&
        status != AddProductStatus.failure) {
      return false;
    }
    if (images.isEmpty) return false;
    if (name.trim().isEmpty) return false;
    if (categoryId == null) return false;
    if (price <= 0) return false;
    // USD input is only submittable once a rate exists to convert it with —
    // the toggle is gated on the rate, but a fetch failure after a switch
    // must not let a zero-UZS price through.
    if (isUsdInput && priceInUzs <= 0) return false;
    if (hasDelivery && deliveryPrice < 0) return false;
    if (!hasAllRequiredAttributes) return false;
    return true;
  }

  bool get isUsdInput => priceCurrency == PriceCurrency.usd;

  /// Base price in UZS — the only currency the backend ever receives. USD
  /// input is converted with the CBU rate and rounded to a whole som.
  int get priceInUzs {
    if (!isUsdInput) return price.round();
    final rate = usdRate;
    if (rate == null) return 0;
    return (price * rate).round();
  }

  /// Discounted price in UZS — what the buyer pays and what the summary box
  /// shows. The discount applies to the converted [priceInUzs], so UZS and
  /// USD input go through the exact same discount math.
  int get discountedPriceUzs => discountPercent > 0
      ? (priceInUzs * (100 - discountPercent) / 100).round()
      : priceInUzs;

  AddProductState copyWith({
    AddProductStatus? status,
    AddProductShopContext? context,
    String? editingProductId,
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
    PriceCurrency? priceCurrency,
    double? usdRate,
    int? discountPercent,
    String? productionTimeDays,
    bool? hasDelivery,
    num? deliveryPrice,
    bool? hasInstallation,
    num? installationPrice,
    int? warrantyMonths,
    List<FormImage>? images,
    bool? isAiBusy,
    String? error,
    bool clearError = false,
    DuplicateProductMatch? duplicateMatch,
    bool clearDuplicate = false,
  }) {
    return AddProductState(
      status: status ?? this.status,
      context: context ?? this.context,
      editingProductId: editingProductId ?? this.editingProductId,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      subcategoryId: clearSubcategory
          ? null
          : (subcategoryId ?? this.subcategoryId),
      attributeSchema: attributeSchema ?? this.attributeSchema,
      attributes: attributes ?? this.attributes,
      isLoadingSchema: isLoadingSchema ?? this.isLoadingSchema,
      colorSlugs: colorSlugs ?? this.colorSlugs,
      price: price ?? this.price,
      priceCurrency: priceCurrency ?? this.priceCurrency,
      usdRate: usdRate ?? this.usdRate,
      discountPercent: discountPercent ?? this.discountPercent,
      productionTimeDays: productionTimeDays ?? this.productionTimeDays,
      hasDelivery: hasDelivery ?? this.hasDelivery,
      deliveryPrice: deliveryPrice ?? this.deliveryPrice,
      hasInstallation: hasInstallation ?? this.hasInstallation,
      installationPrice: installationPrice ?? this.installationPrice,
      warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      images: images ?? this.images,
      isAiBusy: isAiBusy ?? this.isAiBusy,
      error: clearError ? null : (error ?? this.error),
      duplicateMatch: clearDuplicate
          ? null
          : (duplicateMatch ?? this.duplicateMatch),
    );
  }

  @override
  List<Object?> get props => [
    status,
    context?.shopId,
    context?.activeProductsCount,
    editingProductId,
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
    priceCurrency,
    usdRate,
    discountPercent,
    productionTimeDays,
    hasDelivery,
    deliveryPrice,
    hasInstallation,
    installationPrice,
    warrantyMonths,
    // FormImage has no value equality; identity of the rebuilt list plus its
    // length is enough for the form to repaint on add/remove.
    images.length,
    isAiBusy,
    error,
    duplicateMatch,
  ];
}

class AddProductCubit extends Cubit<AddProductState> {
  AddProductCubit({
    required AddProductRepository repository,
    required AttributesRepository attributesRepository,
    ExchangeRateService? exchangeRates,
    AnalyticsService? analytics,
  }) : _repository = repository,
       _attributesRepository = attributesRepository,
       _exchangeRates = exchangeRates,
       _analytics = analytics,
       super(AddProductState(sku: _generateSku()));

  final AddProductRepository _repository;
  final AttributesRepository _attributesRepository;
  final ExchangeRateService? _exchangeRates;
  final AnalyticsService? _analytics;

  /// Max photos sent to the AI endpoint. The backend caps `image_urls` at 4
  /// (more rarely improves recognition and each one costs vision tokens), so
  /// we trim here to avoid a 422 when the seller's tariff allows more images.
  static const int _maxAiImages = 4;

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
    emit(
      state.copyWith(status: AddProductStatus.loadingContext, clearError: true),
    );
    unawaited(_loadUsdRate());
    try {
      final ctx = await _repository.loadShopContext();
      if (isClosed) return;
      // Debt freeze outranks the quota gate — upgrading the plan wouldn't
      // help a frozen shop, so don't show the upgrade prompt.
      if (ctx.isSuspendedDueToDebt) {
        emit(
          state.copyWith(
            status: AddProductStatus.walletSuspended,
            context: ctx,
          ),
        );
        return;
      }
      if (!ctx.canAddMoreProducts) {
        emit(
          state.copyWith(status: AddProductStatus.tariffBlocked, context: ctx),
        );
        return;
      }
      emit(state.copyWith(status: AddProductStatus.ready, context: ctx));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(status: AddProductStatus.failure, error: e.toString()),
      );
    }
  }

  /// Edit-mode boot: loads the shop context, then prefils every form field
  /// from [product] — existing photos become remote image refs (no
  /// re-upload), the category is selected first and its attribute schema
  /// awaited so only schema-valid attribute keys survive (the same contract
  /// the AI fill enforces). Emits `ready` exactly once, with the form fully
  /// populated, so the screen can sync its text controllers on that
  /// transition. The tariff quota gate is skipped — editing doesn't consume
  /// a slot.
  Future<void> loadForEdit(SellerProduct product) async {
    emit(
      state.copyWith(
        status: AddProductStatus.loadingContext,
        editingProductId: product.id,
        clearError: true,
      ),
    );
    unawaited(_loadUsdRate());
    try {
      final ctx = await _repository.loadShopContext();
      if (isClosed) return;
      final hasDiscount =
          product.discountPrice != null &&
          product.discountPrice! > 0 &&
          product.discountPrice! < product.price;
      final discountPercent = hasDiscount
          ? (((product.price - product.discountPrice!) / product.price) * 100)
                .round()
          : 0;
      emit(
        state.copyWith(
          context: ctx,
          sku: product.sku.isNotEmpty ? product.sku : state.sku,
          name: product.name.uz ?? '',
          description: product.description.uz ?? '',
          price: product.price,
          discountPercent: discountPercent,
          productionTimeDays: product.productionTimeDays ?? '',
          hasDelivery: product.hasDelivery,
          deliveryPrice: product.deliveryPrice,
          hasInstallation: product.hasInstallation,
          installationPrice: product.installationPrice,
          warrantyMonths: product.warrantyMonths,
          colorSlugs: {
            for (final slug in product.colors)
              if (productColorBySlug(slug) != null) slug,
          },
          images: [
            for (final img in product.images)
              if (img.remoteUrl != null && img.remoteUrl!.isNotEmpty)
                FormImage.remote(img.remoteUrl!),
          ],
        ),
      );

      final categoryId = product.categorySlug;
      if (categoryId.isNotEmpty && findCategory(categoryId) != null) {
        selectCategory(categoryId);
        final sub = product.subcategoryId;
        if (sub != null && _subcategoryExists(categoryId, sub)) {
          selectSubcategory(sub);
        }
        await _awaitSchema();
        if (isClosed) return;
        final validKeys = {for (final d in state.attributeSchema) d.key};
        for (final entry in product.attributes.entries) {
          if (validKeys.contains(entry.key) && entry.value != null) {
            setAttribute(entry.key, entry.value);
          }
        }
      }

      emit(state.copyWith(status: AddProductStatus.ready));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(status: AddProductStatus.failure, error: e.toString()),
      );
    }
  }

  void setName(String value) => emit(state.copyWith(name: value));
  void setDescription(String value) => emit(state.copyWith(description: value));
  void setProductionDays(String value) =>
      emit(state.copyWith(productionTimeDays: value));

  /// Selecting a (new) category wipes the entire [attributes] map and triggers
  /// a fresh schema load. Subcategory is also cleared because it's scoped
  /// inside the previous category.
  void selectCategory(String? id) {
    if (id == null) {
      talker.info('[add-product-cubit] selectCategory cleared');
      emit(
        state.copyWith(
          clearCategory: true,
          clearSubcategory: true,
          attributeSchema: const [],
          attributes: const {},
        ),
      );
      return;
    }
    if (state.categoryId == id) return;
    talker.info(
      '[add-product-cubit] selectCategory id=$id (was ${state.categoryId})',
    );
    emit(
      state.copyWith(
        categoryId: id,
        clearSubcategory: true,
        attributeSchema: const [],
        attributes: const {},
      ),
    );
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
    final pruned = _pruneSubcategoryAttributes(
      state.attributes,
      state.attributeSchema,
    );
    emit(
      state.copyWith(
        subcategoryId: id,
        clearSubcategory: id == null,
        attributes: pruned,
      ),
    );
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
      if (isClosed || token != _schemaRequestId) return; // stale response
      emit(state.copyWith(attributeSchema: schema, isLoadingSchema: false));
    } catch (e) {
      if (isClosed || token != _schemaRequestId) return;
      emit(state.copyWith(isLoadingSchema: false, error: e.toString()));
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

  /// Switches the currency the price field is interpreted in. The typed
  /// number is kept as-is ("500" stays "500", now meaning the other
  /// currency) — the helper line under the field shows the live UZS
  /// equivalent, so the seller sees the effect immediately. Switching to USD
  /// requires a loaded rate; the UI disables the USD segment until then, and
  /// this guard is the cubit-side belt to that suspender.
  void setPriceCurrency(PriceCurrency currency) {
    if (currency == state.priceCurrency) return;
    if (currency == PriceCurrency.usd && state.usdRate == null) {
      // Retry — e.g. the boot fetch raced a dead network and the seller taps
      // the segment once connectivity is back.
      unawaited(_loadUsdRate());
      return;
    }
    emit(state.copyWith(priceCurrency: currency));
  }

  /// Background CBU rate fetch. Failure simply leaves [AddProductState.usdRate]
  /// null — the USD toggle stays disabled and the form remains fully usable
  /// in UZS. Never throws.
  Future<void> _loadUsdRate() async {
    final service = _exchangeRates;
    if (service == null || state.usdRate != null) return;
    final rate = await service.getUsdRate();
    if (isClosed || rate == null || rate <= 0) return;
    emit(state.copyWith(usdRate: rate));
  }

  void setDiscountPercent(int value) =>
      emit(state.copyWith(discountPercent: value.clamp(0, 100)));

  void setHasDelivery(bool value) {
    emit(
      state.copyWith(
        hasDelivery: value,
        // Reset price when delivery is turned off so we never persist a stale
        // non-zero value behind the disabled toggle.
        deliveryPrice: value ? state.deliveryPrice : 0,
      ),
    );
  }

  void setDeliveryPrice(num value) =>
      emit(state.copyWith(deliveryPrice: value));

  void setHasInstallation(bool value) {
    emit(
      state.copyWith(
        hasInstallation: value,
        // Same defensive reset as delivery — toggle off, price goes to zero so
        // the disabled state never carries a stale value.
        installationPrice: value ? state.installationPrice : 0,
      ),
    );
  }

  void setInstallationPrice(num value) =>
      emit(state.copyWith(installationPrice: value));

  void setWarrantyMonths(int value) =>
      emit(state.copyWith(warrantyMonths: value.clamp(0, 120)));

  void addImage(File file) {
    if (!state.canPickMoreImages) return;
    emit(state.copyWith(images: [...state.images, FormImage.local(file)]));
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
      final remaining = state.maxImages - state.images.length;
      if (remaining <= 0) return 0;
      accepted = files.length <= remaining
          ? files
          : files.sublist(0, remaining);
    }
    emit(
      state.copyWith(
        images: [...state.images, for (final f in accepted) FormImage.local(f)],
      ),
    );
    return accepted.length;
  }

  void removeImageAt(int index) {
    if (index < 0 || index >= state.images.length) return;
    final next = [...state.images]..removeAt(index);
    emit(state.copyWith(images: next));
  }

  void regenerateSku() => emit(state.copyWith(sku: _generateSku()));

  /// Saves the form: create mode uploads + POSTs a new product; edit mode
  /// uploads only the newly-picked photos and PATCHes the existing row.
  /// Returns `true` on success so the screen can pop after the snackbar.
  /// Saves the form (create or edit). [forceCreate] re-sends after the seller
  /// dismissed a duplicate warning with "Baribir qo'shish", telling the backend
  /// to skip the seller-scoped similarity check.
  Future<bool> submit({bool forceCreate = false}) async {
    final ctx = state.context;
    if (ctx == null) {
      talker.warning('[add-product-cubit] submit aborted — no shop context');
      return false;
    }
    // Editing never consumes a new tariff slot, so the quota gate only
    // applies to create mode.
    if (!state.isEditing && !ctx.canAddMoreProducts) {
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
        'price=${state.price} images=${state.images.length} '
        'requiredAttrsOk=${state.hasAllRequiredAttributes}',
      );
      return false;
    }

    talker.info(
      '[add-product-cubit] submit start sku=${state.sku} '
      'editing=${state.editingProductId ?? '-'} '
      'category=${state.categoryId} sub=${state.subcategoryId} '
      'images=${state.images.length} attributes=${state.attributes.length} '
      'currency=${state.priceCurrency.name} priceUzs=${state.priceInUzs}',
    );
    emit(
      state.copyWith(
        status: AddProductStatus.saving,
        clearError: true,
        clearDuplicate: true,
      ),
    );
    try {
      final input = AddProductInput(
        sellerId: ctx.sellerId,
        shopId: ctx.shopId,
        name: state.name.trim(),
        description: state.description.trim(),
        categoryId: state.categoryId!,
        subcategoryId: state.subcategoryId,
        // The backend is UZS-only and must stay unaware of the currency
        // toggle — USD input is converted with the CBU rate and rounded to a
        // whole som here, at the last client-side moment.
        price: state.priceInUzs,
        discountPercent: state.discountPercent,
        sku: state.sku,
        colorSlugs: state.colorSlugs.toList(),
        colorNames: [
          for (final slug in state.colorSlugs) _colorNameFor(slug) ?? slug,
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
        images: state.images,
      );
      final editingId = state.editingProductId;
      if (editingId != null) {
        await _repository.updateProduct(
          editingId,
          input,
          forceCreate: forceCreate,
        );
        unawaited(_analytics?.productUpdated(productId: editingId));
      } else {
        final result = await _repository.createProduct(
          input,
          forceCreate: forceCreate,
        );
        unawaited(_analytics?.productCreated(productId: result.productId));
      }
      if (!isClosed) {
        emit(state.copyWith(status: AddProductStatus.success));
      }
      talker.info('[add-product-cubit] submit ok sku=${state.sku}');
      return true;
    } catch (e, st) {
      // 409 DUPLICATE_DETECTED is a soft warning, not a failure: surface the
      // matched product so the form can offer "save anyway" (force_create).
      if (e is ApiError) {
        final match = DuplicateProductMatch.fromApiError(e);
        if (match != null) {
          talker.info(
            '[add-product-cubit] duplicate detected '
            'match=${match.id} sim=${match.similarity}',
          );
          if (!isClosed) {
            emit(
              state.copyWith(
                status: AddProductStatus.failure,
                clearError: true,
                duplicateMatch: match,
              ),
            );
          }
          return false;
        }
      }
      talker.handle(
        e,
        st,
        '[add-product-cubit] submit failed sku=${state.sku}',
      );
      // The backend sends seller-actionable Uzbek copy in `detail`
      // (e.g. "Tarif limit: …"); show that, not the ApiError envelope.
      final message = e is ApiError ? (e.message ?? e.code) : e.toString();
      if (!isClosed) {
        emit(state.copyWith(status: AddProductStatus.failure, error: message));
      }
      return false;
    }
  }

  /// Drafts the form from the currently-picked photos: uploads them, asks the
  /// backend's vision model for a suggestion, and applies whatever came back.
  /// The seller reviews and edits before saving — AI never auto-submits.
  ///
  /// Returns `(available, sameProduct)` so the UI can pick the right message:
  /// success, a "couldn't read the photos" soft message (`available:false`),
  /// or a "these look like different products" warning (`sameProduct:false`).
  /// Empty images, a busy run, or an upload failure are handled gracefully —
  /// this never throws.
  Future<({bool available, bool sameProduct})> generateFromImages() async {
    final ctx = state.context;
    if (ctx == null || state.images.isEmpty || state.isAiBusy) {
      return (available: false, sameProduct: true);
    }
    // Trim to the backend's image cap — the first photos are the primary/most
    // representative ones, and sending more would 422.
    final images = state.images.length > _maxAiImages
        ? state.images.sublist(0, _maxAiImages)
        : state.images;

    emit(state.copyWith(isAiBusy: true, clearError: true));
    unawaited(_analytics?.aiSuggestRequested(imageCount: images.length));
    try {
      final result = await _repository.suggestFromImages(
        sellerId: ctx.sellerId,
        images: images,
      );
      if (isClosed) return (available: false, sameProduct: true);
      final s = result.suggestion;
      if (s.hasAnything) {
        await _applySuggestion(s);
        if (isClosed) return (available: false, sameProduct: true);
      }
      unawaited(_analytics?.aiSuggestApplied(available: s.available));
      emit(state.copyWith(isAiBusy: false));
      talker.info(
        '[add-product-cubit] ai-suggest done available=${s.available} '
        'sameProduct=${s.sameProduct} applied=${s.hasAnything}',
      );
      return (available: s.available, sameProduct: s.sameProduct);
    } catch (e, st) {
      talker.handle(e, st, '[add-product-cubit] ai-suggest failed');
      if (!isClosed) {
        emit(state.copyWith(isAiBusy: false));
      }
      return (available: false, sameProduct: true);
    }
  }

  /// Applies a suggestion field-by-field. Category is applied first and its
  /// attribute schema is awaited before the AI attributes land, so we only
  /// keep keys the chosen category actually defines (the same contract the
  /// manual form enforces).
  Future<void> _applySuggestion(AiProductSuggestion s) async {
    if (s.name != null) emit(state.copyWith(name: s.name));
    if (s.description != null) emit(state.copyWith(description: s.description));

    for (final slug in s.colors) {
      if (!state.colorSlugs.contains(slug) &&
          productColorBySlug(slug) != null) {
        toggleColor(slug);
      }
    }

    final categoryId = s.categoryId;
    if (categoryId != null && findCategory(categoryId) != null) {
      selectCategory(categoryId);
      final sub = s.subcategoryId;
      if (sub != null && _subcategoryExists(categoryId, sub)) {
        selectSubcategory(sub);
      }
      // selectCategory/selectSubcategory kick off an async schema load; wait
      // for it to settle so the attributes below are validated against the
      // real schema rather than an empty one.
      await _awaitSchema();
      if (isClosed) return;
    }

    if (s.attributes.isNotEmpty && state.attributeSchema.isNotEmpty) {
      final validKeys = {for (final d in state.attributeSchema) d.key};
      for (final entry in s.attributes.entries) {
        if (validKeys.contains(entry.key) && entry.value != null) {
          setAttribute(entry.key, entry.value);
        }
      }
    }
  }

  bool _subcategoryExists(String categoryId, String subcategoryId) {
    final cat = findCategory(categoryId);
    if (cat == null) return false;
    for (final s in cat.subcategories) {
      if (s.id == subcategoryId) return true;
    }
    return false;
  }

  /// Loads the attribute schema for the current (category, subcategory) and
  /// awaits it — the awaitable twin of [_reloadSchema], used by the AI flow so
  /// attribute application can depend on the schema being present.
  Future<void> _awaitSchema() async {
    final categoryId = state.categoryId;
    if (categoryId == null) return;
    final token = ++_schemaRequestId;
    emit(state.copyWith(isLoadingSchema: true));
    try {
      final schema = await _attributesRepository.loadForCategory(
        categoryId: categoryId,
        subcategoryId: state.subcategoryId,
      );
      if (isClosed || token != _schemaRequestId) return;
      emit(state.copyWith(attributeSchema: schema, isLoadingSchema: false));
    } catch (e) {
      if (isClosed || token != _schemaRequestId) return;
      emit(state.copyWith(isLoadingSchema: false, error: e.toString()));
    }
  }

  /// Human-readable color name persisted on the variant row. We keep the slug
  /// in the form state for cheap equality checks, then map it to the
  /// localised display name at save time.
  String? _colorNameFor(String? slug) {
    if (slug == null) return null;
    return productColorBySlug(slug)?.label ?? '';
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
