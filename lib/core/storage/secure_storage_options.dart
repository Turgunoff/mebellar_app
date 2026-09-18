import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The single `FlutterSecureStorage` configuration every call site uses.
///
/// `migrateWithBackup` matters exactly once: on the update that first ships
/// flutter_secure_storage 10, the plugin re-encrypts every entry written by
/// v9 (RSA_ECB_PKCS1Padding / AES_CBC_PKCS7Padding → OAEP / AES_GCM) the first
/// time it is read. A crash partway through that rewrite loses the entry, and
/// the entries here are the access/refresh token pair — losing them signs the
/// user out. The backup makes the migration resumable.
///
/// Do NOT jump this dependency straight to v11: v11 removed the legacy ciphers
/// outright, so v9 data would be unreadable and `resetOnError` would wipe it.
/// One shipped release on v10 is what migrates it.
const FlutterSecureStorage woodySecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(migrateWithBackup: true),
);
