import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/failure.dart';
import '../../core/result/result.dart';
import '../models/shop_settings.dart';
import 'shop_settings_repository.dart';

/// Live Supabase implementation of [ShopSettingsRepository] (ROADMAP B.1).
///
/// Schema — `public.shops` (see `docs/supabase_rls_policies.sql.md`). The
/// seller-editable view stores `name`, `description`, `region`, `city`,
/// `district` and `working_hours` as embedded `jsonb`, so a settings load is
/// a single row read with no joins. Logo/cover assets live in the public
/// `shop-assets` storage bucket under `<shop_id>/...`.
class SupabaseShopSettingsRepository implements ShopSettingsRepository {
  SupabaseShopSettingsRepository({required SupabaseClient supabase})
      : _client = supabase;

  final SupabaseClient _client;

  static const String _table = 'shops';
  static const String _assetBucket = 'shop-assets';

  /// Shop settings rarely change out-of-band; the seller form is the single
  /// writer, so an empty stream is correct here (no realtime fan-in needed).
  @override
  Stream<ShopSettings> watch() => const Stream.empty();

  @override
  Future<Result<ShopSettings>> get() => runCatching(() async {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) {
          throw const AuthFailure(message: 'Tizimga kirish talab qilinadi');
        }
        final row = await _client
            .from(_table)
            .select()
            .eq('seller_id', userId)
            .maybeSingle();
        if (row == null) {
          throw const ServerFailure(message: "Do'kon topilmadi");
        }
        return ShopSettings.fromJson(row);
      });

  @override
  Future<Result<ShopSettings>> save(ShopSettings settings) =>
      runCatching(() async {
        final row = await _client
            .from(_table)
            .update(settings.toJson())
            .eq('id', settings.id)
            .select()
            .single();
        return ShopSettings.fromJson(row);
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
        .from(_table)
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
