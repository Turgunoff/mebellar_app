import 'dart:async';
import 'dart:io';

import 'package:woody_app/shared/models/multilingual_text.dart';
import 'package:woody_app/shared/models/paginated.dart';
import 'package:woody_app/shared/models/seller_product.dart';
import 'package:woody_app/shared/models/tariff.dart';
import 'package:woody_app/shared/repositories/seller_product_repository.dart';
import 'mock_seller_products.dart';
import 'mock_seller_state.dart';

class MockSellerProductRepository implements SellerProductRepository {
  MockSellerProductRepository() {
    _products.addAll(MockSellerProducts.products);
  }

  static const _delay = Duration(milliseconds: 280);
  static const _uploadDelay = Duration(milliseconds: 700);
  static const _activeStatuses = {
    SellerProductStatus.approved,
    SellerProductStatus.pendingReview,
  };

  final List<SellerProduct> _products = [];
  final _controller = StreamController<List<SellerProduct>>.broadcast();
  int _idCounter = 100;

  int get _activeCount =>
      _products.where((p) => _activeStatuses.contains(p.status)).length;

  void _emit() => _controller.add(List<SellerProduct>.unmodifiable(_products));

  @override
  Stream<List<SellerProduct>> watch() => _controller.stream;

  @override
  Future<Paginated<SellerProduct>> list({
    SellerProductFilter filter = const SellerProductFilter(),
    int page = 1,
    int perPage = 20,
  }) async {
    await Future<void>.delayed(_delay);
    final filtered = _products.where(filter.matches).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final total = filtered.length;
    final start = (page - 1) * perPage;
    final end = (start + perPage).clamp(0, total);
    final pageItems =
        start >= total ? <SellerProduct>[] : filtered.sublist(start, end);
    return Paginated(
      items: pageItems,
      page: page,
      perPage: perPage,
      total: total,
      hasNext: end < total,
    );
  }

  @override
  Future<SellerProduct> getById(String id) async {
    await Future<void>.delayed(_delay);
    final p = _products.where((x) => x.id == id).firstOrNull;
    if (p == null) throw StateError('Mahsulot topilmadi: $id');
    return p;
  }

  @override
  Future<SellerProduct> create(SellerProductInput input) async {
    await Future<void>.delayed(_delay);
    final tariff = TariffSnapshot(
      plan: TariffPlan.free,
      activeProductsCount: _activeCount,
    );
    final wouldBeActive = _activeStatuses.contains(input.status) ||
        input.status == SellerProductStatus.draft;
    if (wouldBeActive && tariff.reachedLimit) {
      throw TariffLimitException(tariff);
    }
    _idCounter += 1;
    final now = DateTime.now();
    final product = SellerProduct(
      id: 'sp-mock-$_idCounter',
      name: input.name as MultilingualText,
      description: input.description as MultilingualText,
      categorySlug: input.categorySlug,
      price: input.price,
      oldPrice: input.oldPrice,
      stock: input.stock,
      sku: input.sku,
      images: const [],
      attributes: input.attributes,
      lengthCm: input.lengthCm,
      widthCm: input.widthCm,
      heightCm: input.heightCm,
      weightKg: input.weightKg,
      status: input.status,
      createdAt: now,
      updatedAt: now,
    );
    _products.insert(0, product);
    _emit();
    return product;
  }

  @override
  Future<SellerProduct> update(String id, SellerProductInput input) async {
    await Future<void>.delayed(_delay);
    final idx = _products.indexWhere((p) => p.id == id);
    if (idx < 0) throw StateError('Mahsulot topilmadi: $id');
    final updated = _products[idx].copyWith(
      name: input.name as MultilingualText,
      description: input.description as MultilingualText,
      categorySlug: input.categorySlug,
      price: input.price,
      oldPrice: input.oldPrice,
      stock: input.stock,
      sku: input.sku,
      attributes: input.attributes,
      lengthCm: input.lengthCm,
      widthCm: input.widthCm,
      heightCm: input.heightCm,
      weightKg: input.weightKg,
      status: input.status,
      updatedAt: DateTime.now(),
    );
    _products[idx] = updated;
    _emit();
    return updated;
  }

  @override
  Future<SellerProduct> archive(String id) async {
    await Future<void>.delayed(_delay);
    final idx = _products.indexWhere((p) => p.id == id);
    if (idx < 0) throw StateError('Mahsulot topilmadi: $id');
    _products[idx] = _products[idx].copyWith(
      status: SellerProductStatus.archived,
      updatedAt: DateTime.now(),
    );
    _emit();
    return _products[idx];
  }

