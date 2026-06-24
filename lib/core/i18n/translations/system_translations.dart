// Cross-cutting infra: offline indicator, the in-app update gate, and the
// deep-link debug tester.

const Map<String, dynamic> updateUz = {
  'required_title': 'Yangilanish kerak',
  'required_body':
      'Woody\'ning yangi versiyasi chiqdi. Davom etish uchun ilovani '
      'yangilang.',
  'update_now': 'Yangilash',
  'ready_title': 'Yangilanish tayyor',
  'ready_body': 'O\'rnatish uchun ilovani qayta ishga tushiring',
  'restart_now': 'Qayta ochish',
};

const Map<String, dynamic> updateRu = {
  'required_title': 'Требуется обновление',
  'required_body':
      'Вышла новая версия Woody. Обновите приложение, чтобы продолжить.',
  'update_now': 'Обновить',
  'ready_title': 'Обновление готово',
  'ready_body': 'Перезапустите приложение, чтобы установить его',
  'restart_now': 'Перезапуск',
};

const Map<String, dynamic> updateEn = {
  'required_title': 'Update required',
  'required_body':
      'A new version of Woody is available. Update the app to continue.',
  'update_now': 'Update',
  'ready_title': 'Update ready',
  'ready_body': 'Restart the app to install it',
  'restart_now': 'Restart',
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

// Inline full-screen "no connection" placeholder (NetworkErrorView) — shown as
// a screen's body when a critical fetch fails AND there is no cached data to
// fall back on. Non-blocking; a reconnect repopulates it silently.
const Map<String, dynamic> networkErrorUz = {
  'title': 'Internetga ulanib bo\'lmadi',
  'message':
      'Ma\'lumotlarni yuklab bo\'lmadi. Internet aloqangizni tekshirib, '
      'qayta urinib ko\'ring.',
  'retry': 'Qayta urinish',
};

const Map<String, dynamic> networkErrorRu = {
  'title': 'Нет подключения к интернету',
  'message':
      'Не удалось загрузить данные. Проверьте подключение к интернету и '
      'попробуйте снова.',
  'retry': 'Повторить',
};

const Map<String, dynamic> networkErrorEn = {
  'title': 'No internet connection',
  'message':
      'We couldn\'t load the latest data. Check your internet connection and '
      'try again.',
  'retry': 'Retry',
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
