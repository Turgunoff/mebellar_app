import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/failure.dart';
import '../../core/logging/talker.dart';
import '../../core/result/result.dart';
import '../models/verification_document.dart';
import '../models/verification_status.dart';
import 'seller_verification_repository.dart';

/// Live Supabase implementation of [SellerVerificationRepository] (B.1).
///
/// KYC documents are sensitive — they go to the **private** `verification-docs`
/// storage bucket, never a public bucket. The applied RLS storage policy
/// (`docs/supabase_rls_policies.sql.md`) keys on `auth.uid()` as the first
/// path segment, so the scoped object path is `<seller_uid>/<type>.<ext>`
/// — NOT `<shop_id>/...`, which would fail the RLS check. The persisted
/// reference is the *object path*, not a public URL; the UI fetches a
/// short-lived signed URL on demand.
class SupabaseSellerVerificationRepository
    implements SellerVerificationRepository {
  SupabaseSellerVerificationRepository({required SupabaseClient supabase})
      : _client = supabase {
    unawaited(_loadDocuments());
    unawaited(_loadStatus());
  }

  final SupabaseClient _client;

  static const String _bucket = 'verification-docs';
  static const String _docsTable = 'verification_documents';
  static const String _statusTable = 'seller_verifications';

  List<VerificationDocument> _cache = const [];
  // Broadcast feeds for the bloc. App-lifetime singletons — no dispose needed.
  final StreamController<List<VerificationDocument>> _docsController =
      StreamController<List<VerificationDocument>>.broadcast();
  final StreamController<VerificationStatus> _statusController =
      StreamController<VerificationStatus>.broadcast();

  @override
  List<VerificationDocument> get documents => _cache;

  @override
  Stream<List<VerificationDocument>> watchDocuments() =>
      _docsController.stream;

  @override
  Stream<VerificationStatus> watchStatus() => _statusController.stream;

  @override
  Future<Result<VerificationDocument>> uploadDocument({
    required VerificationDocumentType type,
    required File file,
    required String fileExtension,
  }) =>
      runCatching(() async {
        final userId = _requireUserId();
        final path = '$userId/${type.code}.$fileExtension';
        await _client.storage.from(_bucket).upload(
              path,
              file,
              // Re-uploading a document type overwrites the previous file.
              fileOptions: const FileOptions(upsert: true),
            );
        await _client.from(_docsTable).upsert(
          {
            'seller_id': userId,
            'document_type': type.code,
            'storage_path': path,
          },
          onConflict: 'seller_id,document_type',
        );
        final doc = VerificationDocument(
          type: type,
          localPath: file.path,
          remoteUrl: path,
        );
        _upsertCacheDoc(doc);
        return doc;
      });

  @override
  Future<Result<void>> removeDocument(VerificationDocumentType type) =>
      runCatching(() async {
        final userId = _requireUserId();
        await _client
            .from(_docsTable)
            .delete()
            .eq('seller_id', userId)
            .eq('document_type', type.code);
        // Best-effort storage cleanup using the cached object path.
        final path = _docFor(type)?.remoteUrl;
        if (path != null) {
          await _client.storage.from(_bucket).remove([path]);
        }
        _cache = [
          for (final d in _cache)
            if (d.type != type) d,
        ];
        _emitDocs();
      });

  @override
  Future<Result<VerificationStatus>> submit() => runCatching(() async {
        final userId = _requireUserId();
        await _client.from(_statusTable).upsert(
          {
            'seller_id': userId,
            'status': VerificationStatus.pending.code,
          },
          onConflict: 'seller_id',
        );
        if (!_statusController.isClosed) {
          _statusController.add(VerificationStatus.pending);
        }
        return VerificationStatus.pending;
      });

  // ─── Internals ──────────────────────────────────────────────────────────

  Future<void> _loadDocuments() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      final rows = await _client
          .from(_docsTable)
          .select()
          .eq('seller_id', userId);
      _cache = rows.map(VerificationDocument.fromJson).toList(growable: false);
      _emitDocs();
    } catch (e, st) {
      talker.handle(e, st, 'SupabaseSellerVerificationRepository._loadDocuments');
    }
  }

  Future<void> _loadStatus() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      final row = await _client
          .from(_statusTable)
          .select('status')
          .eq('seller_id', userId)
          .maybeSingle();
      if (!_statusController.isClosed) {
        _statusController
            .add(VerificationStatus.fromCode(row?['status'] as String?));
      }
    } catch (e, st) {
      talker.handle(e, st, 'SupabaseSellerVerificationRepository._loadStatus');
    }
  }

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailure(message: 'Tizimga kirish talab qilinadi');
    }
    return userId;
  }

  VerificationDocument? _docFor(VerificationDocumentType type) {
    for (final doc in _cache) {
      if (doc.type == type) return doc;
    }
    return null;
  }

  void _upsertCacheDoc(VerificationDocument doc) {
    _cache = [
      for (final d in _cache)
        if (d.type != doc.type) d,
      doc,
    ];
    _emitDocs();
  }

  void _emitDocs() {
    if (!_docsController.isClosed) _docsController.add(_cache);
  }
}
