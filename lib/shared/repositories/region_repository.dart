import 'package:dio/dio.dart';

import '../models/region.dart';

abstract class RegionRepository {
  Future<List<Region>> tree();
}

class RemoteRegionRepository implements RegionRepository {
  RemoteRegionRepository(this._dio);
  final Dio _dio;

  @override
  Future<List<Region>> tree() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/v1/regions');
    final data = res.data?['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Region.fromJson)
        .toList();
  }
}
