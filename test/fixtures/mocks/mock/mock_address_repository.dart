import '../models/address.dart';
import '../repositories/address_repository.dart';
import 'mock_orders_data.dart';

class MockAddressRepository implements AddressRepository {
  static const _delay = Duration(milliseconds: 220);

  final List<Address> _addresses =
      List<Address>.from(MockOrdersData.addresses);
  int _idCounter = 100;

  @override
  Future<List<Address>> list() async {
    await Future<void>.delayed(_delay);
    return List.unmodifiable(_addresses);
  }

  @override
  Future<Address> create(Address address) async {
    await Future<void>.delayed(_delay);
    _idCounter += 1;
    final created = address.copyWith(id: 'addr-mock-$_idCounter');
    if (created.isDefault) {
      _clearOtherDefaults(created.id);
    }
    if (_addresses.isEmpty) {
      _addresses.add(created.copyWith(isDefault: true));
    } else {
      _addresses.add(created);
    }
    return _addresses.last;
  }

  @override
  Future<Address> update(Address address) async {
    await Future<void>.delayed(_delay);
    final idx = _addresses.indexWhere((a) => a.id == address.id);
    if (idx < 0) {
      throw StateError('Manzil topilmadi: ${address.id}');
    }
    if (address.isDefault) {
      _clearOtherDefaults(address.id);
    }
    _addresses[idx] = address;
    return address;
  }

  @override
  Future<void> delete(String id) async {
    await Future<void>.delayed(_delay);
    final removedDefault =
        _addresses.where((a) => a.id == id && a.isDefault).isNotEmpty;
    _addresses.removeWhere((a) => a.id == id);
    // Promote the first remaining address to default so the user always has
    // a sane "default" pick on checkout.
    if (removedDefault && _addresses.isNotEmpty) {
      _addresses[0] = _addresses[0].copyWith(isDefault: true);
    }
  }

  @override
  Future<void> setDefault(String id) async {
    await Future<void>.delayed(_delay);
    _clearOtherDefaults(id);
    final idx = _addresses.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      _addresses[idx] = _addresses[idx].copyWith(isDefault: true);
    }
  }

  void _clearOtherDefaults(String exceptId) {
    for (var i = 0; i < _addresses.length; i++) {
      if (_addresses[i].id != exceptId && _addresses[i].isDefault) {
        _addresses[i] = _addresses[i].copyWith(isDefault: false);
      }
    }
  }
}
