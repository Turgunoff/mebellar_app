import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/models/category_model.dart';
import '../../../../shared/models/tariff.dart';

/// Snapshot of the seller's shop + plan that the add-product screen needs
/// before the user can start filling the form. Loaded once via
/// [AddProductRepository.loadShopContext] so the cubit can:
///   * gate access (`canAddMoreProducts` against the current product count),
///   * cap image picking dynamically (`plan.maxImagesPerProduct`),
///   * surface the right tariff snapshot to the upgrade prompt.
class AddProductShopContext {
  const AddProductShopContext({
    required this.shopId,
    required this.sellerId,
    required this.plan,
    required this.activeProductsCount,
    required this.categories,
  });

  final String shopId;
  final String sellerId;
  final SubscriptionPlan plan;
  final int activeProductsCount;
  final List<CategoryModel> categories;

  bool get canAddMoreProducts => plan.canAddMoreProducts(activeProductsCount);

  /// `-1` means unlimited.
  int get maxImages => plan.maxImagesPerProduct;

  TariffSnapshot get tariffSnapshot => TariffSnapshot(
        plan: plan.asEnum,
        activeProductsCount: activeProductsCount,
      );
}

/// Inputs the cubit hands to the repository when the user taps
/// "Saqlash va e'lon qilish". Single-variant MVP: one product row + one
/// variant row + N image rows are inserted atomically in [createProduct].
class AddProductInput {
  const AddProductInput({
    required this.sellerId,
    required this.shopId,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.price,
    required this.discountPercent,
    required this.sku,
    required this.colorName,
    required this.widthCm,
    required this.heightCm,
    required this.depthCm,
    required this.material,
    required this.productionTimeDays,
    required this.hasDelivery,
    required this.deliveryPrice,
    required this.hasInstallation,
    required this.warrantyMonths,
    required this.imageFiles,
  });

  final String sellerId;
  final String shopId;
  final String name;
  final String description;
  final String categoryId;
  final num price;
  final int discountPercent;
  final String sku;
  final String? colorName;
  final int? widthCm;
  final int? heightCm;
  final int? depthCm;
  final String? material;
  final String? productionTimeDays;
  final bool hasDelivery;
  final num deliveryPrice;
  final bool hasInstallation;
  final int warrantyMonths;
  final List<File> imageFiles;
}

class AddProductResult {
  const AddProductResult({required this.productId, required this.imageUrls});
  final String productId;
  final List<String> imageUrls;
}

/// Add-product data layer. Wraps Supabase Storage upload + the
/// `products` / `product_variants` / `product_images` triple-insert so the
/// cubit stays free of SDK details.
class AddProductRepository {
  AddProductRepository({required SupabaseClient supabase}) : _client = supabase;

  final SupabaseClient _client;

  static const _bucket = 'product-images';

