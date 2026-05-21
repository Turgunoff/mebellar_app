import '../models/region.dart';
import '../repositories/region_repository.dart';
import 'mock_regions.dart';

class MockRegionRepository implements RegionRepository {
  @override
  Future<List<Region>> tree() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return MockRegions.tree;
  }
}
