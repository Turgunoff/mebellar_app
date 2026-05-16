import 'package:geolocator/geolocator.dart';

/// Testable seam over `geolocator`'s static API (ROADMAP B.5).
///
/// `geolocator` exposes everything through `static` methods, so feature code
/// that calls `Geolocator.getCurrentPosition()` directly cannot be unit-tested
/// without a real platform channel. Depending on this interface instead lets a
/// test inject a fake. The value types ([LocationPermission], [Position],
/// [LocationSettings]) are plain data and re-used unchanged — only the
/// channel-backed calls are wrapped.
abstract class LocationFacade {
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> getCurrentPosition({LocationSettings? locationSettings});
}

/// Production implementation — delegates to the `geolocator` plugin.
class GeolocatorLocationFacade implements LocationFacade {
  const GeolocatorLocationFacade();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      Geolocator.getCurrentPosition(locationSettings: locationSettings);
}
