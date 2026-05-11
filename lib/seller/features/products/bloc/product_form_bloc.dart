import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/multilingual_text.dart';
import '../../../../shared/models/seller_product.dart';
import '../../../../shared/models/tariff.dart';
import '../../../../shared/repositories/seller_product_repository.dart';

/// Multi-step product editor state. Wraps both create and edit flows — the
/// caller passes an `existing` product when editing so the form pre-fills.
enum ProductFormStep {
  basics,
  category,
  pricing,
  images,
  dimensions,
  finalize;

  static const total = 6;
}

sealed class ProductFormEvent extends Equatable {
  const ProductFormEvent();
  @override
  List<Object?> get props => const [];
}

class ProductFormStarted extends ProductFormEvent {
  const ProductFormStarted({this.existing});
  final SellerProduct? existing;
  @override
  List<Object?> get props => [existing?.id];
}

class ProductFormNextStep extends ProductFormEvent {
  const ProductFormNextStep();
}

class ProductFormPreviousStep extends ProductFormEvent {
  const ProductFormPreviousStep();
}

class ProductFormBasicsChanged extends ProductFormEvent {
  const ProductFormBasicsChanged({
    this.nameUz,
    this.nameRu,
    this.nameEn,
    this.descriptionUz,
    this.descriptionRu,
    this.descriptionEn,
  });
  final String? nameUz;
  final String? nameRu;
  final String? nameEn;
  final String? descriptionUz;
  final String? descriptionRu;
  final String? descriptionEn;
  @override
  List<Object?> get props => [
        nameUz,
        nameRu,
        nameEn,
        descriptionUz,
        descriptionRu,
        descriptionEn,
      ];
}

class ProductFormCategoryChanged extends ProductFormEvent {
  const ProductFormCategoryChanged(this.slug);
  final String slug;
  @override
  List<Object?> get props => [slug];
}

class ProductFormAttributeChanged extends ProductFormEvent {
  const ProductFormAttributeChanged({required this.key, required this.value});
  final String key;
  final String value;
  @override
  List<Object?> get props => [key, value];
}

class ProductFormPricingChanged extends ProductFormEvent {
  const ProductFormPricingChanged({this.price, this.oldPrice, this.stock, this.sku});
  final num? price;
  final num? oldPrice;
  final int? stock;
  final String? sku;
  @override
  List<Object?> get props => [price, oldPrice, stock, sku];
}

class ProductFormDimensionsChanged extends ProductFormEvent {
  const ProductFormDimensionsChanged({
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.weightKg,
  });
  final num? lengthCm;
  final num? widthCm;
  final num? heightCm;
  final num? weightKg;
  @override
  List<Object?> get props => [lengthCm, widthCm, heightCm, weightKg];
}

class ProductFormImagePicked extends ProductFormEvent {
  const ProductFormImagePicked({required this.file, required this.fileExtension});
  final File file;
  final String fileExtension;
  @override
  List<Object?> get props => [file.path, fileExtension];
}

class ProductFormImageRemoved extends ProductFormEvent {
  const ProductFormImageRemoved(this.imageId);
  final String imageId;
  @override
  List<Object?> get props => [imageId];
}

class ProductFormImagesReordered extends ProductFormEvent {
  const ProductFormImagesReordered(this.idsInOrder);
  final List<String> idsInOrder;
  @override
  List<Object?> get props => [idsInOrder];
}

class ProductFormPrimaryImageChanged extends ProductFormEvent {
  const ProductFormPrimaryImageChanged(this.imageId);
  final String imageId;
  @override
  List<Object?> get props => [imageId];
}

class ProductFormSaveDraft extends ProductFormEvent {
  const ProductFormSaveDraft();
}

class ProductFormSubmittedForReview extends ProductFormEvent {
  const ProductFormSubmittedForReview();
}

class _ProductFormStateRefreshed extends ProductFormEvent {
  const _ProductFormStateRefreshed(this.product);
  final SellerProduct product;
  @override
  List<Object?> get props => [product];
}

enum ProductFormStatus { editing, saving, saved, failure, tariffLimit }

class ProductFormState extends Equatable {
  const ProductFormState({
    this.status = ProductFormStatus.editing,
    this.step = ProductFormStep.basics,
    this.productId,
    this.nameUz = '',
    this.nameRu = '',
    this.nameEn = '',
    this.descriptionUz = '',
    this.descriptionRu = '',
    this.descriptionEn = '',
    this.categorySlug,
    this.attributes = const {},
    this.price = 0,
    this.oldPrice,
    this.stock = 0,
    this.sku = '',
    this.images = const [],
    this.primaryImageId,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.weightKg,
    this.error,
    this.tariffSnapshot,
  });

