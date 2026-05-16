# 03 — Deferred Components (Bundle Size Optimization)

> Asl §5.4. **V2'da optional optimization** — V1 MVP'da disabled.

## 1. Muammo

Seller-specific og'ir paketlar (`fl_chart`, `pdf`, `qr_flutter`) faqat seller app'da `import` qilinadi. Customer app build'i bularga referens bermaydi → tree-shaking ularni olib tashlashi mumkin.

**Lekin** ikkala app bitta APK'da bo'lgani uchun bu paketlar baribir APK'ga kiradi. Real bundle saving uchun **Flutter deferred imports** ishlatish mumkin.

## 2. Deferred import pattern

```dart
// seller_app.dart
import 'features/analytics/analytics_screen.dart' deferred as analytics;

// foydalanish:
Future<void> openAnalytics(BuildContext context) async {
  await analytics.loadLibrary();
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => analytics.AnalyticsScreen(),
  ));
}
```

## 3. Diqqat

**Deferred loading hali ham flaky**, ayniqsa iOS'da:

- iOS App Store guidelines'iga binoan deferred kod bundle ichida bo'lishi shart (real "ondemand download" emas)
- Network'da timeout bo'lsa user error ko'radi
- Hot reload paytida deferred kod ko'p hollarda bo'sh bo'ladi

**MVP'da** oddiy import qiling, optimization keyinroq.

## 4. V2'da qo'llashning tartibi

1. Profile → analytics dependency'larni mark
2. APK size (`flutter build apk --analyze-size`) ni o'lchash
3. Deferred imports qo'shib qayta o'lchash
4. iOS QA — turli tarmoq sharoitlarida test
5. A/B yoki staged rollout

## 5. Alternative — Flutter App Bundle (AAB)

Google Play Asset Delivery (AAB) — install-time, on-demand, fast-follow modules. Buni ham V2'da ko'rib chiqish kerak.

## 6. Keyingi qadam

→ [04-realtime.md](./04-realtime.md) — Supabase Realtime integratsiyasi
