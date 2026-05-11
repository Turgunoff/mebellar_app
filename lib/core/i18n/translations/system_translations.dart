// Cross-cutting infra: offline indicator and the deep-link debug tester.

const Map<String, dynamic> offlineUz = {
  'banner': 'Internet aloqasi yo\'q',
  'restored': 'Aloqa tiklandi',
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

const Map<String, dynamic> deepLinksUz = {
  'tester_title': 'Deep link tekshiruvi',
  'tester_hint':
      'URI\'ni kiriting va tugmani bosing — handler navigatsiya qiladi',
  'routed': 'Yo\'naltirildi: mode={}, route={}',
  'unrecognised': 'URI tan olinmadi',
};

const Map<String, dynamic> deepLinksRu = {
  'tester_title': 'Тест deep link',
  'tester_hint':
      'Введите URI и нажмите кнопку — обработчик выполнит переход',
  'routed': 'Перенаправлено: mode={}, route={}',
  'unrecognised': 'URI не распознан',
};

const Map<String, dynamic> deepLinksEn = {
  'tester_title': 'Deep link tester',
  'tester_hint': 'Enter a URI and tap send — the handler routes immediately',
  'routed': 'Routed: mode={}, route={}',
  'unrecognised': 'URI not recognised',
};