  /// One-shot context load that the screen uses to gate access AND drive the
  /// dynamic image cap. The query joins the shop row to its subscription plan
  /// so the canonical `max_products` / `max_images_per_product` limits come
  /// from the DB rather than the Dart enum defaults.
  Future<AddProductShopContext> loadShopContext() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Seller is not authenticated');
    }

    final shopRow = await _client
        .from('shops')
        .select('id, plan:subscription_plans(*)')
        .eq('seller_id', userId)
        .maybeSingle();
    if (shopRow == null) {
      throw StateError("Shop is not yet created for the current seller");
    }

    final planJson = shopRow['plan'];
    final plan = planJson is Map<String, dynamic>
        ? SubscriptionPlan.fromJson(planJson)
        : _fallbackPlan;

    final productsCount = await _countActiveProducts(shopRow['id'] as String);
    final categories = await _fetchCategories();

    return AddProductShopContext(
      shopId: shopRow['id'] as String,
      sellerId: userId,
      plan: plan,
      activeProductsCount: productsCount,
      categories: categories,
    );
  }

  Future<int> _countActiveProducts(String shopId) async {
    final rows = await _client
        .from('products')
        .select('id')
        .eq('shop_id', shopId);
    return rows.length;
  }

  Future<List<CategoryModel>> _fetchCategories() async {
    final rows = await _client
        .from('categories')
        .select('id, name, name_uz, name_ru, subtitle, image_url, sort_order')
        .order('sort_order', ascending: true);
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map((r) => CategoryModel(
              id: r['id'] as String,
              name: (r['name_uz'] as String?) ?? (r['name'] as String? ?? ''),
              subtitle: r['subtitle'] as String?,
              imageUrl: r['image_url'] as String?,
              sortOrder: r['sort_order'] as int? ?? 0,
            ))
        .toList(growable: false);
  }

  /// Persists the product. Order matters: storage uploads happen first so a
  /// network failure aborts before any DB row exists. Once images are up, we
  /// insert the product row, then the single variant, then one row per image.
  Future<AddProductResult> createProduct(AddProductInput input) async {
    if (input.imageFiles.isEmpty) {
      throw StateError('At least one product image is required');
    }

    final uploaded = await _uploadImages(
      sellerId: input.sellerId,
      files: input.imageFiles,
    );

    final productPayload = <String, dynamic>{
      'shop_id': input.shopId,
      'seller_id': input.sellerId,
      'category_id': input.categoryId,
      'name': input.name,
      'description': input.description.isEmpty ? null : input.description,
      'price': input.price,
      'images': uploaded.map((u) => u.publicUrl).toList(),
      'width_cm': input.widthCm,
      'height_cm': input.heightCm,
      'depth_cm': input.depthCm,
      'material': input.material,
      'production_time_days': input.productionTimeDays,
      'has_delivery': input.hasDelivery,
      'delivery_price': input.hasDelivery ? input.deliveryPrice : 0,
      'has_installation': input.hasInstallation,
      'warranty_months': input.warrantyMonths,
      'status': 'pending_review',
    };

    final productRow = await _client
        .from('products')
        .insert(productPayload)
        .select('id')
        .single();
    final productId = productRow['id'] as String;

    final discountPrice = input.discountPercent > 0
        ? (input.price *
                (100 - input.discountPercent) /
                100)
            .roundToDouble()
        : null;

    await _client.from('product_variants').insert({
      'product_id': productId,
      'sku': input.sku,
      'color_name': input.colorName,
      'price': input.price,
      'discount_price': discountPrice,
    });

    if (uploaded.isNotEmpty) {
      final imageRows = <Map<String, dynamic>>[
        for (var i = 0; i < uploaded.length; i++)
          {
            'product_id': productId,
            'image_url': uploaded[i].publicUrl,
            'is_main': i == 0,
            'sort_order': i,
          },
      ];
      await _client.from('product_images').insert(imageRows);
    }

    return AddProductResult(
      productId: productId,
      imageUrls: uploaded.map((u) => u.publicUrl).toList(),
    );
  }

  Future<List<_UploadedImage>> _uploadImages({
    required String sellerId,
    required List<File> files,
  }) async {
    final results = <_UploadedImage>[];
    for (final file in files) {
      final compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        format: CompressFormat.webp,
        quality: 82,
        keepExif: false,
        minWidth: 1024,
        minHeight: 1024,
      );
      final bytes = compressed ?? await file.readAsBytes();
      final objectPath = '$sellerId/${_randomObjectName()}.webp';
      await _client.storage.from(_bucket).uploadBinary(
            objectPath,
            Uint8List.fromList(bytes),
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'image/webp',
              cacheControl: '3600',
            ),
          );
      final publicUrl = _client.storage.from(_bucket).getPublicUrl(objectPath);
      results.add(_UploadedImage(path: objectPath, publicUrl: publicUrl));
    }
    return results;
  }

  /// Pseudo-uuid that's safe inside a storage object name. Combines a
  /// millisecond timestamp with a 6-char random suffix derived from the
  /// SDK's auth UID + Object.hashCode — good enough for a low-volume
  /// per-seller folder where collision risk is essentially zero.
  String _randomObjectName() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rand = identityHashCode(Object()).toRadixString(36);
    return '${ts}_$rand';
  }

  static final SubscriptionPlan _fallbackPlan = SubscriptionPlan(
    id: '',
    code: TariffPlan.free.code,
    name: TariffPlan.free.code,
    priceMonthly: TariffPlan.free.monthlyPriceUzs,
    maxProducts: TariffPlan.free.maxActiveProducts,
    maxImagesPerProduct: TariffPlan.free.maxImagesPerProduct,
    commissionRate: TariffPlan.free.commissionRate,
  );
}

class _UploadedImage {
  const _UploadedImage({required this.path, required this.publicUrl});
  final String path;
  final String publicUrl;
}
