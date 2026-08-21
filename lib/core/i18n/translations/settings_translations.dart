// Settings screens (customer + seller) and the shared language picker.
// uz is the baseline; ru/en must stay in parity (the boot guard + the
// i18n completeness test enforce this).

const Map<String, dynamic> settingsUz = {
  'title': 'Sozlamalar',

  // Section labels
  'section_notifications': 'Bildirishnomalar',
  'section_appearance': "Ko'rinish",
  'section_privacy': 'Maxfiylik',
  'section_storage': 'Xotira',
  'section_account': 'Akkaunt',
  'section_other': 'Boshqa',

  // Language
  'language_row': 'Ilova tili',
  'language_title': 'Tilni tanlang',

  // Appearance — three-way theme picker (System / Light / Dark)
  'theme': 'Mavzu',
  'theme_title': 'Mavzuni tanlang',
  'theme_system': 'Tizimga mos',
  'theme_light': "Yorug'",
  'theme_dark': "Qorong'i",

  // Customer notifications
  'push_notifications': 'Push bildirishnomalar',
  'order_updates': 'Buyurtma yangilanishlari',

  // Seller notifications
  'new_orders': 'Yangi buyurtmalar',
  'push_messages': 'Push xabarlari',
  'customer_messages': 'Mijoz xabarlari va sharhlar',
  'system_alerts': 'Tizim xabarlari',
  'system_alerts_subtitle': 'Yangilanishlar va ogohlantirishlar',

  // Other
  'clear_cache': 'Keshni tozalash',
  'calculating': 'Hisoblanmoqda...',
  'clear_cache_message':
      'Haqiqatan ham barcha vaqtinchalik fayllar va rasmlar keshini '
      'tozalamoqchimisiz?',
  'clear_cache_confirm': 'Tozalash',
  'about': 'Ilova haqida',

  // Privacy / analytics
  'analytics_usage': 'Foydalanish statistikasi',
  'analytics_subtitle':
      'Qurilma va foydalanish eventlari ilovani yaxshilashga yordam beradi',
  'analytics_intro':
      "Ilova qaysi qismlari faol ishlatilayotganini tushunish va xatolarni "
      "tezroq topish uchun anonim statistik signallar yig'amiz.",
  'analytics_collected_label': "Nimalar yig'iladi",
  'analytics_b1': "Qaysi mahsulot va kategoriyalar ko'rilgani",
  'analytics_b2': "Savatga qo'shish va xarid voronkasi",
  'analytics_b3': "Qidiruv so'rovlari va natijalar soni",
  'analytics_b4': 'Chat va sotuvchi onboardingi bosqichlari',
  'analytics_b5':
      'Qurilma modeli, OS, ilova versiyasi va so‘nggi faollik (login)',
  'analytics_privacy_note':
      "Ism, telefon, email yoki to'lov ma'lumotlari yig'ilmaydi. Eventlar "
      "Firebase Analytics'ga shifrlangan kanal orqali yuboriladi.",
  'privacy_policy': 'Maxfiylik siyosati',
  'understood': 'Tushunarli',
};

const Map<String, dynamic> settingsRu = {
  'title': 'Настройки',

  'section_notifications': 'Уведомления',
  'section_appearance': 'Оформление',
  'section_privacy': 'Конфиденциальность',
  'section_storage': 'Память',
  'section_account': 'Аккаунт',
  'section_other': 'Прочее',

  'language_row': 'Язык приложения',
  'language_title': 'Выберите язык',

  'theme': 'Тема',
  'theme_title': 'Выберите тему',
  'theme_system': 'Системная',
  'theme_light': 'Светлая',
  'theme_dark': 'Тёмная',

  'push_notifications': 'Push-уведомления',
  'order_updates': 'Обновления заказов',

  'new_orders': 'Новые заказы',
  'push_messages': 'Push-уведомления',
  'customer_messages': 'Сообщения и отзывы клиентов',
  'system_alerts': 'Системные оповещения',
  'system_alerts_subtitle': 'Обновления и предупреждения',

  'clear_cache': 'Очистить кэш',
  'calculating': 'Вычисляется...',
  'clear_cache_message':
      'Действительно удалить все временные файлы и кэш изображений?',
  'clear_cache_confirm': 'Очистить',
  'about': 'О приложении',

  'analytics_usage': 'Статистика использования',
  'analytics_subtitle':
      'События устройства и использования помогают улучшать приложение',
  'analytics_intro':
      'Мы собираем анонимные статистические сигналы, чтобы понимать, какие '
      'части приложения используются, и быстрее находить ошибки.',
  'analytics_collected_label': 'Что собирается',
  'analytics_b1': 'Какие товары и категории просматривались',
  'analytics_b2': 'Добавление в корзину и воронка покупки',
  'analytics_b3': 'Поисковые запросы и число результатов',
  'analytics_b4': 'Этапы чата и онбординга продавца',
  'analytics_b5':
      'Модель устройства, ОС, версия приложения и последняя активность (вход)',
  'analytics_privacy_note':
      'Имя, телефон, email и платёжные данные не собираются. События '
      'отправляются в Firebase Analytics по зашифрованному каналу.',
  'privacy_policy': 'Политика конфиденциальности',
  'understood': 'Понятно',
};

const Map<String, dynamic> settingsEn = {
  'title': 'Settings',

  'section_notifications': 'Notifications',
  'section_appearance': 'Appearance',
  'section_privacy': 'Privacy',
  'section_storage': 'Storage',
  'section_account': 'Account',
  'section_other': 'Other',

  'language_row': 'App language',
  'language_title': 'Choose language',

  'theme': 'Theme',
  'theme_title': 'Choose theme',
  'theme_system': 'System',
  'theme_light': 'Light',
  'theme_dark': 'Dark',

  'push_notifications': 'Push notifications',
  'order_updates': 'Order updates',

  'new_orders': 'New orders',
  'push_messages': 'Push notifications',
  'customer_messages': 'Customer messages & reviews',
  'system_alerts': 'System alerts',
  'system_alerts_subtitle': 'Updates and warnings',

  'clear_cache': 'Clear cache',
  'calculating': 'Calculating...',
  'clear_cache_message':
      'Really clear all temporary files and the image cache?',
  'clear_cache_confirm': 'Clear',
  'about': 'About',

  'analytics_usage': 'Usage statistics',
  'analytics_subtitle': 'Device and usage events help improve the app',
  'analytics_intro':
      'We collect anonymous statistical signals to understand which parts of '
      'the app are used and to find errors faster.',
  'analytics_collected_label': "What's collected",
  'analytics_b1': 'Which products and categories were viewed',
  'analytics_b2': 'Add-to-cart and the purchase funnel',
  'analytics_b3': 'Search queries and result counts',
  'analytics_b4': 'Chat and seller onboarding steps',
  'analytics_b5':
      'Device model, OS, app version, and last activity (signed-in)',
  'analytics_privacy_note':
      'Name, phone, email and payment details are not collected. Events are '
      'sent to Firebase Analytics over an encrypted channel.',
  'privacy_policy': 'Privacy policy',
  'understood': 'Got it',
};