  @override
  Future<SellerProduct> submitForReview(String id) async {
    await Future<void>.delayed(_delay);
    final idx = _products.indexWhere((p) => p.id == id);
    if (idx < 0) throw StateError('Mahsulot topilmadi: $id');
    final product = _products[idx];
    if (!product.status.isMutable) {
      throw StateError('Bu holatda submit qilib bo\'lmaydi');
    }
    _products[idx] = product.copyWith(
      status: SellerProductStatus.pendingReview,
      clearRejectionReason: true,
      updatedAt: DateTime.now(),
    );
    // Mock: 8 sekunddan keyin avtomatik approve qiladi (admin simulation).
    Future<void>.delayed(const Duration(seconds: 8), () {
      final stillIdx = _products.indexWhere((p) => p.id == id);
      if (stillIdx < 0) return;
      if (_products[stillIdx].status != SellerProductStatus.pendingReview) {
        return;
      }
      _products[stillIdx] = _products[stillIdx].copyWith(
        status: SellerProductStatus.approved,
        updatedAt: DateTime.now(),
      );
      _emit();
    });
    _emit();
    return _products[idx];
  }

  @override
  Future<SellerProductImage> uploadImage({
    required String productId,
    required File file,
    required String fileExtension,
  }) async {
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx < 0) throw StateError('Mahsulot topilmadi: $productId');
    final imgId =
        'img-${productId.split('-').last}-${DateTime.now().millisecondsSinceEpoch}';
    final placeholder = SellerProductImage(
      id: imgId,
      localPath: file.path,
      uploading: true,
      uploadProgress: 0.0,
    );
    var product = _products[idx];
    product = product.copyWith(
      images: [...product.images, placeholder],
      primaryImageId: product.primaryImageId ?? imgId,
      updatedAt: DateTime.now(),
    );
    _products[idx] = product;
    _emit();

    // Pretend chunked upload: emit 25/50/75/100% progress steps.
    for (var pct in const [0.25, 0.5, 0.75]) {
      await Future<void>.delayed(_uploadDelay ~/ 4);
      final pIdx = _products.indexWhere((p) => p.id == productId);
      if (pIdx < 0) break;
      final imgs = List<SellerProductImage>.from(_products[pIdx].images);
      final imgIdx = imgs.indexWhere((i) => i.id == imgId);
      if (imgIdx >= 0) {
        imgs[imgIdx] = imgs[imgIdx].copyWith(uploadProgress: pct);
        _products[pIdx] = _products[pIdx].copyWith(images: imgs);
        _emit();
      }
    }

    await Future<void>.delayed(_uploadDelay ~/ 4);
    final fIdx = _products.indexWhere((p) => p.id == productId);
    if (fIdx < 0) throw StateError('Mahsulot endi topilmadi');
    final imgs = List<SellerProductImage>.from(_products[fIdx].images);
    final imgIdx = imgs.indexWhere((i) => i.id == imgId);
    if (imgIdx >= 0) {
      imgs[imgIdx] = imgs[imgIdx].copyWith(
        uploading: false,
        uploadProgress: 1.0,
        remoteUrl: file.path,
      );
      _products[fIdx] = _products[fIdx].copyWith(images: imgs);
      _emit();
    }
    return imgs[imgIdx];
  }

  @override
  Future<void> deleteImage({
    required String productId,
    required String imageId,
  }) async {
    await Future<void>.delayed(_delay);
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx < 0) return;
    final remaining =
        _products[idx].images.where((i) => i.id != imageId).toList();
    final newPrimary = _products[idx].primaryImageId == imageId
        ? (remaining.isEmpty ? null : remaining.first.id)
        : _products[idx].primaryImageId;
    _products[idx] = _products[idx].copyWith(
      images: remaining,
      primaryImageId: newPrimary,
      updatedAt: DateTime.now(),
    );
    _emit();
  }

  @override
  Future<SellerProduct> reorderImages({
    required String productId,
    required List<String> imageIdsInOrder,
  }) async {
    await Future<void>.delayed(_delay);
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx < 0) throw StateError('Mahsulot topilmadi: $productId');
    final imgsById = {for (final i in _products[idx].images) i.id: i};
    final reordered = [
      for (final id in imageIdsInOrder)
        if (imgsById.containsKey(id)) imgsById[id]!,
    ];
    _products[idx] = _products[idx].copyWith(
      images: reordered,
      updatedAt: DateTime.now(),
    );
    _emit();
    return _products[idx];
  }

  @override
  Future<SellerProduct> setPrimaryImage({
    required String productId,
    required String imageId,
  }) async {
    await Future<void>.delayed(_delay);
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx < 0) throw StateError('Mahsulot topilmadi: $productId');
    _products[idx] = _products[idx].copyWith(
      primaryImageId: imageId,
      updatedAt: DateTime.now(),
    );
    _emit();
    return _products[idx];
  }

  /// Helpers used by `SellerDashboardRepository` to stay in sync without
  /// querying through `list()` repeatedly.
  int get activeProductsCount => _activeCount;
  Stream<List<SellerProduct>> get stream => _controller.stream;
  // Suppress unused field warning in mock (state not fed through here yet).
  // ignore: unused_element
  void _touch() => MockSellerState.instance;
}
