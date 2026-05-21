import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/failure.dart';
import '../../core/result/result.dart';
import '../models/shop_settings.dart';
import 'shop_settings_repository.dart';

/// Live Supabase implementation of [ShopSettingsRepository].
///
/// Reads/writes the seller-editable slice of `public.shops` plus the
/// contact-channels slice of `public.sellers`. Logo / cover assets live in
/// the public `shop-assets` storage bucket under `<shop_id>/...`.
class SupabaseShopSettingsRepository implements ShopSettingsRepository {
  SupabaseShopSettingsRepository({required SupabaseClient supabase})
      : _client = supabase;

  final SupabaseClient _client;

  static const String _shopsTable = 'shops';
  static const String _sellersTable = 'sellers';
  static const String _assetBucket = 'shop-assets';

  /// Shop settings rarely change out-of-band; the seller form is the
  /// single writer, so an empty stream is correct here (no realtime
  /// fan-in needed).
  @override
  Stream<ShopSettings> watch() => const Stream.empty();

  @override
  Future<Result<ShopSettings>> get() => runCatching(() async {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) {
          throw const AuthFailure(message: 'Tizimga kirish talab qilinadi');
        }
        final shopFuture = _client
            .from(_shopsTable)
            .select()
            .eq('seller_id', userId)
            .maybeSingle();
        final sellerFuture = _client
            .from(_sellersTable)
            .select('contact_phone, contact_email, telegram_username')
            .eq('id', userId)
            .maybeSingle();
        final results = await Future.wait<Map<String, dynamic>?>([
          shopFuture,
          sellerFuture,
        ]);
        final shop = results[0];
        if (shop == null) {
          throw const ServerFailure(message: "Do'kon topilmadi");
        }
        return ShopSettings.fromRow(
          shopRow: shop,
          sellerRow: results[1],
        );
      });

  @override
  Future<Result<ShopSettings>> save(ShopSettings settings) =>
      runCatching(() async {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) {
          throw const AuthFailure(message: 'Tizimga kirish talab qilinadi');
        }

        // Two updates in parallel — shops and sellers don't share a
        // primary key so we can't bundle them into one upsert.
        final shopFuture = _client
            .from(_shopsTable)
            .update(settings.toShopJson())
            .eq('id', settings.id)
            .select()
            .single();
        final sellerFuture = _client
            .from(_sellersTable)
            .update(settings.toSellerContactJson())
            .eq('id', userId)
            .select('contact_phone, contact_email, telegram_username')
            .maybeSingle();

        final results = await Future.wait<Map<String, dynamic>?>([
          shopFuture,
          sellerFuture,
        ]);
        return ShopSettings.fromRow(
          shopRow: results[0]!,
          sellerRow: results[1],
        );
      });

  @override
  Future<Result<String>> uploadAsset({
    required String kind,
    required File file,
    required String fileExtension,
  }) =>
      runCatching(() async {
        final shopId = await _requireShopId();
        final path =
            '$shopId/$kind-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        await _client.storage.from(_assetBucket).upload(
              path,
              file,
              fileOptions: const FileOptions(upsert: true),
            );
        return _client.storage.from(_assetBucket).getPublicUrl(path);
      });

  Future<String> _requireShopId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailure(message: 'Tizimga kirish talab qilinadi');
    }
    final row = await _client
        .from(_shopsTable)
        .select('id')
        .eq('seller_id', userId)
        .maybeSingle();
    final shopId = row?['id'] as String?;
    if (shopId == null) {
      throw const ServerFailure(message: "Do'kon topilmadi");
    }
    return shopId;
  }
}
