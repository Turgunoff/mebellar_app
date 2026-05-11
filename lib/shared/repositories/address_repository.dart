import 'package:dio/dio.dart';

import '../models/address.dart';

abstract class AddressRepository {
  Future<List<Address>> list();
  Future<Address> create(Address address);
  Future<Address> update(Address address);
  Future<void> delete(String id);
  Future<void> setDefault(String id);
}

class RemoteAddressRepository implements AddressRepository {
  RemoteAddressRepository(this._dio);
  final Dio _dio;

  @override
  Future<List<Address>> list() async {
    await _dio.get<Map<String, dynamic>>('/api/v1/addresses');
    // V1: server emits region/city ids; UI stitches from RegionRepository.
    throw UnimplementedError('Remote address parsing — Sprint 5 backend');
  }

  @override
  Future<Address> create(Address address) async {
    throw UnimplementedError('Remote address create — Sprint 5 backend');
  }

  @override
  Future<Address> update(Address address) async {
    throw UnimplementedError('Remote address update — Sprint 5 backend');
  }

  @override
  Future<void> delete(String id) async {
    await _dio.delete<dynamic>('/api/v1/addresses/$id');
  }

  @override
  Future<void> setDefault(String id) async {
    await _dio.post<dynamic>('/api/v1/addresses/$id/default');
  }
}
