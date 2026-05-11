// Profile screen and the notifications inbox + push debug simulator copy.

const Map<String, dynamic> profileUz = {
  'title': 'Profil',
};

const Map<String, dynamic> profileRu = {
  'title': 'Профиль',
};

const Map<String, dynamic> profileEn = {
  'title': 'Profile',
};

const Map<String, dynamic> notificationsUz = {
  'title': 'Bildirishnomalar',
  'empty': 'Hech qanday bildirishnoma yo\'q',
  'empty_hint':
      'Buyurtma, do\'kon va promo haqidagi yangiliklar shu yerda paydo bo\'ladi',
  'mark_all_read': 'Hammasini o\'qildi',
  'simulator_title': 'Push simulyatori',
  'simulator_link_hint': '6 cross-mode holat (debug only)',
  'simulator_hint':
      'Joriy rejim: {}. Quyidagi holatlardan birini tanlang.',
  'simulator_done_same_mode':
      'Bildirishnoma bir xil rejim — to\'g\'ri navigatsiya qilindi',
  'simulator_done_stash':
      'Pending route saqlandi — keyingi mode shell consume qiladi',
  'simulator_done_cold':
      'Mode\'ni almashtirish + pending route saqlandi (cold start simulyatsiyasi)',
  'scenario': {
    'same_foreground': '1. App ochiq, mode mos',
    'same_foreground_hint':
        'Joriy rejimda push tap — to\'g\'ridan-to\'g\'ri navigatsiya',
    'cross_foreground': '2. App ochiq, mode farqli',
    'cross_foreground_hint':
        'Boshqa rejim push — pending saqlanadi + switchAppMode',
    'same_background': '3. App fonda, mode mos',
    'same_background_hint':
        'Pending route stash, app fokusga kirganda consume qilinadi',
    'cross_background': '4. App fonda, mode farqli',
    'cross_background_hint':
        'Pending stash + foydalanuvchi mode\'ni almashtirgach consume',
    'same_cold': '5. App butunlay yopiq, mode mos',
    'same_cold_hint':
        'Cold start: pending route consume qilinadi, mode mos qoldi',
    'cross_cold': '6. App butunlay yopiq, mode farqli',
    'cross_cold_hint':
        'Cold start: app_mode override + pending route + switchAppMode',
  },
};

const Map<String, dynamic> notificationsRu = {
  'title': 'Уведомления',
  'empty': 'Нет уведомлений',
  'empty_hint': 'Здесь появятся обновления заказов, магазина и акции',
  'mark_all_read': 'Прочитать все',
  'simulator_title': 'Симулятор push',
  'simulator_link_hint': '6 cross-mode сценариев (debug only)',
  'simulator_hint': 'Текущий режим: {}. Выберите сценарий ниже.',
  'simulator_done_same_mode': 'Тот же режим — выполнен прямой переход',
  'simulator_done_stash':
      'Pending route сохранён — будет применён при возврате',
  'simulator_done_cold':
      'Переключение режима + pending route (имитация cold start)',
  'scenario': {
    'same_foreground': '1. Приложение открыто, режим совпадает',
    'same_foreground_hint':
        'Тап по push в текущем режиме — прямой переход',
    'cross_foreground': '2. Приложение открыто, режим отличается',
    'cross_foreground_hint':
        'Push для другого режима — сохранение + switchAppMode',
    'same_background': '3. Приложение в фоне, режим совпадает',
    'same_background_hint':
        'Pending route stash, применяется при возврате в фокус',
    'cross_background': '4. Приложение в фоне, режим отличается',
    'cross_background_hint': 'Stash + после смены режима применяется',
    'same_cold': '5. Приложение полностью закрыто, режим совпадает',
    'same_cold_hint':
        'Cold start: pending route применяется, режим тот же',
    'cross_cold': '6. Приложение полностью закрыто, режим отличается',
    'cross_cold_hint':
        'Cold start: app_mode override + pending route + switchAppMode',
  },
};

const Map<String, dynamic> notificationsEn = {
  'title': 'Notifications',
  'empty': 'No notifications',
  'empty_hint': 'Order updates, shop news and promos show up here',
  'mark_all_read': 'Mark all read',
  'simulator_title': 'Push simulator',
  'simulator_link_hint': '6 cross-mode scenarios (debug only)',
  'simulator_hint': 'Current mode: {}. Pick a scenario below.',
  'simulator_done_same_mode': 'Same-mode push — navigated directly',
  'simulator_done_stash':
      'Pending route saved — applied on next consume',
  'simulator_done_cold':
      'Mode switch + pending route saved (cold start sim)',
  'scenario': {
    'same_foreground': '1. App open, same mode',
    'same_foreground_hint': 'Tap a push in the current mode → direct nav',
    'cross_foreground': '2. App open, different mode',
    'cross_foreground_hint': 'Other-mode push → stash + switchAppMode',
    'same_background': '3. App in background, same mode',
    'same_background_hint': 'Pending route stash, consumed on resume',
    'cross_background': '4. App in background, different mode',
    'cross_background_hint': 'Stash + consumed after mode switch',
    'same_cold': '5. App fully closed, same mode',
    'same_cold_hint': 'Cold start: pending route consumed, same mode',
    'cross_cold': '6. App fully closed, different mode',
    'cross_cold_hint':
        'Cold start: app_mode override + pending route + switchAppMode',
  },
};