  final ProductFormStatus status;
  final ProductFormStep step;
  final String? productId;

  final String nameUz;
  final String nameRu;
  final String nameEn;
  final String descriptionUz;
  final String descriptionRu;
  final String descriptionEn;

  final String? categorySlug;
  final Map<String, String> attributes;

  final num price;
  final num? oldPrice;
  final int stock;
  final String sku;

  final List<SellerProductImage> images;
  final String? primaryImageId;

  final num? lengthCm;
  final num? widthCm;
  final num? heightCm;
  final num? weightKg;

  final String? error;
  final TariffSnapshot? tariffSnapshot;

  bool get isEdit => productId != null;
  bool get hasName =>
      nameUz.trim().isNotEmpty ||
      nameRu.trim().isNotEmpty ||
      nameEn.trim().isNotEmpty;

  MultilingualText get nameMl =>
      MultilingualText(uz: nameUz, ru: nameRu, en: nameEn);
  MultilingualText get descriptionMl =>
      MultilingualText(uz: descriptionUz, ru: descriptionRu, en: descriptionEn);

  bool canAdvanceFrom(ProductFormStep step) {
    return switch (step) {
      ProductFormStep.basics => hasName,
      ProductFormStep.category => categorySlug != null,
      ProductFormStep.pricing =>
        price > 0 && stock >= 0 && sku.trim().isNotEmpty,
      ProductFormStep.images => images.any((i) => i.isUploaded),
      ProductFormStep.dimensions => true,
      ProductFormStep.finalize => false,
    };
  }

  ProductFormState copyWith({
    ProductFormStatus? status,
    ProductFormStep? step,
    String? productId,
    String? nameUz,
    String? nameRu,
    String? nameEn,
    String? descriptionUz,
    String? descriptionRu,
    String? descriptionEn,
    String? categorySlug,
    Map<String, String>? attributes,
    num? price,
    num? oldPrice,
    int? stock,
    String? sku,
    List<SellerProductImage>? images,
    String? primaryImageId,
    num? lengthCm,
    num? widthCm,
    num? heightCm,
    num? weightKg,
    String? error,
    bool clearError = false,
    TariffSnapshot? tariffSnapshot,
    bool clearTariffSnapshot = false,
  }) {
    return ProductFormState(
      status: status ?? this.status,
      step: step ?? this.step,
      productId: productId ?? this.productId,
      nameUz: nameUz ?? this.nameUz,
      nameRu: nameRu ?? this.nameRu,
      nameEn: nameEn ?? this.nameEn,
      descriptionUz: descriptionUz ?? this.descriptionUz,
      descriptionRu: descriptionRu ?? this.descriptionRu,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      categorySlug: categorySlug ?? this.categorySlug,
      attributes: attributes ?? this.attributes,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      stock: stock ?? this.stock,
      sku: sku ?? this.sku,
      images: images ?? this.images,
      primaryImageId: primaryImageId ?? this.primaryImageId,
      lengthCm: lengthCm ?? this.lengthCm,
      widthCm: widthCm ?? this.widthCm,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      error: clearError ? null : (error ?? this.error),
      tariffSnapshot: clearTariffSnapshot
          ? null
          : (tariffSnapshot ?? this.tariffSnapshot),
    );
  }

  @override
  List<Object?> get props => [
        status,
        step,
        productId,
        nameUz,
        nameRu,
        nameEn,
        descriptionUz,
        descriptionRu,
        descriptionEn,
        categorySlug,
        attributes,
        price,
        oldPrice,
        stock,
        sku,
        images,
        primaryImageId,
        lengthCm,
        widthCm,
        heightCm,
        weightKg,
        error,
        tariffSnapshot,
      ];
}

