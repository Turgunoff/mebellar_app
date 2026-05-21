import 'dart:async';

import 'package:woody_app/shared/models/business_type.dart';
import 'package:woody_app/shared/models/me.dart';
import 'package:woody_app/shared/models/onboarding_draft.dart';
import 'package:woody_app/shared/models/verification_document.dart';
import 'package:woody_app/shared/models/verification_status.dart';

/// Singleton that holds the mocked seller-side state across the app lifetime
/// (until process restart). Acts as the in-memory database for the
/// `MockSellerOnboardingRepository` and `MockSellerVerificationRepository`,
/// and is read by the mock `AuthRepository.fetchMe()` so seller-mode boots
/// see the latest verification status without a real backend.
class MockSellerState {
  MockSellerState._();
  static final MockSellerState instance = MockSellerState._();

  final _profileController = StreamController<SellerProfile?>.broadcast();
  final _docsController =
      StreamController<List<VerificationDocument>>.broadcast();

  SellerProfile? _profile;
  String? _shopId;
  final List<VerificationDocument> _documents = [];

  SellerProfile? get profile => _profile;
  String? get shopId => _shopId;
  List<VerificationDocument> get documents =>
      List<VerificationDocument>.unmodifiable(_documents);

  Stream<SellerProfile?> get profileStream => _profileController.stream;
  Stream<List<VerificationDocument>> get documentsStream =>
      _docsController.stream;

  /// Persist the wizard output as the new pending profile. Idempotent — if
  /// the user redoes onboarding (e.g. rejected), values overwrite cleanly.
  void recordOnboarding({
    required OnboardingDraft draft,
    required VerificationStatus initialStatus,
  }) {
    _shopId ??= 'shop-mock-${DateTime.now().millisecondsSinceEpoch}';
    _profile = SellerProfile(
      verificationStatus: initialStatus,
      businessType: draft.businessType,
      legalName: draft.legalName,
      contactPhone: draft.contactPhone,
      contactEmail: draft.contactEmail,
      telegramUsername: draft.telegramUsername,
      shopId: _shopId,
    );
    _profileController.add(_profile);
  }

  void setStatus(VerificationStatus status, {String? rejectionReason}) {
    final p = _profile;
    if (p == null) return;
    _profile = p.copyWith(
      verificationStatus: status,
      rejectionReason: rejectionReason,
      clearRejectionReason: rejectionReason == null,
    );
    _profileController.add(_profile);
  }

  void upsertDocument(VerificationDocument doc) {
    final idx = _documents.indexWhere((d) => d.type == doc.type);
    if (idx >= 0) {
      _documents[idx] = doc;
    } else {
      _documents.add(doc);
    }
    _docsController.add(documents);
  }

  void removeDocument(VerificationDocumentType type) {
    _documents.removeWhere((d) => d.type == type);
    _docsController.add(documents);
  }

  /// Test-only — wipe everything so individual tests don't leak state.
  void resetForTests() {
    _profile = null;
    _shopId = null;
    _documents.clear();
  }

  /// Convenience: a pre-approved profile so demos can preview the seller
  /// dashboard without going through onboarding. Not invoked by default —
  /// only call this from a debug entry point.
  void seedApprovedDemoProfile() {
    _shopId = 'shop-mock-demo';
    _profile = const SellerProfile(
      verificationStatus: VerificationStatus.approved,
      businessType: BusinessType.individual,
      legalName: 'Demo Seller',
      shopId: 'shop-mock-demo',
    );
    _profileController.add(_profile);
  }
}
