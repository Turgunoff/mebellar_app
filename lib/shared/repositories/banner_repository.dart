import 'package:dio/dio.dart';

import '../models/banner.dart';

abstract class BannerRepository {
  Future<List<HomeBanner>> list();
}

class RemoteBannerRepository implements BannerRepository {
  RemoteBannerRepository(this._dio);

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
