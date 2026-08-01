# Privacy Policy — Woody

**Last updated:** 2026-08-01

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
| **Yandex Maps** | Yetkazib berish manzilini belgilash | yandex.com/legal/privacy |
| **Payme / Click** | Onlayn to'lov (deep-link) | tegishli to'lov tizimi siyosati |

**Supabase ishlatilmaydi** — avvalgi stack to'liq almashtirilgan.

#### 3a. Foydalanish statistikasi (opt-out)

Sozlamalardagi **"Foydalanish statistikasi"** tugmasi orqali istalgan vaqtda Firebase Analytics va Crashlytics ma'lumot yig'ishni o'chirishingiz mumkin. O'chirilganda yig'ish qurilmada to'xtatiladi (shu jumladan keyingi ishga tushirishlarda).

#### 4. Ma'lumotlarni saqlash

- Ma'lumotlar foydalanuvchi hisob o'chirishni so'raguncha saqlanadi
- Hisob o'chirilganda shaxsiy ma'lumotlar platforma qoidalariga muvofiq o'chiriladi / anonimlashtiriladi

#### 5. Ma'lumotlarni uchinchi tomonlarga berish

Biz shaxsiy ma'lumotlarni hech qachon sotmaymiz yoki reklama maqsadida ulashmaymiz. To'lov provayderlari faqat to'lovni amalga oshirish uchun zarur ma'lumotni oladi.

#### 6. Foydalanuvchi huquqlari

Siz quyidagi huquqlarga egasiz:

- Ma'lumotlaringizni ko'rish va tahrirlash
- Hisobingizni va bog'liq ma'lumotlarni o'chirish
- Statistikani o'chirish (§3a) va push sozlamalarini boshqarish

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
| **Yandex Maps** | Выбор адреса доставки | yandex.com/legal/privacy |
| **Payme / Click** | Онлайн-оплата (deep-link) | политики платёжных систем |

**Supabase не используется** — прежний стек полностью заменён.

#### 3а. Статистика использования (opt-out)

В настройках переключатель **"Foydalanish statistikasi"** в любой момент отключает сбор Firebase Analytics и Crashlytics на устройстве (включая последующие запуски).

#### 4. Хранение данных

- Данные хранятся до удаления аккаунта пользователем
- При удалении аккаунта персональные данные удаляются / обезличиваются по правилам платформы

#### 5. Передача данных третьим лицам

Мы никогда не продаём и не передаём персональные данные в рекламных целях. Платёжные провайдеры получают только данные, необходимые для проведения платежа.

#### 6. Права пользователя

Вы имеете право:

- Просматривать и редактировать свои данные
- Удалить аккаунт и связанные данные
- Отключить статистику (§3а) и управлять push-настройками

#### 7. Контакты

По вопросам: **eshniyazov.jasur.89@gmail.com**
