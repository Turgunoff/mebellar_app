# Architectural & Security Audit — `mebellar_app` (Woody)

> Senior Mobile Architect / Flutter audit. Sana: 2026-06-10.
> Branch: `claude/mebellar-app-audit-tgvnzd`.

**Qamrov:** `lib/` (deyarli to'liq), tarmoq qatlami (network), xavfsizlik/saqlash
(security/storage), state management, performance, Firebase, test/CI,
`.claude`/`CLAUDE.md` aniqligi.

**Asosiy xulosa:** Bu **yetuk, production-darajadagi kod bazasi**. Flutter
marketplace ilovalarida odatda uchraydigan jiddiy xatolar (tokenlar
SharedPreferences'da, refresh-storm race, hamma joyda `Image.network`, `build()`
ichida biznes-logika) bu yerda **yo'q** — aksincha, ular to'g'ri hal qilingan.
Qattiq auditor sifatida ochiq aytaman: **Blocker darajadagi muammo topilmadi.**
Quyida bitta Critical (maxfiylik sizib chiqishi) va bir nechta Moderate bor.
Tasdiqlangan kuchli tomonlar ham keltirilgan — chunki faqat muammolarni sanab
o'tadigan audit haqiqiy xavf manzarasini noto'g'ri ko'rsatadi.

---

## Severity: BLOCKER

**Yo'q.** Hech narsa production'ni qulatmaydi, sessiyani buzmaydi yoki
ma'lumotnomalarni (credentials) sizdirmaydi. Flutter marketplace'larda eng
ko'p Blocker keltirib chiqaradigan ikki soha to'g'ri ishlangan:

- **Token refresh concurrency** — `lib/core/network/woody_api_client.dart:183-186`
  **single-flight refresh** amalga oshirilgan
  (`_refreshFlight ??= _doRefresh().whenComplete(...)`). Bir vaqtda kelgan
  sakkizta 401 aniq **bitta** `/auth/refresh` chaqiruvini hosil qiladi — buni
  isbotlovchi regression test ham bor
  (`test/core/network/woody_api_client_refresh_test.dart:105-129`,
  `expect(adapter.refreshHits, 1)`). U hatto aniq `401` (revoked → sign out) ni
  vaqtinchalik `429/5xx`/network xatosidan (sessiyani saqlab qolish) ajratadi.
  Bu ko'pchilik production ilovalardan yaxshiroq.
- **Token storage** — JWT'lar `flutter_secure_storage` (Keychain /
  EncryptedSharedPreferences) da saqlanadi, **Hive/SharedPreferences'da emas**
  (`lib/core/network/token_store.dart:23-70`). Klass sarlavhasi sirlar uchun
  Hive nega taqiqlanganini ham izohlaydi. `shared_preferences` umuman dependency
  emas.

---

## Severity: CRITICAL

### C-1 — PII (telefon raqamlari) Firebase Crashlytics'ga sizib chiqmoqda

**`lib/auth/auth_sheet_controller.dart:92` va `:139`**

```dart
talker.info('Requesting OTP for: $phone');   // 92-qator — phone = +998901234567
talker.info('Verifying OTP for: $phone');    // 139-qator
```

`talker` `CrashlyticsTalkerObserver` ga ulangan
(`lib/core/logging/crashlytics_talker_observer.dart:27`), u har bir handle
qilingan logni `FirebaseCrashlytics.recordError` ga uzatadi. Natija: **OTP
so'ragan har bir foydalanuvchining to'liq E.164 telefon raqami Crashlytics
dashboard'ida saqlanadi** — bu uchinchi tomon xizmati, indekslanadi va
saqlanadi, crash sessiyalariga bog'lanadi. Bu GDPR/PII muammosi va release
build'larda ishlaydi.

**Yechim** — log oldidan maskalash (debug uchun yetarli qoldirib, identifikatsiya
qiluvchi raqamlarni tashlash):

```dart
// lib/auth/auth_sheet_controller.dart
String _maskPhone(String p) =>
    p.length <= 4 ? '***' : '${p.substring(0, 4)}***${p.substring(p.length - 2)}';

// 92-qator
talker.info('Requesting OTP for: ${_maskPhone(phone)}');   // +998***67
// 139-qator
talker.info('Verifying OTP for: ${_maskPhone(phone)}');
```