class ProductFormBloc extends Bloc<ProductFormEvent, ProductFormState> {
  ProductFormBloc(this._repo) : super(const ProductFormState()) {
    on<ProductFormStarted>(_onStarted);
    on<ProductFormNextStep>(_onNext);
    on<ProductFormPreviousStep>(_onPrev);
    on<ProductFormBasicsChanged>(_onBasics);
    on<ProductFormCategoryChanged>(
        (e, emit) => emit(state.copyWith(categorySlug: e.slug)));
    on<ProductFormAttributeChanged>(_onAttribute);
    on<ProductFormPricingChanged>(_onPricing);
    on<ProductFormDimensionsChanged>(_onDimensions);
    on<ProductFormImagePicked>(_onImagePicked);
    on<ProductFormImageRemoved>(_onImageRemoved);
    on<ProductFormImagesReordered>(_onImagesReordered);
    on<ProductFormPrimaryImageChanged>(_onPrimaryChanged);
    on<ProductFormSaveDraft>(_onSaveDraft);
    on<ProductFormSubmittedForReview>(_onSubmitted);
    on<_ProductFormStateRefreshed>(_onRefreshed);

    _sub = _repo.watch().listen((products) {
      final id = state.productId;
      if (id == null) return;
      final p = products.where((x) => x.id == id).firstOrNull;
      if (p != null) add(_ProductFormStateRefreshed(p));
    });
  }

  final SellerProductRepository _repo;
  StreamSubscription<List<SellerProduct>>? _sub;

  Future<void> _onStarted(
    ProductFormStarted event,
    Emitter<ProductFormState> emit,
  ) async {
    final p = event.existing;
    if (p == null) {
      emit(const ProductFormState());
      return;
    }
    emit(ProductFormState(
      productId: p.id,
      nameUz: p.name.uz ?? '',
      nameRu: p.name.ru ?? '',
      nameEn: p.name.en ?? '',
      descriptionUz: p.description.uz ?? '',
      descriptionRu: p.description.ru ?? '',
      descriptionEn: p.description.en ?? '',
      categorySlug: p.categorySlug,
      attributes: {
        for (final entry in p.attributes.entries)
          entry.key: '${entry.value}',
      },
      price: p.price,
      oldPrice: p.oldPrice,
      stock: p.stock,
      sku: p.sku,
      images: p.images,
      primaryImageId: p.primaryImageId,
      lengthCm: p.lengthCm,
      widthCm: p.widthCm,
      heightCm: p.heightCm,
      weightKg: p.weightKg,
    ));
  }

  void _onNext(ProductFormNextStep event, Emitter<ProductFormState> emit) {
    if (!state.canAdvanceFrom(state.step)) return;
    final nextIdx = state.step.index + 1;
    if (nextIdx >= ProductFormStep.values.length) return;
    emit(state.copyWith(step: ProductFormStep.values[nextIdx]));
  }

  void _onPrev(ProductFormPreviousStep event, Emitter<ProductFormState> emit) {
    final prevIdx = state.step.index - 1;
    if (prevIdx < 0) return;
    emit(state.copyWith(step: ProductFormStep.values[prevIdx]));
  }

  void _onBasics(
    ProductFormBasicsChanged event,
    Emitter<ProductFormState> emit,
  ) {
    emit(state.copyWith(
      nameUz: event.nameUz,
      nameRu: event.nameRu,
      nameEn: event.nameEn,
      descriptionUz: event.descriptionUz,
      descriptionRu: event.descriptionRu,
      descriptionEn: event.descriptionEn,
    ));
  }

  void _onAttribute(
    ProductFormAttributeChanged event,
    Emitter<ProductFormState> emit,
  ) {
    final next = Map<String, String>.from(state.attributes);
    if (event.value.trim().isEmpty) {
      next.remove(event.key);
    } else {
      next[event.key] = event.value;
    }
    emit(state.copyWith(attributes: next));
  }

  void _onPricing(
    ProductFormPricingChanged event,
    Emitter<ProductFormState> emit,
  ) {
    emit(state.copyWith(
      price: event.price ?? state.price,
      oldPrice: event.oldPrice,
      stock: event.stock ?? state.stock,
      sku: event.sku ?? state.sku,
    ));
  }

  void _onDimensions(
    ProductFormDimensionsChanged event,
    Emitter<ProductFormState> emit,
  ) {
    emit(state.copyWith(
      lengthCm: event.lengthCm ?? state.lengthCm,
      widthCm: event.widthCm ?? state.widthCm,
      heightCm: event.heightCm ?? state.heightCm,
      weightKg: event.weightKg ?? state.weightKg,
    ));
  }

