# Privacy Policy — Woody

**Last updated:** 2026-08-10

---

## O'ZBEK

### Maxfiylik Siyosati

Ushbu maxfiylik siyosati **Woody** ilovasining foydalanuvchi ma'lumotlarini qanday yig'ish, ishlatish va himoya qilishini tushuntiradi.

#### 1. Yig'iladigan ma'lumotlar

Biz quyidagi ma'lumotlarni yig'amiz:

- **Hisob ma'lumotlari** — ism, telefon raqam (parolsiz telefon + SMS OTP orqali kirish)
- **Yetkazib berish manzili** — buyurtma uchun ko'rsatilgan manzil
- **Buyurtma va to'lov ma'lumotlari** — tanlangan mahsulotlar, to'lov turi (naqd / Payme / Click), buyurtma holati
- **Qurilma ma'lumotlari** — operatsion tizim versiyasi, qurilma modeli, push token (xatoliklar va bildirishnomalar uchun)
- **Foydalanish statistikasi** (ixtiyoriy) — ilova ichidagi tahlil va nosozlik hisobotlari (pastdagi §3a)
- **Qurilmaning reklama identifikatori** (ixtiyoriy) — iOS'da IDFA, Android'da GAID; faqat siz rozilik berganingizda reklama atributsiyasi uchun (pastdagi §3b)

#### 2. Ma'lumotlar qanday ishlatiladi

Yig'ilgan ma'lumotlar faqat quyidagi maqsadlarda ishlatiladi:

