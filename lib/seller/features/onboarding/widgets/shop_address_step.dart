import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:woody_app/config/app_config.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/maps/yandex_mapkit_initializer.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../../../customer/features/home/widgets/premium/premium_tokens.dart';
import '../bloc/onboarding_bloc.dart';

const _kDefaultCenter = Point(latitude: 41.2995, longitude: 69.2401);
const _kDefaultZoom = 13.0;
const _kPickZoom = 15.0;

class ShopAddressStep extends StatefulWidget {
  const ShopAddressStep({super.key});

  @override
  State<ShopAddressStep> createState() => _ShopAddressStepState();
}

class _ShopAddressStepState extends State<ShopAddressStep> {
  YandexMapController? _mapController;
  late CameraPosition _initialCameraPosition;
  String? _geocodedAddress;
  late final TextEditingController _landmark;
  bool _isGeocoding = false;
  Timer? _geocodeDebounce;
  int _latestGeocodeRequestId = 0;
  late final Future<void> _mapKitReady;

  @override
  void initState() {
    super.initState();
    final draft = context.read<OnboardingBloc>().state.draft;
    _initialCameraPosition = (draft.shopLat != null && draft.shopLng != null)
        ? CameraPosition(
            target: Point(latitude: draft.shopLat!, longitude: draft.shopLng!),
            zoom: _kPickZoom,
          )
        : const CameraPosition(target: _kDefaultCenter, zoom: _kDefaultZoom);
    _geocodedAddress = draft.shopStreetLine;
    _landmark = TextEditingController(text: draft.shopLandmark ?? '');
    // Stored as a field so rebuilds reuse the same Future and the
    // FutureBuilder doesn't flicker back to the loading state.
    _mapKitReady = YandexMapKitInitializer.ensureInitialized();
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _landmark.dispose();
    super.dispose();
  }

  void _onMapCreated(YandexMapController controller) {
    _mapController = controller;
    controller.moveCamera(
      CameraUpdate.newCameraPosition(_initialCameraPosition),
    );
    if (_geocodedAddress == null) {
      _reverseGeocode(_initialCameraPosition.target);
    }
  }

