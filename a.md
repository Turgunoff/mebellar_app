Tekshiruv natijalari — Mebellar Olami Flutter UI

4 ta parallel reviewer 233 ta dart fayl bo'ylab yurib chiqdi.
flutter analyze bitta unused element warning bilan toza, ammo UI
sifatida jiddiy kamchiliklar topildi. Eng muhimlarini tartiblab
beraman.

---

🔴 BLOCKER — shipping'gacha tuzatilishi shart

1. Dark mode butunlay buzilgan

Kodda 230+ Colors.white/black/grey hardcode va 201 Color(0xFF...)
literal core/theme'dan tashqarida ishlatilgan. Ya'ni tema
dark'ga o'tsa, ekranlar ko'p joyda oq fonda oq matn ko'rinadi.

- kpi_card.dart:60, seller_bottom_nav.dart:36,
  dashboard_screen.dart:151, order_details_screen.dart:97 —
  Colors.white background
- reviews_screen.dart:218,256,364,
  seller_products_screen.dart:389 — kartalar oq qotib qolgan
- shop_settings_screen.dart — CircularProgressIndicator(color:
  Colors.white) oq fon ustida ko'rinmaydi
- 6 ta seller fayl \_ink/\_grey/\_greyMid/\_divider deb lokal const
  qaytadan tarif qiladi (settings_screen, shop_settings_screen,  
  services_screen, seller_products_screen,  
  seller_product_detail_screen, product_form_screen) — bir xil rang
  oltita joyda alohida defined.  


2. 15+ onTap: () {} — o'lik tugmalar (Customer Profile)

Profile ekrani deyarli butunlay non-functional:

- profile_screen.dart:102,217,289,383,539,617,671,696 — bell,  
  edit, "Barchasi", buyurtma status, Become Seller,  
  settings/help/about, logout, delete account — hammasining  
  onPressed: () {} bo'sh.
- profile_guest_screen.dart:36,156,349 — Login/SignUp tugmalari
  va menu item'lar bo'sh.
- home_screen.dart:42,47,54,246 — uchta "See All" + qidiruv  
  field'i submit qilmaydi.
- categories_screen.dart:97, favorites_screen.dart:114 — search  
  icon bosilmaydi.  


3. Cart BLoC'ga ulanmagan  


cart_screen.dart:19-26 faqat lokal setState ishlatadi — CartBloc
customer_app.dart'da DI orqali register qilingan, lekin ekran  
 undan o'qimaydi. Demak savatga qo'shish/o'chirish persist  
 bo'lmaydi, badge ham yangilanmaydi. Va onCheckout: () {}  
 (cart_screen.dart:79) — checkout'ga ham o'tilmaydi.

---

🟠 HIGH — sezilarli UX/sifat muammolari

4. i18n teshiklari — hardcoded matnlar

- cart_screen.dart:102,430 — "Savatcha"/"Savatchaga" tr() orqali
  emas
- favorites_screen.dart:98,426 — "Sevimlilar", "Katalogga o'tish"
- profile_screen.dart:80 — "Profil"
- product_detail_screen.dart:187,232, checkout_screen.dart:217,
  order_detail_screen.dart:180 — valyuta "so'м" va miqdor belgisi  
  "×" har joyda hardcoded
- seller_orders_screen.dart:125-130,185-187 — tab label'lari  
  "Yangi"/"Faol" tr() siz

5. Form validation umuman yo'q  


- product_form_screen.dart — name/description/price/stock —  
  birortasi validate qilinmaydi, bo'sh form submit bo'lib ketadi
- seller/onboarding/widgets/personal_info_step.dart:70,  
  shop_info_step.dart:69 — onChanged har bosishda BLoC'ga emit,  
  debounce yo'q
- business_type_step.dart:1 — // ignore_for_file:  
  deprecated_member_use faylga butun, deprecated RadioListTile API
  ishlatilmoqda
- address_edit_screen.dart:212-216 — koordinatalar raw float  
  bilan ko'rsatiladi

6. Theme tokenlari noto'g'ri ishlatilgan  


- AppColors faylida "Do not consume these directly in widgets"  
  deb yozilgan, lekin 146 ta to'g'ridan-to'g'ri ishlatilgan joy bor
  (AppColors.terracotta, AppColors.lightBackground)
- GoogleFonts.plusJakartaSans(...) inline 215 marta chaqirilgan —
  theme'da Inter belgilangan, lekin seller ekranlar Plus Jakarta  
  Sans'ni qo'lda yopishtiradi
- Bir xil terracotta rang 3 xil token sifatida yashaydi:  
  AppColors.terracotta / colorScheme.primary / PremiumTokens.accent
  — qachon qaysi birini ishlatish me'yorsiz aralashgan
- 5 ta showModalBottomSheet theme'ning 28px radius'ini override  
  qiladi (product_form_screen.dart:137,168 — circular(20)) yoki  
  shape umuman ko'rsatmaydi

7. Mock data realligi yetarli emas

- mock_data.dart:281-530 — atigi 19 ta mahsulot 9 kategoriyada,  
  ammo productCount: 12/10/8/6/... deb yozilgan — kategoriya filtri
  tez bo'sh ekranga uradi
- mock_seller_products.dart:17-25 — barcha rasm
  picsum.photos/seed/... — internetsiz hech qanday rasm  
  ko'rinmaydi, fallback yo'q
- mock_notifications_data.dart — 10 ta NotificationKind'dan faqat
  5 tasi seed qilingan: orderCancelled, productRejected,  
  verificationRejected, tariffRejected umuman test qilinmagan
- Order'lar barcha DateTime.now()'dan eski — "Hozir" / "1 daqiqa
  oldin" relative format test qilinmaydi