  Future<void> _onImagePicked(
    ProductFormImagePicked event,
    Emitter<ProductFormState> emit,
  ) async {
    if (state.images.length >= 10) {
      emit(state.copyWith(error: 'image_limit'));
      return;
    }
    var productId = state.productId;
    // First image picked while creating a brand-new product needs a draft on
    // the backend so subsequent uploads have a target. Save a placeholder
    // draft now if needed.
    if (productId == null) {
      try {
        final created = await _repo.create(SellerProductInput(
          name: state.nameMl,
          description: state.descriptionMl,
          categorySlug: state.categorySlug ?? 'other',
          price: state.price,
          oldPrice: state.oldPrice,
          stock: state.stock,
          sku: state.sku.isEmpty ? 'TMP-${DateTime.now().millisecondsSinceEpoch}' : state.sku,
          attributes: state.attributes,
          lengthCm: state.lengthCm,
          widthCm: state.widthCm,
          heightCm: state.heightCm,
          weightKg: state.weightKg,
          status: SellerProductStatus.draft,
        ));
        productId = created.id;
        emit(state.copyWith(productId: productId, images: created.images));
      } on TariffLimitException catch (e) {
        emit(state.copyWith(
          status: ProductFormStatus.tariffLimit,
          tariffSnapshot: e.snapshot,
        ));
        return;
      } catch (e) {
        emit(state.copyWith(error: e.toString()));
        return;
      }
    }

    try {
      await _repo.uploadImage(
        productId: productId,
        file: event.file,
        fileExtension: event.fileExtension,
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onImageRemoved(
    ProductFormImageRemoved event,
    Emitter<ProductFormState> emit,
  ) async {
    final productId = state.productId;
    if (productId == null) return;
    try {
      await _repo.deleteImage(
          productId: productId, imageId: event.imageId);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onImagesReordered(
    ProductFormImagesReordered event,
    Emitter<ProductFormState> emit,
  ) async {
    final productId = state.productId;
    if (productId == null) return;
    try {
      await _repo.reorderImages(
          productId: productId, imageIdsInOrder: event.idsInOrder);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onPrimaryChanged(
    ProductFormPrimaryImageChanged event,
    Emitter<ProductFormState> emit,
  ) async {
    final productId = state.productId;
    if (productId == null) return;
    try {
      await _repo.setPrimaryImage(
          productId: productId, imageId: event.imageId);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onSaveDraft(
    ProductFormSaveDraft event,
    Emitter<ProductFormState> emit,
  ) async {
    await _persist(emit, status: SellerProductStatus.draft);
  }

  Future<void> _onSubmitted(
    ProductFormSubmittedForReview event,
    Emitter<ProductFormState> emit,
  ) async {
    final saved = await _persist(emit, status: SellerProductStatus.draft);
    if (saved == null) return;
    try {
      await _repo.submitForReview(saved.id);
      emit(state.copyWith(status: ProductFormStatus.saved));
    } catch (e) {
      emit(state.copyWith(
          status: ProductFormStatus.failure, error: e.toString()));
    }
  }

  void _onRefreshed(
    _ProductFormStateRefreshed event,
    Emitter<ProductFormState> emit,
  ) {
    final p = event.product;
    emit(state.copyWith(
      images: p.images,
      primaryImageId: p.primaryImageId,
      // Don't overwrite any fields the user is currently typing — only sync
      // the image-related state from realtime updates.
    ));
  }

  Future<SellerProduct?> _persist(
    Emitter<ProductFormState> emit, {
    required SellerProductStatus status,
  }) async {
    emit(state.copyWith(
      status: ProductFormStatus.saving,
      clearError: true,
      clearTariffSnapshot: true,
    ));
    final input = SellerProductInput(
      name: state.nameMl,
      description: state.descriptionMl,
      categorySlug: state.categorySlug ?? 'other',
      price: state.price,
      oldPrice: state.oldPrice,
      stock: state.stock,
      sku: state.sku,
      attributes: state.attributes,
      lengthCm: state.lengthCm,
      widthCm: state.widthCm,
      heightCm: state.heightCm,
      weightKg: state.weightKg,
      status: status,
    );
    try {
      final saved = state.productId == null
          ? await _repo.create(input)
          : await _repo.update(state.productId!, input);
      emit(state.copyWith(
        status: ProductFormStatus.saved,
        productId: saved.id,
      ));
      return saved;
    } on TariffLimitException catch (e) {
      emit(state.copyWith(
        status: ProductFormStatus.tariffLimit,
        tariffSnapshot: e.snapshot,
      ));
      return null;
    } catch (e) {
      emit(state.copyWith(
        status: ProductFormStatus.failure,
        error: e.toString(),
      ));
      return null;
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
