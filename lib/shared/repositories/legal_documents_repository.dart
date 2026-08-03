import '../models/legal_document.dart';

abstract class LegalDocumentsRepository {
  /// Current seller public-offer (`GET /legal/oferta?lang=`). Throws on
  /// transport failure; callers should fall back to the embedded template.
  Future<LegalDocument> fetchSellerOferta({String lang = 'uz'});
}