- mock_orders_data.dart:14-19 — region ID'larni hardcoded string
  bilan qidiradi, mock_regions.dart'da ID o'zgarsa firstWhere crash
  beradi
- quantity_stepper.dart:46 — max 99 hardcoded, product.stockni  
  e'tiborga olmaydi → omborida 2 ta bo'lsa ham 99 tanlash mumkin
- product_card.dart:82 — chegirma foizini chiqarganda oldPrice ==
  price bo'lsa "0%" badge, oldPrice < price bo'lsa minus foiz  
  chiqaradi  


---

🟡 MEDIUM — design system drift

8. Border radius / spacing tarqoq

- circular(14) 34 marta, circular(10) 21 marta — rasmiy shkaladan
  tashqarida (8/12/16/20/24)
- Mikro-radius'lar: circular(2), (3), (6) —  
  product_form_screen.dart:1752, analytics_screen.dart:589,  
  tariff_screen.dart:359
- glass_bottom_nav.dart:56,72,79 — circular(30) (haddan past)
- 4-multiple grid'ni buzuvchi padding'lar 40+ joyda: vertical:  
  7/9, horizontal: 14, vertical: 5 (eng yaxshisi  
  tariff_screen.dart:359 — horizontal: 7, vertical: 3)  


9. Status ranglar tasodifiy

- AppCustomColors.success/warning/error aniqlangan, lekin  
  ekranlar Colors.green / Colors.red / Color(0xFFC0392B) ishlatadi
  (tariff_pending_screen.dart:201, seller_products_screen.dart:318,
  order_detail_screen.dart:85)
- Auth screen'larda Colors.red.shade700 3 xil joyda
  (login_screen.dart:71, register_screen.dart:66,  
  forgot_password_screen.dart:52)

10. Onboarding bug

- onboarding_screen.dart:54 — step indicator verifyChoice'da  
  100%'ga yetadi, lekin Done step keyinroq → user tugadi deb
  o'ylaydi
- onboarding_screen.dart:46-51 — PopScope welcome/done'da only —
  orada xato bo'lsa qaytib chiqib bo'lmaydi

11. Image / loading state'lar  


- address_edit_screen.dart:108 — MapPreview shunchaki  
  placeholder, "Sprint 5" izohi bilan
- product_form_screen.dart:24 — \_kMaxPhotos = 10 lekin UI'da  
  limit ko'rsatilmaydi, "add" tugmasi disable bo'lmaydi
- verification_screen.dart — hujjat upload paytida loading
  indikator yo'q
- product_detail_screen.dart:65-70 — loading bosqichida
  shimmer/skeleton emas, oddiy CircularProgressIndicator cheksiz  
  aylanadi
- payment_instructions_sheet.dart:114-119 — FutureBuilder error  
  state'siz, fail bo'lsa cheksiz spinner

12. Performance / state  


- cart_screen.dart:28-34 — total/filter build() ichida har frame
  qayta hisoblanadi, memoization yo'q
- BlocConsumer checkout_screen.dart:54-61 — har status flap'da  
  listener, dialog stack'ka tushib qolishi mumkin
- home_screen.dart:456-478 — GridView ichki ListView'da,
  SliverToBoxAdapter siz overflow xavfi
- \_NotificationBell seller/profile_screen.dart:174 — unused
  element (flutter analyze warning)  


---

🟢 LOW — polish

- 26 ta turli alpha: qiymat (0.04/0.05/0.06 deyarli bir xil,
  lekin alohida) — semantic token yo'q
- 44 ta inline BoxShadow, PremiumTokens.softShadow/cardShadow
  mavjud bo'lsa-da, deyarli ishlatilmaydi
- 15 ta turli icon size: (12/13/14/16/18/22/24/26/28...) —
  semantic xarita yo'q
- addresses_screen.dart:108 — edit menu label tr('common.next')
  (xato kalit)
- expandable_description.dart:39 — InkWell'da Semantics yo'q,
  screen reader announce qilmaydi
- notification_simulator_screen.dart:64-114 — 6 ta scenario tile
  hardcoded, NotificationKind kengaytirilsa avtomatik yangilanmaydi
- Order status / verification banner / product status chip — har
  biri o'z palette'ini yaratadi, umumiy tizim yo'q  


---

Tavsiya — qaysi tartibda tuzatish

1. Avval blocker'lar (1, 2, 3): dark mode, dead handler'lar,
   cart-bloc ulash. Bu uchtasi "demo'da yaxshi ko'rinadi, ishlatib  
   bo'lmaydi" muammosini hal qiladi.
2. i18n + form validation (4, 5): qoplama yaxshilanadi, store  
   review'da yiqilmaydi.
3. Theme migratsiya (6, 8): bitta \_DesignTokens (yoki kengaytirib
   AppCustomColors) yarating, 6 ta lokal \_ink/\_grey ta'rifini va  
   AppColors.X to'g'ridan ishlatishlarni shunga ko'chiring.
   circular(14) → circular(12) global topib-almashtirish.
4. Mock data kengaytirish (7): har kategoriyaga 5+ mahsulot,
   barcha NotificationKind/OrderStatus/VerificationStatus  
   qiymatlari, "yangi" sana'lar, Future.delayed random latency,
   ba'zi mock'larda error simulation.
5. Qolganlari — polish'da kelishi mumkin.

Eng tezkor g'alaba: grep -rn "Colors.white\|Color(0xFF"  
 lib/seller lib/customer | grep -v core/theme ro'yxatini olib, har
bir hit'ni Theme.of(context)'ga ko'chirish — bu bir kun ish,  
 lekin dark mode'ni butunlay ishlatadi.

Agar xohlasangiz, bittasidan boshlab konkret patch'lar qilib  
 ketaman — qaysisidan boshlaymiz?
