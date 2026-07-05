/// Approximate bounding box for Uzbekistan — used to reject checkout addresses
/// picked far outside the service area.
abstract final class UzbekistanBounds {
  static const double minLatitude = 37.0;
  static const double maxLatitude = 45.7;
  static const double minLongitude = 56.0;
  static const double maxLongitude = 73.5;

  static bool contains({required double latitude, required double longitude}) {
    return latitude >= minLatitude &&
        latitude <= maxLatitude &&
        longitude >= minLongitude &&
        longitude <= maxLongitude;
  }
}
