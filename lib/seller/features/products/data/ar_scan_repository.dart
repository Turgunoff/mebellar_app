import '../../../../core/network/woody_api_client.dart';
import '../../../../shared/models/ar_part.dart';

/// Data layer for the seller "Request a 3D model" flow. Abstract interface so
/// the AR section depends on the contract, not the REST impl, and tests mock it.
///
/// The workflow pivoted: a seller no longer captures photos or triggers Meshy.
/// They only REQUEST a model for a part (the part lands `pending`); an admin
/// reviews the request, picks the best product photos, and sends them to Meshy.
/// This repo therefore just kicks the request off and reads/toggles part state.
abstract class ArScanRepository {
  /// Requests a per-part 3D model. [partKey] identifies which component
  /// ('single' for a one-piece product) and [label] is its display name; the
  /// backend upserts the part, applies the free-then-token rule (the first
  /// request is free, a re-request locks 1 token), and lands it `pending`.
  /// Returns the product's full updated AR part list.
  Future<List<ArPart>> requestArModel({
    required String productId,
    required String partKey,
    required String label,
    required int heightCm,
    required int widthCm,
    required int lengthCm,
  });

  /// The product's existing AR parts (model state, visibility, free-scan spent).
  Future<List<ArPart>> fetchArParts(String productId);

  /// Toggle whether a part's model is shown to buyers (the eye icon).
  Future<void> setPartVisibility({
    required String productId,
    required String partId,
    required bool isVisible,
  });
}

class WoodyArScanRepository implements ArScanRepository {
  WoodyArScanRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<List<ArPart>> requestArModel({
    required String productId,
    required String partKey,
    required String label,
    required int heightCm,
    required int widthCm,
    required int lengthCm,
  }) async {
    final res = await _api.post<List<dynamic>>(
      '/seller/products/$productId/ar-request',
      body: {
        'part_key': partKey,
        'label': label,
        'height_cm': heightCm,
        'width_cm': widthCm,
        'length_cm': lengthCm,
      },
    );
    return res
        .whereType<Map<String, dynamic>>()
        .map(ArPart.fromSellerJson)
        .toList(growable: false);
  }

  @override
  Future<List<ArPart>> fetchArParts(String productId) async {
    final res = await _api.get<List<dynamic>>(
      '/seller/products/$productId/ar-parts',
    );
    return res
        .whereType<Map<String, dynamic>>()
        .map(ArPart.fromSellerJson)
        .toList(growable: false);
  }

  @override
  Future<void> setPartVisibility({
    required String productId,
    required String partId,
    required bool isVisible,
  }) async {
    await _api.patch<void>(
      '/seller/products/$productId/parts/$partId/visibility',
      body: {'is_ar_visible': isVisible},
    );
  }
}
