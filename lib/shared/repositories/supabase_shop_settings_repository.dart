import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/failure.dart';
import '../../core/logging/talker.dart';
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
        final ext = fileExtension.toLowerCase();
        final path =
            '$shopId/$kind-${DateTime.now().millisecondsSinceEpoch}.$ext';
        final bytes = await file.readAsBytes();
        talker.info(
          '[shop-settings] uploadAsset start kind=$kind '
          'bucket=$_assetBucket path=$path bytes=${bytes.length}',
        );
        try {
          // `uploadBinary` with an explicit content type — the same call the
          // working product-image upload uses. `upload(File)` was failing
          // here with a storage HTTP 400.
          await _client.storage.from(_assetBucket).uploadBinary(
                path,
                bytes,
                fileOptions: FileOptions(
                  contentType: _contentTypeFor(ext),
                  upsert: true,
                ),
              );
        } on StorageException catch (e, st) {
          talker.handle(
            e,
            st,
            '[shop-settings] uploadAsset storage error kind=$kind '
            'statusCode=${e.statusCode} error=${e.error} message=${e.message}',
          );
          rethrow;
        } catch (e, st) {
          talker.handle(e, st, '[shop-settings] uploadAsset failed kind=$kind');
          rethrow;
        }
        final url = _client.storage.from(_assetBucket).getPublicUrl(path);
        talker.info('[shop-settings] uploadAsset ok kind=$kind url=$url');
        return url;
      });

  /// Maps a lower-cased image extension to the MIME type Storage expects.
  String _contentTypeFor(String ext) => switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

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