- Buyurtmalarni qayta ishlash, to'lov va yetkazib berish
- Foydalanuvchi hisobini boshqarish
- Ilova ishlashini yaxshilash va nosozliklarni tuzatish
- Foydalanuvchiga bildirishnomalar yuborish (sozlamalar bo'yicha)

#### 3. Infratuzilma va uchinchi tomon xizmatlar

Woody o'zining **Python / FastAPI** backendida (`api.woody.uz`) ishlaydi: autentifikatsiya, katalog, buyurtmalar va ma'lumotlar bazasi shu yerda. Ob'ektlar **Cloudflare R2** da saqlanadi (AWS S3-ga mos xotira). Ilova quyidagi uchinchi tomon xizmatlaridan ham foydalanadi:

| Xizmat | Maqsad | Siyosat |
|--------|--------|---------|
| **Firebase** (Google) | Push (FCM), Analytics, Crashlytics | firebase.google.com/support/privacy |
| **Meta Platforms** (Facebook) | Reklama tahlili va atributsiya (App Events SDK) | facebook.com/privacy/policy |
| **Yandex Maps** | Yetkazib berish manzilini belgilash | yandex.com/legal/privacy |
| **Payme / Click** | Onlayn to'lov (deep-link) | tegishli to'lov tizimi siyosati |

**Supabase ishlatilmaydi** — avvalgi stack to'liq almashtirilgan.

#### 3a. Foydalanish statistikasi (opt-out)

Sozlamalardagi **"Foydalanish statistikasi"** tugmasi orqali istalgan vaqtda Firebase Analytics va Crashlytics ma'lumot yig'ishni o'chirishingiz mumkin. O'chirilganda yig'ish qurilmada to'xtatiladi (shu jumladan keyingi ishga tushirishlarda). Bu tugma §3b dagi Meta'ga uzatishni ham to'xtatadi.

#### 3b. Reklama tahlili va atributsiya (Meta / Facebook)

Ilova reklama kampaniyalarimiz samaradorligini o'lchash uchun **Meta Platforms (Facebook)** kompaniyasining App Events SDK'sidan foydalanadi.

**Meta'ga nima uzatiladi:**

- qurilmaning reklama identifikatori — iOS'da **IDFA**, Android'da **GAID**
- ilova ichidagi hodisalar — ilovani ochish, mahsulotni ko'rish, savatga qo'shish, to'lovni boshlash, buyurtmani rasmiylashtirish (summasi va mahsulot identifikatorlari bilan), ro'yxatdan o'tish, AR/AI funksiyalaridan foydalanish

Bu ma'lumot qaysi reklama qaysi o'rnatish va buyurtmaga olib kelganini aniqlash uchun ishlatiladi.

**Woody Meta'ga ismingizni, telefon raqamingizni yoki elektron pochta manzilingizni uzatmaydi.**

**Rozilik va uni qaytarib olish:**

- **iOS** — ilova birinchi ishga tushganda Apple'ning **App Tracking Transparency** so'rovi ko'rsatiladi. Rad etsangiz Meta'ga hech narsa yuborilmaydi. Javobni keyinchalik *Sozlamalar → Maxfiylik va xavfsizlik → Kuzatuv* bo'limidan o'zgartirish mumkin.
- **Barcha qurilmalarda** — ilovaning *Sozlamalar → "Foydalanish statistikasi"* tugmasi rozilikni istalgan vaqtda qaytarib oladi. O'chirilgan zahoti uzatish to'xtaydi va keyingi ishga tushirishlarda ham qayta boshlanmaydi.

Har ikkala shart bajarilgandagina uzatish amalga oshiriladi: iOS'da ATT ruxsati **va** ilova ichidagi tugma yoqilgan bo'lishi kerak.

#### 4. Ma'lumotlarni saqlash

- Ma'lumotlar foydalanuvchi hisob o'chirishni so'raguncha saqlanadi
- Hisob o'chirilganda shaxsiy ma'lumotlar platforma qoidalariga muvofiq o'chiriladi / anonimlashtiriladi

#### 5. Ma'lumotlarni uchinchi tomonlarga berish

Biz shaxsiy ma'lumotlarni **hech qachon sotmaymiz**. Ismingiz, telefon raqamingiz va elektron pochta manzilingiz reklama maqsadida uchinchi tomonlarga uzatilmaydi. To'lov provayderlari faqat to'lovni amalga oshirish uchun zarur ma'lumotni oladi.

Yagona istisno — §3b da tavsiflangan holat: siz rozilik berganingizda qurilmaning reklama identifikatori va ilova ichidagi hodisalar reklama atributsiyasi uchun Meta'ga uzatiladi. Bu ma'lumot ismingiz yoki telefon raqamingiz bilan birga yuborilmaydi va roziligingizni istalgan vaqtda qaytarib olishingiz mumkin.

#### 6. Foydalanuvchi huquqlari

Siz quyidagi huquqlarga egasiz:

- Ma'lumotlaringizni ko'rish va tahrirlash
- Hisobingizni va bog'liq ma'lumotlarni o'chirish
- Statistikani o'chirish (§3a) va push sozlamalarini boshqarish
- Reklama atributsiyasi uchun roziligingizni qaytarib olish — iOS'da ATT orqali, barcha qurilmalarda "Foydalanish statistikasi" tugmasi orqali (§3b)

#### 7. Bog'lanish

Savollar uchun: **eshniyazov.jasur.89@gmail.com**

---

## РУССКИЙ

### Политика конфиденциальности

Настоящая политика конфиденциальности объясняет, как приложение **Woody** собирает, использует и защищает данные пользователей.

#### 1. Собираемые данные

Мы собираем следующие данные:

- **Данные аккаунта** — имя, номер телефона (вход по телефону + SMS OTP)
- **Адрес доставки** — адрес, указанный для заказа
- **Данные заказов и оплаты** — выбранные товары, способ оплаты (наличные / Payme / Click), статус заказа
- **Данные устройства** — версия ОС, модель, push-токен (для ошибок и уведомлений)
- **Статистика использования** (опционально) — аналитика и отчёты о сбоях (см. §3а)
- **Рекламный идентификатор устройства** (опционально) — IDFA на iOS, GAID на Android; только с вашего согласия, для рекламной атрибуции (см. §3б)

#### 2. Как используются данные

Собранные данные используются исключительно для:

- Обработки заказов, оплаты и доставки
- Управления аккаунтом
- Улучшения приложения и исправления ошибок
- Отправки уведомлений (согласно настройкам)

#### 3. Инфраструктура и сторонние сервисы

Woody работает на собственном бэкенде **Python / FastAPI** (`api.woody.uz`): аутентификация, каталог, заказы и база данных. Файлы хранятся в **Cloudflare R2** (S3-совместимое хранилище). Также используются:

| Сервис | Назначение | Политика |
|--------|-----------|---------|
| **Firebase** (Google) | Push (FCM), Analytics, Crashlytics | firebase.google.com/support/privacy |
| **Meta Platforms** (Facebook) | Рекламная аналитика и атрибуция (App Events SDK) | facebook.com/privacy/policy |
| **Yandex Maps** | Выбор адреса доставки | yandex.com/legal/privacy |
| **Payme / Click** | Онлайн-оплата (deep-link) | политики платёжных систем |

**Supabase не используется** — прежний стек полностью заменён.

#### 3а. Статистика использования (opt-out)

В настройках переключатель **"Foydalanish statistikasi"** в любой момент отключает сбор Firebase Analytics и Crashlytics на устройстве (включая последующие запуски). Этот же переключатель останавливает передачу в Meta, описанную в §3б.

#### 3б. Рекламная аналитика и атрибуция (Meta / Facebook)

Приложение использует SDK App Events компании **Meta Platforms (Facebook)** для оценки эффективности наших рекламных кампаний.

**Что передаётся в Meta:**

- рекламный идентификатор устройства — **IDFA** на iOS, **GAID** на Android
- события внутри приложения — запуск приложения, просмотр товара, добавление в корзину, начало оформления, оформление заказа (с суммой и идентификаторами товаров), регистрация, использование AR/AI-функций

Эти данные используются, чтобы определить, какая реклама привела к установке и заказу.

**Woody не передаёт в Meta ваше имя, номер телефона или адрес электронной почты.**

**Согласие и его отзыв:**

- **iOS** — при первом запуске приложение показывает системный запрос Apple **App Tracking Transparency**. При отказе в Meta не отправляется ничего. Ответ можно изменить позже в *Настройках → Конфиденциальность и безопасность → Отслеживание*.
- **На любом устройстве** — переключатель *Настройки → "Foydalanish statistikasi"* в приложении отзывает согласие в любой момент. Передача прекращается сразу и не возобновляется при последующих запусках.

Передача происходит только при выполнении обоих условий: на iOS — разрешение ATT **и** включённый переключатель в приложении.

#### 4. Хранение данных

- Данные хранятся до удаления аккаунта пользователем
- При удалении аккаунта персональные данные удаляются / обезличиваются по правилам платформы

#### 5. Передача данных третьим лицам

Мы **никогда не продаём** персональные данные. Ваше имя, номер телефона и адрес электронной почты не передаются третьим лицам в рекламных целях. Платёжные провайдеры получают только данные, необходимые для проведения платежа.

Единственное исключение описано в §3б: с вашего согласия рекламный идентификатор устройства и события внутри приложения передаются в Meta для рекламной атрибуции. Эти данные не сопровождаются вашим именем или номером телефона, и согласие можно отозвать в любой момент.

#### 6. Права пользователя

Вы имеете право:

- Просматривать и редактировать свои данные
- Удалить аккаунт и связанные данные
- Отключить статистику (§3а) и управлять push-настройками
- Отозвать согласие на рекламную атрибуцию — через ATT на iOS и через переключатель "Foydalanish statistikasi" на любом устройстве (§3б)

#### 7. Контакты

По вопросам: **eshniyazov.jasur.89@gmail.com**
