# Woody / Mebellar — Backlog

> **Status:** Living · **Sana:** 2026-06-12
> Yo'l xaritasi: [roadmap.md](./roadmap.md)

Rejalashtirilgan, lekin hali boshlanmagan ishlar. Holat belgilari roadmap bilan
bir xil (✅ bajarilgan · 🟡 operatsion qadam kerak · 🔧 texnik qarz · 🔜 rejalashtirilgan).

---

## Phase: Deep Linking & Web Routing 🔜

**Kontekst.** Do'kon profilini ulashish (`share_plus`) hozir
`https://woody.uz/shop/:id` havolasini yuboradi (mahsulot ulashish
`https://woody.uz/product/:id` shaklini takrorlaydi). Havola **ishlaydi**, lekin
hozircha na ilovaga deep-link qiladi, na web'da do'kon sahifasini ko'rsatadi —
shunchaki domenga olib boradi. Zanjirni uzluksiz qilish kerak.

**Bajariladigan ishlar:**

- [ ] **`woody_frontend`** — `/shop/:id` web route qo'shish (do'kon profilini
      SSR/landing sifatida ko'rsatadigan sahifa; "ilovada ochish" CTA bilan,
      `/product/:id` landing'iga o'xshash).
- [ ] **iOS Universal Links** — `apple-app-site-association` faylига `/shop/*`
      path'ini qo'shish (`woody_frontend` `.well-known/` ostida xizmat qiladi).
- [ ] **Android App Links** — `assetlinks.json` ni `/shop/*` ni qamrab oladigan
      qilib tekshirish/sozlash (SHA-256 imzo barmoq izlari to'g'ri).
- [ ] **Flutter deep-link handler** — kelgan `/shop/:id` havolasini
      `ShopProfileScreen(shopId:)` ga yo'naltirish (mavjud `/product/:id`
      intercept naqshini takrorlash). O'rnatilmagan qurilma uchun **deferred
      deep link** (clipboard seed → `DeferredDeepLinkService`) ni do'konga ham
      kengaytirish.
- [ ] **`shopShareUrl()` ni qayta ko'rib chiqish** — web route va deep-link
      konfiguratsiyasi jonli bo'lgach, `lib/shared/sharing/shop_share.dart`
      dagi URL shakli ular bilan sinxron ekanini tasdiqlash (mahsulot ulashish
      bilan bir xil tartibda).

**Bog'liqliklar:** uchchala — `woody_frontend` (web route + `.well-known/`),
`mebellar_app` (deep-link handler), va deploy (statik `.well-known/` fayllar).
Mustaqil ravishda mahsulot deep-linking'i allaqachon ishlaydi — bu uni do'konга
kengaytirish, yangi infratuzilma emas.