  void _onCameraPositionChanged(
    CameraPosition position,
    CameraUpdateReason reason,
    bool finished,
  ) {
    if (!finished) return;
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 600), () {
      _reverseGeocode(position.target);
    });
  }

  Future<void> _reverseGeocode(Point point) async {
    if (!mounted) return;
    final requestId = ++_latestGeocodeRequestId;
    setState(() => _isGeocoding = true);

    final address =
        await _reverseGeocodeViaYandex(point) ??
        await _reverseGeocodeViaNominatim(point);

    if (!mounted || requestId != _latestGeocodeRequestId) return;
    setState(() {
      _geocodedAddress = address;
      _isGeocoding = false;
    });

    context.read<OnboardingBloc>().add(
      OnboardingShopInfoChanged(
        lat: point.latitude,
        lng: point.longitude,
        streetLine: address,
        landmark: _landmark.text,
      ),
    );
  }

  Future<String?> _reverseGeocodeViaYandex(Point point) async {
    if (AppConfig.yandexGeocoderApiKey.isEmpty) return null;
    try {
      final uri = Uri.https('geocode-maps.yandex.ru', '/1.x', {
        'apikey': AppConfig.yandexGeocoderApiKey,
        'geocode': '${point.longitude},${point.latitude}',
        'format': 'json',
        'lang': 'uz_UZ',
        'results': '1',
        'kind': 'house',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      developer.log(
        'reverse-geocode-yandex: lat=${point.latitude}, lng=${point.longitude}, '
        'status=${response.statusCode}',
        name: 'shop_address',
      );
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;

      final responseNode = body['response'];
      if (responseNode is! Map<String, dynamic>) return null;
      final collection = responseNode['GeoObjectCollection'];
      if (collection is! Map<String, dynamic>) return null;
      final members = collection['featureMember'];
      if (members is! List || members.isEmpty) return null;
      final first = members.first;
      if (first is! Map<String, dynamic>) return null;
      final geoObject = first['GeoObject'];
      if (geoObject is! Map<String, dynamic>) return null;

      final meta = geoObject['metaDataProperty'];
      if (meta is Map<String, dynamic>) {
        final geocoderMeta = meta['GeocoderMetaData'];
        if (geocoderMeta is Map<String, dynamic>) {
          final text = geocoderMeta['text'];
          if (text is String && text.trim().isNotEmpty) return text;
        }
      }

      final name = geoObject['name'];
      if (name is String && name.trim().isNotEmpty) return name;
      return null;
    } catch (e, st) {
      developer.log(
        'reverse-geocode-yandex failed',
        name: 'shop_address',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Yandex MapKit "lite" pod doesn't include the Search SDK, so we hit the
  /// public Nominatim endpoint as a fallback.
  Future<String?> _reverseGeocodeViaNominatim(Point point) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'json',
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'accept-language': 'uz',
        'zoom': '18',
      });
      final response = await http
          .get(uri, headers: const {'User-Agent': 'WoodyApp/1.0'})
          .timeout(const Duration(seconds: 8));

      developer.log(
        'reverse-geocode: lat=${point.latitude}, lng=${point.longitude}, '
        'status=${response.statusCode}',
        name: 'shop_address',
      );
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;
      final display = body['display_name'];
      return display is String && display.trim().isNotEmpty ? display : null;
    } catch (e, st) {
      developer.log(
        'reverse-geocode failed',
        name: 'shop_address',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<void> _goToMyLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return;
    }
    if (!mounted) return;

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      await _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: Point(latitude: pos.latitude, longitude: pos.longitude),
            zoom: _kPickZoom,
          ),
        ),
        animation: const MapAnimation(
          type: MapAnimationType.smooth,
          duration: 0.4,
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('onboarding.step_address_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            tr('onboarding.step_address_subtitle'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _MapCard(
              isGeocoding: _isGeocoding,
              mapKitReady: _mapKitReady,
              onMapCreated: _onMapCreated,
              onCameraPositionChanged: _onCameraPositionChanged,
              onMyLocation: _goToMyLocation,
            ),
          ),
          const SizedBox(height: 12),
          _AddressField(address: _geocodedAddress, isLoading: _isGeocoding),
          const SizedBox(height: 12),
          TextFormField(
            controller: _landmark,
            decoration: const InputDecoration(
              labelText: 'Mo\'ljal yoki ofis raqami (ixtiyoriy)',
              hintText: 'Mo\'ljal yoki ofis raqami (ixtiyoriy)',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              context.read<OnboardingBloc>().add(
                OnboardingShopInfoChanged(landmark: value),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Map card — YandexMap with static center-pin overlay
// ---------------------------------------------------------------------------

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.isGeocoding,
    required this.mapKitReady,
    required this.onMapCreated,
    required this.onCameraPositionChanged,
    required this.onMyLocation,
  });

  final bool isGeocoding;
  final Future<void> mapKitReady;
  final void Function(YandexMapController) onMapCreated;
  final void Function(CameraPosition, CameraUpdateReason, bool)
  onCameraPositionChanged;
  final VoidCallback onMyLocation;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // YandexMap mounts a PlatformView that calls into MapKitFactory
            // straight away — if setApiKey hasn't run yet, the native side
            // throws. Gate the widget on the deferred initializer so the
            // map only attaches after MapKit is ready.
            FutureBuilder<void>(
              future: mapKitReady,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Container(
                    color: pt.surface,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PremiumTokens.accent,
                      ),
                    ),
                  );
                }
                return YandexMap(
                  onMapCreated: onMapCreated,
                  onCameraPositionChanged: onCameraPositionChanged,
                  mapObjects: const [],
                  zoomGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  fastTapEnabled: true,
                );
              },
            ),
            // Static pin — pointer-events ignored so map panning still works.
            IgnorePointer(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -18),
                  child: const Icon(
                    Icons.location_on,
                    size: 36,
                    color: PremiumTokens.accent,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Geocoding progress pill
            if (isGeocoding)
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: PremiumTokens.accent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Manzil aniqlanmoqda...',
                          style: PremiumTokens.body(size: 11, color: pt.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // My-location button
            Positioned(
              right: 12,
              bottom: 12,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.15),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onMyLocation,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.my_location,
                      size: 20,
                      color: PremiumTokens.accent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Geocoded address display
// ---------------------------------------------------------------------------

class _AddressField extends StatelessWidget {
  const _AddressField({required this.address, required this.isLoading});

  final String? address;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pt.divider),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 20,
            color: PremiumTokens.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              address ?? 'Xaritani suring, manzil avtomatik aniqlanadi',
              style: PremiumTokens.body(
                size: 13,
                color: address != null ? pt.dark : pt.grey,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isLoading) ...[
            const SizedBox(width: 10),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: PremiumTokens.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
