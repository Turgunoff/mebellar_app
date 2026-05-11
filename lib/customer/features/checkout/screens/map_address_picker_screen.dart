import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../../../config/app_config.dart';
import '../../../../core/maps/yandex_mapkit_initializer.dart';
import '../../home/widgets/premium/premium_tokens.dart';

const _kDefaultCenter = Point(latitude: 41.2995, longitude: 69.2401);
const _kDefaultZoom = 13.0;
const _kPickZoom = 16.0;

/// Full-screen map picker that returns the selected address string via
/// `Navigator.pop(context, address)`.
class MapAddressPickerScreen extends StatefulWidget {
  const MapAddressPickerScreen({super.key, this.initialAddress});

  final String? initialAddress;

  @override
  State<MapAddressPickerScreen> createState() => _MapAddressPickerScreenState();
}

class _MapAddressPickerScreenState extends State<MapAddressPickerScreen> {
  YandexMapController? _mapController;
  String? _geocodedAddress;
  bool _isGeocoding = false;
  Timer? _geocodeDebounce;
  int _latestGeocodeRequestId = 0;
  late final Future<void> _mapKitReady;

  @override
  void initState() {
    super.initState();
    _geocodedAddress = widget.initialAddress?.isEmpty == true
        ? null
        : widget.initialAddress;
    _mapKitReady = YandexMapKitInitializer.ensureInitialized();
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(YandexMapController controller) {
    _mapController = controller;
    controller.moveCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(target: _kDefaultCenter, zoom: _kDefaultZoom),
      ),
    );
    if (_geocodedAddress == null) {
      _reverseGeocode(_kDefaultCenter);
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

    final address = await _reverseGeocodeViaYandex(point) ??
        await _reverseGeocodeViaNominatim(point);

    if (!mounted || requestId != _latestGeocodeRequestId) return;
    setState(() {
      _geocodedAddress = address;
      _isGeocoding = false;
    });
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
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));

      developer.log(
        'map-picker reverse-geocode-yandex: lat=${point.latitude}, '
        'lng=${point.longitude}, status=${response.statusCode}',
        name: 'map_address_picker',
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
        'map-picker reverse-geocode-yandex failed',
        name: 'map_address_picker',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

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
        'map-picker reverse-geocode-nominatim: lat=${point.latitude}, '
        'lng=${point.longitude}, status=${response.statusCode}',
        name: 'map_address_picker',
      );
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;
      final display = body['display_name'];
      return display is String && display.trim().isNotEmpty ? display : null;
    } catch (e, st) {
      developer.log(
        'map-picker reverse-geocode-nominatim failed',
        name: 'map_address_picker',
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
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
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
    final pt = PremiumTokens.of(context);
    return Scaffold(
      backgroundColor: pt.background,
      body: Stack(
        children: [
          FutureBuilder<void>(
            future: _mapKitReady,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Container(
                  color: pt.surface,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: PremiumTokens.accent,
                    ),
                  ),
                );
              }
              return YandexMap(
                onMapCreated: _onMapCreated,
                onCameraPositionChanged: _onCameraPositionChanged,
                mapObjects: const [],
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                tiltGesturesEnabled: true,
                rotateGesturesEnabled: true,
                fastTapEnabled: true,
              );
            },
          ),

          // Static center pin (pointer-events ignored so map pan still works)
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: const Icon(
                  Icons.location_on,
                  size: 42,
                  color: PremiumTokens.accent,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Geocoding progress pill
          if (_isGeocoding)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 72,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.09),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: PremiumTokens.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Manzil aniqlanmoqda...',
                        style: PremiumTokens.body(size: 12, color: pt.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // App bar overlay (back button)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _GlassButton(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          'Yetkazib berish manzili',
                          style: PremiumTokens.body(
                            size: 14,
                            weight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // My-location FAB
          Positioned(
            right: 16,
            bottom: 180,
            child: _GlassButton(
              onTap: _goToMyLocation,
              child: const Icon(
                Icons.my_location,
                size: 22,
                color: PremiumTokens.accent,
              ),
            ),
          ),

          // Bottom address panel + confirm button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomPanel(
              address: _geocodedAddress,
              isGeocoding: _isGeocoding,
              onConfirm: () {
                final address = _geocodedAddress;
                if (address != null && address.trim().isNotEmpty) {
                  Navigator.of(context).pop(address.trim());
                }
              },
              pt: pt,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom panel
// ---------------------------------------------------------------------------

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.address,
    required this.isGeocoding,
    required this.onConfirm,
    required this.pt,
  });

  final String? address;
  final bool isGeocoding;
  final VoidCallback onConfirm;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    final hasAddress = address != null && address!.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, -4),
            blurRadius: 20,
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Iconsax.location,
                size: 16,
                color: PremiumTokens.accent,
              ),
              const SizedBox(width: 8),
              Text(
                'TANLANGAN MANZIL',
                style: PremiumTokens.body(
                  size: 11,
                  weight: FontWeight.w700,
                  color: pt.grey,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isGeocoding
                ? Row(
                    key: const ValueKey('loading'),
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: PremiumTokens.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Manzil aniqlanmoqda...',
                        style: PremiumTokens.body(size: 14, color: pt.grey),
                      ),
                    ],
                  )
                : Text(
                    key: ValueKey(address),
                    hasAddress
                        ? address!
                        : 'Xaritani suring, manzil avtomatik aniqlanadi',
                    style: PremiumTokens.body(
                      size: 14,
                      weight: FontWeight.w500,
                      color: hasAddress ? pt.dark : pt.grey,
                      height: 1.45,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: hasAddress && !isGeocoding ? onConfirm : null,
              style: FilledButton.styleFrom(
                backgroundColor: PremiumTokens.accent,
                disabledBackgroundColor:
                    PremiumTokens.accent.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Manzilni tasdiqlash',
                    style: PremiumTokens.body(
                      size: 15,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Iconsax.tick_circle,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Glass button helper
// ---------------------------------------------------------------------------

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: child),
        ),
      ),
    );
  }
}
