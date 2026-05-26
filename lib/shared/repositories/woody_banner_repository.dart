import '../../core/network/woody_api_client.dart';
import '../models/banner.dart';
import 'banner_repository.dart';

/// Replaces `SupabaseBannerRepository`. Calls `/catalog/banners` which
/// returns the flat banner rows (`title`/`subtitle` as single-language
/// strings) — `HomeBanner.fromSupabaseJson` broadcasts those to all locales.
class WoodyBannerRepository extends BannerRepository {
  WoodyBannerRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<List<HomeBanner>> list() async {
    final rows = await _api.get<List<dynamic>>('/catalog/banners');
    return rows
        .whereType<Map<String, dynamic>>()
        .map(HomeBanner.fromSupabaseJson)
        .toList(growable: false);
  }
}
