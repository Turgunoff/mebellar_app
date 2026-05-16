# 06 — Auth flow (Mobile angle)

> Asl §4.3, §19.1 mobile perspektivasidan.

## 1. Strategiya

Mobile **Supabase SDK** (`supabase_flutter`) orqali to'g'ridan-to'g'ri Supabase Auth bilan ishlaydi:

- signup, login, refresh, password reset, email verify — Supabase SDK
- Backend Python — faqat business logic (profile, products, orders)

Backend `Authorization: Bearer <jwt>` header bilan murojaat qabul qiladi. JWT'ni Supabase'ning JWKS endpoint orqali offline verify qiladi.

---

## 2. Profile yaratish — Postgres trigger orqali (NOT client sync)

> **Muhim:** mobile app'da `POST /api/v1/auth/sync` endpoint'i **YO'Q**. Profile DB trigger orqali atomik yaratiladi. Tafsilot: `backend/docs/02-auth-jwt.md`.

Mobile uchun bu shuni anglatadi: signup'dan keyin **darhol** `GET /api/v1/me` chaqirish mumkin — profile **albatta** mavjud bo'ladi.

---

## 3. Signup flow

```dart
// lib/auth/register_screen.dart
Future<void> _onRegister() async {
  try {
    final response = await Supabase.instance.client.auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      data: {
        'full_name': _fullNameController.text.trim(),
        'preferred_language': context.locale.languageCode,  // 'uz' | 'ru' | 'en'
      },
    );

    if (response.user == null) {
      throw 'Signup failed';
    }

    // Email verification screen ko'rsatish
    Navigator.pushReplacementNamed(context, '/verify-email',
      arguments: response.user!.email);
  } on AuthException catch (e) {
    _showError(e.message);
  }
}
```

Backend tomonida (avtomatik):

```sql
-- handle_new_user trigger:
-- 1) auth.users INSERT
-- 2) public.profiles INSERT (full_name, preferred_language, phone)
-- atomik bitta tranzaksiyada
```

---

## 4. Email verification

Email verify link Supabase'dan keladi. Universal link / deep link sozlanishi shart:

- iOS: Associated Domains
- Android: App Links

Verify bo'lgandan keyin mobile app login screen'ga qaytadi va auto-login mumkin (refresh token bo'lsa).

---

## 5. Login flow

```dart
// lib/auth/login_screen.dart
Future<void> _onLogin() async {
  try {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (response.session == null) {
      throw 'Invalid credentials';
    }

    // Email confirmed?
    if (response.user?.emailConfirmedAt == null) {
      _showError('Email tasdiqlanmagan');
      return;
    }

    // Backend'dan profile + role'larni olish
    final me = await GetIt.I<AuthRepository>().fetchMe();

    // Initial mode tanlash
    await _decideInitialMode(me);

    // Phoenix.rebirth orqali yangi mode'da app ochiladi
    Phoenix.rebirth(context);
  } on AuthException catch (e) {
    _showError(e.message);
  }
}

Future<void> _decideInitialMode(Me me) async {
  final box = GetIt.I<Box>(instanceName: 'settings');

  if (me.sellerProfile?.verificationStatus == 'approved') {
    // Mode chooser bottom sheet
    final chosen = await showModeChooser(context);
    await box.put('app_mode', chosen.name);
  } else {
    await box.put('app_mode', 'customer');
  }
}
```

---

## 6. Token storage

Supabase SDK avtomatik token'larni `flutter_secure_storage`'ga saqlaydi (default). Qo'shimcha sozlash kerak emas.

Auto-refresh ham SDK ichida — 60 soniya oldin expiration'dan refresh token ishlatiladi.

---

## 7. Backend so'rovlariga JWT qo'shish

Dio interceptor:

```dart
// lib/core/network/api_client.dart
Dio buildDioClient() {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        options.headers['Authorization'] = 'Bearer ${session.accessToken}';
      }
      return handler.next(options);
    },
    onError: (err, handler) async {
      // 401 → token refresh urinish (SDK avtomatik), aks holda logout
      if (err.response?.statusCode == 401) {
        await Supabase.instance.client.auth.signOut();
      }
      return handler.next(err);
    },
  ));

  return dio;
}
```

---

## 8. AuthRepository

```dart
// lib/core/auth/auth_repository.dart
class AuthRepository {
  final SupabaseClient _supabase;
  final Dio _dio;

  AuthRepository(this._supabase, this._dio);

  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  bool get isAuthenticated => _supabase.auth.currentSession != null;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<Me> fetchMe() async {
    final response = await _dio.get('/api/v1/me');
    return Me.fromJson(response.data['data']);
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    await _dio.patch('/api/v1/me', data: updates);
  }

  Future<void> deleteAccount() async {
    await _dio.delete('/api/v1/me');  // soft delete
    await _supabase.auth.signOut();
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    // Hive'da app_mode reset qilish kerakmas — keyingi loginda decide qilinadi
  }

  Future<void> dispose() async {
    // SupabaseClient root scope'da, dispose qilmaymiz
  }
}
```

---

## 9. Forgot password

```dart
await Supabase.instance.client.auth.resetPasswordForEmail(
  email,
  redirectTo: 'mebellar://reset-password',  // deep link
);
```

Email'da link → app ochiladi → password reset screen → `auth.updateUser(password: newPassword)`.

---

## 10. Logout va data cleanup

```dart
Future<void> logout() async {
  // 1) Sign out Supabase
  await Supabase.instance.client.auth.signOut();

  // 2) Hive cache tozalash
  await GetIt.I<Box>(instanceName: 'cache').clear();

  // 3) settings.app_mode reset (next login default = customer)
  await GetIt.I<Box>(instanceName: 'settings').delete('app_mode');

  // 4) Mode scope dispose va login screen'ga
  await GetIt.I.popScope();
  Phoenix.rebirth(context);
}
```

---

## 11. AuthBloc (mode-agnostic, root scope)

```dart
// lib/core/auth/auth_bloc.dart
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _auth;
  StreamSubscription<sb.AuthState>? _sub;

  AuthBloc(this._auth) : super(AuthInitial()) {
    on<AuthStarted>(_onStarted);
    _sub = _auth.authStateChanges.listen((event) {
      add(AuthSupabaseEvent(event));
    });
  }

  // ...

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
```

> AuthBloc root scope'da emas — har AppMode o'z BLoC'ini yaratadi (login screen ham, dashboard ham). AuthRepository root scope'da, Bloc'lar mode scope'da.

---

## 12. Test

Backend tomonida `INSERT INTO auth.users` SQL bilan test user yaratish mumkin (trigger profile yaratadi). Mobile test'da:

```dart
testWidgets('register and fetchMe work', (tester) async {
  await Supabase.instance.client.auth.signUp(
    email: 'test@example.com',
    password: 'password123',
    data: {'full_name': 'Test User'},
  );

  // Trigger sync — profile mavjud
  final me = await GetIt.I<AuthRepository>().fetchMe();
  expect(me.fullName, 'Test User');
});
```

---

## 13. Keyingi qadam

→ [07-api-reference.md](./07-api-reference.md) — backend endpoint xaritasi
