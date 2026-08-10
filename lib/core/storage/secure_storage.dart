import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Wrapper around `flutter_secure_storage` for tokens we cannot leave in Hive.
/// The auth token store persists the session; this is for any extra data
/// we may need (e.g. stored refresh hints).
class SecureStorage {
  SecureStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> clear() => _storage.deleteAll();
}

/// Hive (`settings` box) key marking that the fresh-install Keychain wipe
/// below has already run on this install.
const String _kSecureStorageResetGuardKey =
    'secure_storage_reset_after_install_v1';

/// Unlike Hive/SharedPreferences (app-sandbox files), the iOS Keychain and
/// Android EncryptedSharedPreferences survive app deletion by design — so
/// deleting and reinstalling the app silently resumes the previous session
/// (`TokenStore`'s access/refresh pair) instead of landing on a signed-out
/// state. That's a real session leak if the device is later handed to
/// someone else. [settingsBox] is a Hive box, which *is* wiped on uninstall,
/// so its absence is a reliable fresh-install signal — same trick
/// `DeferredDeepLinkService` uses via SharedPreferences.
///
/// Must run before anything reads `TokenStore` or `SecureStorage` (call at
/// the top of `registerCoreModule`, right after the settings box opens).
Future<void> resetSecureStorageOnFreshInstall(Box settingsBox) async {
  if (settingsBox.get(_kSecureStorageResetGuardKey) == true) return;
  await const FlutterSecureStorage().deleteAll();
  await settingsBox.put(_kSecureStorageResetGuardKey, true);
}
