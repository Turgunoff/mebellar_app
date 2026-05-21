import 'package:woody_app/shared/models/banner.dart';
import 'package:woody_app/shared/repositories/banner_repository.dart';
import 'mock_data.dart';

class MockBannerRepository implements BannerRepository {
  static const _delay = Duration(milliseconds: 150);

  @override
  Future<List<HomeBanner>> list() async {
    await Future<void>.delayed(_delay);
    return MockData.banners;
  }
}
