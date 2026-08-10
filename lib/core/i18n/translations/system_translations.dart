// Cross-cutting infra: offline indicator, the in-app update gate, and the
// deep-link debug tester.

const Map<String, dynamic> updateUz = {
  'required_title': 'Yangi versiya mavjud!',
  'required_body':
      'Ilovamiz yanada qulay va tezkor bo\'ldi. Davom etish uchun ilovani '
      'yangilang.',
  'update_now': 'Yangilash',
};

const Map<String, dynamic> updateRu = {
  'required_title': 'Доступна новая версия!',
  'required_body':
      'Приложение стало удобнее и быстрее. Обновите его, чтобы продолжить.',
  'update_now': 'Обновить',
};

const Map<String, dynamic> updateEn = {
  'required_title': 'A new version is available!',
  'required_body':
      'Our app is now smoother and faster. Update it to continue.',
  'update_now': 'Update',
};

// Maintenance overlay — the title is app copy (tr); the body comes from the
// backend `maintenance.message`, with this localized fallback when it's blank.
const Map<String, dynamic> maintenanceUz = {
  'title': 'Texnik Xizmat',
  'fallback_message': 'Tez orada qaytamiz.',
};

const Map<String, dynamic> maintenanceRu = {
  'title': 'Технические работы',
  'fallback_message': 'Скоро вернёмся.',
};

const Map<String, dynamic> maintenanceEn = {
  'title': 'Under Maintenance',
  'fallback_message': 'We\'ll be back soon.',
};

const Map<String, dynamic> offlineUz = {
  'banner': 'Internet aloqasi yo\'q',
  'restored': 'Tarmoq tiklandi',
  'toggle_title': 'Tarmoq holati',
  'toggle_online': 'Online — barcha so\'rovlar oddiy ketadi',
  'toggle_offline': 'Offline — banner ko\'rinadi, kesh fallback ishlatiladi',
};

const Map<String, dynamic> offlineRu = {
  'banner': 'Нет подключения к интернету',
  'restored': 'Соединение восстановлено',
  'toggle_title': 'Состояние сети',
  'toggle_online': 'Online — запросы работают как обычно',
  'toggle_offline': 'Offline — показывается баннер, используется кэш',
};

const Map<String, dynamic> offlineEn = {
  'banner': 'No internet connection',
  'restored': 'Connection restored',
  'toggle_title': 'Network status',
  'toggle_online': 'Online — requests run normally',
  'toggle_offline': 'Offline — the banner shows, cache fallback is used',
};

// Default title/message for the inline full-screen "no connection"
// placeholder (`ErrorState`) — shown as a screen's body when a critical fetch
// fails AND there is no cached data to fall back on. Non-blocking; a
// reconnect repopulates it silently. The retry label is shared (`common.retry`).
const Map<String, dynamic> networkErrorUz = {
  'title': 'Internetga ulanib bo\'lmadi',
  'message':
      'Ma\'lumotlarni yuklab bo\'lmadi. Internet aloqangizni tekshirib, '
      'qayta urinib ko\'ring.',
};

const Map<String, dynamic> networkErrorRu = {
  'title': 'Нет подключения к интернету',
  'message':
      'Не удалось загрузить данные. Проверьте подключение к интернету и '
      'попробуйте снова.',
};

const Map<String, dynamic> networkErrorEn = {
  'title': 'No internet connection',
  'message':
      'We couldn\'t load the latest data. Check your internet connection and '
      'try again.',
};

const Map<String, dynamic> deepLinksUz = {
  'tester_title': 'Deep link tekshiruvi',
  'tester_hint':
      'URI\'ni kiriting va tugmani bosing — handler navigatsiya qiladi',
  'routed': 'Yo\'naltirildi: mode={}, route={}',
  'unrecognised': 'URI tan olinmadi',
};

const Map<String, dynamic> deepLinksRu = {
  'tester_title': 'Тест deep link',
  'tester_hint': 'Введите URI и нажмите кнопку — обработчик выполнит переход',
  'routed': 'Перенаправлено: mode={}, route={}',
  'unrecognised': 'URI не распознан',
};

const Map<String, dynamic> deepLinksEn = {
  'tester_title': 'Deep link tester',
  'tester_hint': 'Enter a URI and tap send — the handler routes immediately',
  'routed': 'Routed: mode={}, route={}',
  'unrecognised': 'URI not recognised',
};
