# 13 — Security (Mobile)

> Asl §11 mobile parts. Backend qism: `backend/docs/11-security.md`.

## 1. Token storage

Supabase SDK avtomatik:

- access token + refresh token `flutter_secure_storage`'da
- iOS: Keychain
- Android: EncryptedSharedPreferences

> **Token'ni qo'lda Hive'ga yozmang** — Hive cache encrypted emas, leak risk.

```dart
// flutter_secure_storage Supabase SDK ichida default
// Qo'shimcha sezgir ma'lumotlar uchun:
final secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
);
```

## 2. Bearer token interceptor

```dart
// Faqat backend'ga so'rovlarda — Supabase SDK o'zining auth'ini bilim ishlatadi
Dio buildDioClient() {
  final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && !session.isExpired) {
        options.headers['Authorization'] = 'Bearer ${session.accessToken}';
      } else if (session?.isExpired == true) {
        // Refresh urinish (SDK avtomatik qiladi, lekin ishonch uchun)
        await Supabase.instance.client.auth.refreshSession();
      }
      return handler.next(options);
    },
    onError: (err, handler) async {
      if (err.response?.statusCode == 401) {
        await Supabase.instance.client.auth.signOut();
        // Login screen'ga redirect
      }
      return handler.next(err);
    },
  ));
  return dio;
}
```

## 3. Network security

### iOS App Transport Security

```xml
<!-- ios/Runner/Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <false/>
</dict>
```

### Android Network Security Config

```xml
<!-- android/app/src/main/res/xml/network_security_config.xml -->
<network-security-config>
  <base-config cleartextTrafficPermitted="false">
    <trust-anchors>
      <certificates src="system" />
    </trust-anchors>
  </base-config>
</network-security-config>
```

`AndroidManifest.xml`:

```xml
<application
    android:networkSecurityConfig="@xml/network_security_config"
    ...>
```

## 4. Deep link xavfsizlik

Pending route pattern (05-notifications-deep-linking.md) ichida:

- **Logged out user'da pending route consume qilinmaydi** — agar boshqa user notification olib qoldirgan bo'lsa, navigate qilmaslik
- **Stale check 5 daqiqa** — eski route e'tiborga olinmasin
- **Defensive check** — agar mode mos kelmasa, redirect

## 5. Sensitive ma'lumotlar log'larda

```dart
// Sentry / structured logger filter
final logger = Logger(filter: ProductionFilter());

// dio interceptor — log'ga JWT yozmang
dio.interceptors.add(LogInterceptor(
  requestHeader: false,
  requestBody: true,
  responseBody: true,
  // Authorization header log'ga tushmaydi
));
```

Sentry ham JWT'ni request data'dan tozalash kerak — `beforeSend` callback.

## 6. Image picker permissions

```yaml
# ios/Runner/Info.plist
<key>NSPhotoLibraryUsageDescription</key>
<string>Mahsulot rasmlarini tanlash uchun</string>
<key>NSCameraUsageDescription</key>
<string>Passport va selfie rasmlari uchun</string>
```

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>  <!-- Android 13+ -->
```

## 7. Push notification permissions

OneSignal SDK avtomatik so'raydi. iOS'da explicit `requestPermission`:

```dart
await OneSignal.Notifications.requestPermission(true);
```

## 8. Root detection (V2 optional)

V1'da yo'q — yuqori xavfsizlik talab qilingan financial app emas. V2'da `flutter_jailbreak_detection` qo'shish mumkin.

## 9. Code obfuscation

Production build'da:

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols/
flutter build ipa --release --obfuscate --split-debug-info=build/symbols/
```

Symbol'lar Sentry'ga upload qilinadi (stack trace deobfuscation uchun).

## 10. Secrets va API keys

```
NEVER commit:
  - SUPABASE_SERVICE_KEY (backend only)
  - PRIVATE_KEY any
  - PRODUCTION JWT secret

OK to ship in app:
  - SUPABASE_URL
  - SUPABASE_ANON_KEY (public, safe)
  - ONESIGNAL_APP_ID
```

```dart
// lib/core/config/app_config.dart
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const oneSignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID');
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://api.mebellar.uz/api/v1');
}
```

Build:

```bash
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

Yoki `--dart-define-from-file=env/dev.json`.

## 11. Account deletion

`DELETE /api/v1/me` (soft delete, 90 kun grace period). UI'da:

```
"Akountni o'chirish" tap →
  Confirm dialog: "Hamma ma'lumotlaringiz 90 kun ichida o'chiriladi.
                   Bu vaqt ichida login bo'lib qaytarib olishingiz mumkin."
  → API call → logout → login screen
```

App Store / Play Store **majburiy** talab — shu yerda implementatsiya majburiy.

## 12. Privacy policy / ToS link

App ichida link (Profile → "Sirlilik siyosati" / "Foydalanish shartlari") — `https://mebellar.uz/privacy` va `https://mebellar.uz/terms`. App Store metadata'da ham ushbu link'lar.

## 13. SSL pinning (V2 optional)

V1'da yo'q — Supabase va backend production HTTPS bilan ishlaydi, certificate authority chain ga ishonish OK. SSL pinning V2'da Click/Payme integratsiya bo'lganda qo'shiladi.

## 14. Test

```dart
test('logout clears local cache', () async {
  await GetIt.I<Box>(instanceName: 'cache').put('user_data', {...});

  await authRepository.signOut();

  expect(GetIt.I<Box>(instanceName: 'cache').get('user_data'), isNull);
});
```

## 15. Keyingi qadam

→ [14-roadmap-phases.md](./14-roadmap-phases.md) — bosqichma-bosqich implementatsiya
