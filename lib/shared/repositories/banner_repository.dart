import 'package:dio/dio.dart';

import '../models/banner.dart';

abstract class BannerRepository {
  Future<List<HomeBanner>> list();

  /// Synchronous read of any cached snapshot. Returns `null` on a cache miss
  /// or for non-caching implementations. Blocs use this to hydrate state on
  /// cold start before the network call lands.
  List<HomeBanner>? peek() => null;
}

class RemoteBannerRepository extends BannerRepository {
  RemoteBannerRepository(Dio dio) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<HomeBanner>> list() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/banners');
    final data = response.data?['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(HomeBanner.fromJson)
        .toList(growable: false);
  }
}
