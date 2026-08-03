import '../../core/network/woody_api_client.dart';
import '../models/legal_document.dart';
import 'legal_documents_repository.dart';

class WoodyLegalDocumentsRepository implements LegalDocumentsRepository {
  WoodyLegalDocumentsRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<LegalDocument> fetchSellerOferta({String lang = 'uz'}) async {
    final code = lang.trim().toLowerCase();
    final normalized = (code == 'ru' || code == 'en') ? code : 'uz';
    final raw = await _api.get<Map<String, dynamic>>(
      '/legal/oferta',
      query: {'lang': normalized},
      anonymous: true,
    );
    return LegalDocument.fromJson(raw);
  }
}
