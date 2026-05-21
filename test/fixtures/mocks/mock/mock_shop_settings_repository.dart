import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';

import '../../core/result/result.dart';
import '../models/shop_settings.dart';
import '../repositories/shop_settings_repository.dart';
import 'mock_shop_settings.dart';

class MockShopSettingsRepository implements ShopSettingsRepository {
  MockShopSettingsRepository() : _current = MockShopSettings.defaultSettings();

  static const _delay = Duration(milliseconds: 250);
  static const _uploadDelay = Duration(milliseconds: 600);

  ShopSettings _current;
  final _controller = StreamController<ShopSettings>.broadcast();

  @override
  Stream<ShopSettings> watch() => _controller.stream;

  @override
  Future<Result<ShopSettings>> get() async {
    await Future<void>.delayed(_delay);
    return Ok(_current);
  }

  @override
  Future<Result<ShopSettings>> save(ShopSettings settings) async {
    await Future<void>.delayed(_delay);
    _current = settings;
    _controller.add(_current);
    return Ok(_current);
  }

  @override
  Future<Result<String>> uploadAsset({
    required String kind,
    required File file,
    required String fileExtension,
  }) async {
    await Future<void>.delayed(_uploadDelay);
    // Pretend the asset is hosted on Supabase Storage.
    return Ok(
      'shops/${_current.id}/$kind-'
      '${clock.now().millisecondsSinceEpoch}.$fileExtension',
    );
  }
}