Faylning qolgan qismini ham tekshiring — boshqa hech qaysi `talker.*` ichiga
`$phone` yoki `$code` tushib qolmasligiga ishonch hosil qiling.

---

## Severity: MODERATE

### M-1 — Foydalanuvchiga xom exception matni, tarjimasiz ko'rsatilmoqda

**`lib/shared/chat/bloc/chats_list_cubit.dart:62-77`,
`lib/customer/features/search/bloc/search_bloc.dart:181-206`** (va shunga o'xshash)

```dart
onError: (Object e) => emit(
  state.copyWith(status: ChatsListStatus.failure, error: e.toString()),
),
```

To'g'ri mexanizm qurilgan — `ApiError` mashina o'qiy oladigan `code` ni olib
yuradi (`api_error.dart`) va `authErrorMessageFromApi(e)` mapper bor — lekin
bir nechta bloc uni chetlab o'tib `e.toString()` ni chiqaradi. Bu i18n qoidasini
buzadi (*"No literal user-facing copy in widgets — always a `tr(...)`"*): tarmoq
uzilsa foydalanuvchiga inglizcha `DioException [connection error]...` ko'rinadi,
uzbek/rus ilovasida.

**Yechim** — `ApiError.code → tr()` ni bir marta map qilib, hamma joyda qayta
ishlatish:

```dart
// lib/core/network/api_error_messages.dart
String apiErrorMessage(Object e) {
  if (e is ApiError) {
    return switch (e.code) {
      'network_error'    => tr('errors.network'),
      'validation_error' => tr('errors.validation'),
      _ when e.isRateLimited => tr('errors.rate_limited'),
      _ when e.isForbidden   => tr('errors.forbidden'),
      _ => tr('errors.generic'),
    };
  }
  return tr('errors.generic');
}
```

So'ng cubit/bloc'larda `error: apiErrorMessage(e)`. `errors.*` kalitlarini
uchchala bundle'ga (uz/ru/en) qo'shing, aks holda `_missing_keys_check.dart`
debug'da boot-crash beradi.

### M-2 — `BuildContext` async gap orqali `mounted` tekshiruvisiz ishlatilmoqda

**`lib/customer/features/profile/screens/edit_profile_screen.dart:111`**

```dart
await cubit.updateProfile(...);   // 106-qator — async gap
navigator.pop();                  // 111-qator — mounted tekshiruvi yo'q
```

`navigator` `await` dan oldin olingan (shuning uchun eski `context` da crash
bermaydi), lekin foydalanuvchi allaqachon boshqa sahifaga o'tib ketgan widget'da
route'ni pop qilish real lifecycle bug. `catch` bloki `setState` ni
`if (!mounted) return` (114-qator) bilan himoyalaydi — success path himoyalanmagan.

**Yechim:**

```dart
      await cubit.updateProfile(...);
      if (!mounted) return;
      navigator.pop();
```

Bu memory-leak sweep topgan yagona himoyalanmagan async-gap context ishlatilishi
edi — boshqa har bir ekran (checkout map picker, onboarding address step, auth
sheet) buni to'g'ri bajaradi. Demak, bu pattern emas, alohida xato.

### M-3 — Vaqtinchalik xatolarda retry/backoff yo'q; `Retry-After` o'qiladi-yu, qo'llanmaydi

**`lib/core/network/woody_api_client.dart` (`_toApiError`),
`api_error.dart` (`retryAfterSeconds`)**

5xx / timeout / `SocketException` to'g'ridan-to'g'ri UI'ga chiqadi, exponential
backoff yo'q, va `ApiError.retryAfterSeconds` `429` header'idan o'qiladi-yu hech
qachon ishlatilmaydi (faqat auth sheet countdown ko'rsatadi). Beqaror mobil
internetda bu bir blip = transparent qayta urinish o'rniga qattiq xato ekrani
degani.

**Yechim** — idempotent GET'lar uchun kichik retry wrapper (POST/PUT'ni ko'r-ko'rona
qayta urinmang):

```dart
Future<T> _withRetry<T>(Future<T> Function() run, {int max = 2}) async {
  for (var attempt = 0; ; attempt++) {
    try {
      return await run();
    } on ApiError catch (e) {
      final transient = e.status == 0 || e.status >= 500 || e.isRateLimited;
      if (!transient || attempt >= max) rethrow;
      final delay = e.retryAfterSeconds ?? (1 << attempt); // Retry-After'ni hurmat qil
      await Future<void>.delayed(Duration(seconds: delay));
    }
  }
}
```

Read-path repolar (catalog, dashboard, orders list) ga qo'llang.
Cached-category decorator pattern (`cached_category_repository.dart`) holicha
qoldiring — u allaqachon graceful degrade qiladi.

### M-4 — Chat thread xabarlar ro'yxatini har rebuild'da eager quradi

**`lib/shared/chat/screens/chat_thread_screen.dart:417-435`**

```dart
final messagesNewestFirst = widget.messages.reversed.toList();
final items = <Widget>[];
for (...) { items.add(MessageBubble(...)); ... }   // BARCHA bubble'larni quradi
return ListView(reverse: true, children: items);    // eager
```

Har bir yangi xabar barcha bubble'lar + sana ajratgichlarni sinxron qayta quradi.
30-xabarli thread uchun yaxshi; uzoq davom etgan buyurtma chati (yuzlab xabar)
uchun bu har kelgan xabarda va har klaviatura rebuild'ida O(n) ish. Ilovaning
qolgan qismi bu yerda namunali (har bir product/order/cart list `.builder`/Sliver
delegate'lar + `const` item'lar bilan) — bu qolgan yagona eager list.

**Yechim** — state'da oldindan hisoblangan tekis `items` ro'yxatini saqlab
(`didUpdateWidget` ichida `messages.length` o'zgarganda qayta qurib),
`itemBuilder` dan indekslab `ListView.builder` ga o'tkazing.

### M-5 — Bitta keshlashmagan `Image.network`

**`lib/seller/features/dashboard/widgets/top_products_card.dart:50-57`** —
ilovadagi yagona `Image.network`; qolgan hammasi `memCacheWidth` o'rnatilgan
`CachedNetworkImage` (~10 joyda tekshirildi). Disk kesh yo'q, decode chegarasi
yo'q. Kam chastotali kartochka, lekin nomuvofiq.

**Yechim:**

```dart
CachedNetworkImage(
  imageUrl: product.imageUrl!,
  width: 48, height: 48, memCacheWidth: 150, fit: BoxFit.cover,
  errorWidget: (_, _, _) => _ThumbPlaceholder(color: c.imageBg, icon: c.greyMid),
),
```

### M-6 — Test va CI qamrovidagi bo'shliqlar

- **Auth UI oqimi uchun widget test yo'q** (Phone → OTP → Profile). OTP
  *repository* test qilingan (`auth_repository_test.dart`) va mode-chooser widget
  test qilingan, lekin haqiqiy sheet + autofill (`AuthSheetController`) — sizning
  eng xavfsizlikka sezgir UI'ngiz — widget qamroviga ega emas.
- **Nol test:** customer `broadcasts`, `reviews`, `tutorial`; seller
  `notifications`, `reviews`.
- **CI** (`.github/workflows/ci.yml`) `dart analyze` + `flutter test` ni
  ishlatadi (yaxshi, `env/example.json` ishlatadi — sir oshkor bo'lmaydi), lekin
  **ilovani hech qachon build qilmaydi** va `integration_test/app_test.dart` ni
  ishga tushirmaydi (unga jonli backend kerak). Buzilgan release build (masalan,
  Gradle/AGP yangilanishi) kimdir `build_release.sh` ni qo'lda ishga tushirgunicha
  topilmaydi. Workflow'ga `flutter build appbundle
  --dart-define-from-file=env/example.json` smoke step (imzo kerak emas) qo'shishni
  ko'rib chiqing.

### M-7 — Backend kalit nomlarini o'zgartirganda jimgina noto'g'ri ma'lumot (dashboard savoli)

**`lib/shared/models/dashboard_snapshot.dart`,
`lib/shared/repositories/woody_seller_repositories.dart:49-94`**

Avval yaxshi xabar, "yangi dashboard maydonlari" savolingizga to'g'ridan-to'g'ri
javob: **achievements, leaderboard va aggregated KPI'lar allaqachon to'liq
ulangan** — `AchievementProgress.fromJson`, `LeaderboardStanding.fromJson`,
`TopProductStat.fromJson`, `KpiDeltas.fromJson` mavjud, hammasi null-safe
`(json['x'] as num?) ?? 0` access ishlatadi, va noma'lum/qo'shimcha maydonlar
jimgina e'tiborsiz qoldiriladi. *Yangi* nested KPI obyekti qo'shish ~3 fayl /
~10 qator. Struktura yangi payload'ni **crash bermasdan** o'zlashtiradi. Bu
to'g'ri dizayn.

Ikkinchi tomoni (Moderate): har bir `fromJson` qo'lda `as T?` + default'lar bilan
yozilgani va **codegen / compile-time kontrakt yo'q** bo'lgani uchun, backend
**kalit nomini o'zgartirsa** (masalan `revenue` → `total_revenue`) u throw bermaydi
— jimgina `0` qaytaradi. KPI har bir sotuvchining dashboard'ida nol bo'lib
ko'rinadi va hech narsa sizni ogohlantirmaydi. Yumshatish: (a) o'z qoidalaringiz
talab qilganidek enum/maydon kontraktini `woody_backend` bilan sinxron saqlang,
va (b) bo'sh bo'lmagan payload'da *ma'lum* kalit yo'qligida log beradigan
debug-only assertion qo'shishni ko'rib chiqing — shunda rename'lar production
grafiklarida emas, dev'da yuzaga chiqadi.

---

## Tasdiqlangan kuchli tomonlar (xavf manzarasi halol bo'lishi uchun)

| Soha | Topilma |
|---|---|
| **Memory safety** | 11+ bloc va realtime servisdagi har bir `StreamSubscription`/`Timer`/`Controller`/WebSocket `close()`/`dispose()` da bekor qilinadi. Bitta sweep aniq bitta himoyalanmagan async-gap pop topdi (M-2). |
| **State management** | Toza Bloc/Cubit ajratish; `build()` ichida API chaqiruvi yoki biznes-logika **yo'q**; debounce UI'da `Future.delayed` orqali emas, to'g'ri `StreamTransformer` orqali. |
| **Lists & images** | Barcha katta ro'yxatlar lazy (`*.builder`/Sliver delegate'lar) `const` item'lar bilan; barcha remote rasmlar `CachedNetworkImage` + `memCacheWidth` (bitta istisno, M-5). |
| **Crashlytics/FCM** | Yig'ish `!kDebugMode` da; `FlutterError.onError` + `PlatformDispatcher.onError` + `runZonedGuarded` ulangan; background handler top-level `@pragma('vm:entry-point')`; Android channel yaratilgan; env bilan teglangan. |
| **Secrets** | Hardcoded sir yo'q — hammasi `String.fromEnvironment` orqali, boot-vaqti `assertConfigured()` bilan; `key.properties`/env gitignored; cleartext traffic yo'q; kutilmagan exported komponentlar yo'q. |
| **`CLAUDE.md` aniqligi** | Barcha spot-check'lar o'tdi: `grep -i supabase lib/` = 0, `tools/build_release.sh` mavjud va mos, `env/example.json` kalitlari to'g'ri, AI `generateFromImages()` oqimi real, i18n bundle'lar + `_missing_keys_check.dart` mavjud. "Project brain" ishonchli. |

---

## Tavsiya etilgan ish tartibi

1. **C-1** (PII maskalash) — maxfiylik/muvofiqlik, ~10 daqiqa, darhol chiqaring.
2. **M-2** (mounted guard) + **M-5** (keshli rasm) — juda oson, C-1 bilan birga.
3. **M-1** (lokalizatsiyalangan error mapper) — 3-bundle i18n kalitlari kerak;
   eng katta UX yutug'i.
4. **M-3** (retry/backoff) va **M-4** (lazy chat list) — barqarorlik/perf
   mustahkamlash.
5. **M-6 / M-7** — test qamrovi + backend kalit drift uchun debug guard.

---

### Audit metodologiyasi

Topilmalar 6 ta parallel maxsus tekshiruv orqali yig'ildi: network/API client,
security/token storage, state management/memory leaks, seller dashboard data
layer, performance/Firebase, va tests/CI/`CLAUDE.md` aniqligi. C-1, M-2 va M-7
manbaaga qarab tasdiqlangan (`file:line` to'g'riligi).
