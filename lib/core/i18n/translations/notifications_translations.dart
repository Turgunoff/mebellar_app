// Profile screen and the notifications inbox + push debug simulator copy.

const Map<String, dynamic> profileUz = {
  'title': 'Profil',
  'avatar_pick_failed': 'Rasmni tanlab boʻlmadi',
  'save_failed_retry': 'Saqlab boʻlmadi. Qayta urinib koʻring',
  'edit_title': 'Profilni tahrirlash',
  'change_photo': 'Rasmni oʻzgartirish',
  'label_full_name': 'Ism va familiya',
  'validation_name_required': 'Ismni kiriting',
  'hint_full_name': 'Toʻliq ismingiz',
  'label_email_optional': 'Email (ixtiyoriy)',
  'validation_email_invalid': 'Email notoʻgʻri',
  'label_phone': 'Telefon raqam',
  'phone_locked_note':
      'Telefon raqam — bu sizning login identifikatoringiz, uni oʻzgartirib boʻlmaydi.',
  'save': 'Saqlash',
  'help_title': 'Yordam va Qo\'llab-quvvatlash',
  'help_contact_section': 'Murojaat qiling',
  'help_faq_section': 'Tez-tez so\'raladigan savollar',
  'help_faq_general_title': 'Umumiy savollar',
  'help_faq_delivery_time_q': 'Yetkazib berish qancha vaqt oladi?',
  'help_faq_delivery_time_a':
      'Toshkent bo\'ylab 1–2 ish kuni, viloyatlarga 3–5 ish kuni. Aniq muddat buyurtma sahifasida ko\'rsatiladi.',
  'help_faq_delivery_price_q': 'Yetkazib berish narxi qancha?',
  'help_faq_delivery_price_a':
      'Toshkent ichida 25 000 so\'mdan boshlanadi. 500 000 so\'mdan yuqori buyurtmalarga bepul.',
  'help_faq_payment_methods_q': 'Qanday to\'lov usullari mavjud?',
  'help_faq_payment_methods_a':
      'Naqd, Click, Payme, Uzcard va Humo. Yetkazib berishda to\'lash ham mumkin.',
  'help_faq_buyers_title': 'Xaridorlar uchun',
  'help_faq_cancel_q': 'Buyurtmamni qanday bekor qilaman?',
  'help_faq_cancel_a':
      '\'Buyurtmalarim\'dan kerakli buyurtmani tanlab, \'Bekor qilish\'ni bosing. Jo\'natilgunga qadar bekor qilish mumkin.',
  'help_faq_track_q': 'Buyurtma holatini qanday kuzataman?',
  'help_faq_track_a':
      '\'Buyurtmalarim\' bo\'limida joriy holat ko\'rinadi: Kutilmoqda, Tayyorlanmoqda, Yo\'lda, Yetkazilgan.',
  'help_faq_refund_q': 'To\'lovni qaytarish qanday ishlaydi?',
  'help_faq_refund_a':
      'Bekor qilinganda to\'lov 3–5 ish kunida kartaga qaytadi. Naqd to\'lovlar darhol qaytariladi.',
  'help_faq_sellers_title': 'Sotuvchilar uchun',
  'help_faq_become_seller_q': 'Qanday qilib sotuvchi bo\'lish mumkin?',
  'help_faq_become_seller_a':
      'Profil bo\'limidan \'Sotuvchi bo\'ling\' tugmasini bosib, so\'rovnoma to\'ldiring.',
  'help_faq_seller_reqs_q': 'Sotuvchilardan nimalar talab qilinadi?',
  'help_faq_seller_reqs_a':
      'Faqat sifatli mebel suratlari, to\'g\'ri o\'lchamlar va o\'z vaqtida yetkazib berish.',
  'help_contact_online_chat': 'Onlayn chat',
  'guest_welcome_title': 'Xush kelibsiz!',
  'guest_welcome_body':
      'Buyurtmalarni boshqarish va do\'koningiz savdosini kuzatish uchun tizimga kiring yoki ro\'yxatdan o\'ting.',
  'continue': 'Davom etish',
  'sell_on_woody_title': 'Woody\'da soting',
  'sell_on_woody_subtitle': 'Biznesingizni minglab xaridorlarga yetkazing',
  'sell_on_woody_showcase_title': 'Woody\'da soting! 🏪',
  'sell_on_woody_showcase_desc':
      'O\'z do\'koningizni oching va minglab xaridorlarga yeting.',
  'menu_settings': 'Sozlamalar',
  'menu_about': 'Ilova haqida',
  'menu_application_status': 'Ariza holati',
  'sign_out_title': 'Hisobdan chiqish',
  'sign_out_confirm': 'Hisobingizdan chiqmoqchimisiz?',
  'cancel': 'Bekor qilish',
  'sign_out_action': 'Chiqish',
  'delete_account_title': 'Akkauntni o\'chirish',
  'delete_account_body':
      'Haqiqatan ham hisobingizni o\'chirmoqchimisiz? Barcha ma\'lumotlaringiz, buyurtmalar tarixi va agar mavjud bo\'lsa, do\'koningiz hamda mahsulotlaringiz butunlay o\'chiriladi. Bu amalni ortga qaytarib bo\'lmaydi.',
  'delete_account_type_confirm': 'Tasdiqlash uchun DELETE so\'zini kiriting:',
  'delete_account_error': 'Xato: {error}',
  'confirm': 'Tasdiqlash',
  'delete_blocked_active_orders':
      'Hisobni o\'chirish uchun avval barcha faol buyurtmalarni yakunlang yoki bekor qiling.',
  'delete_blocked_has_debt':
      'Hisobni o\'chirish uchun avval qarzdorlikni to\'lang.',
  'delete_blocked_unwithdrawn_funds':
      'Hisobni o\'chirish uchun avval hamyoningizdagi mablag\'ni yechib oling.',
  'action_blocked_title': 'Amalni bajarib bo\'lmaydi',
  'understood': 'Tushunarli',
  'orders_active_count': '{count} ta faol buyurtma',
  'orders_total_count': 'Jami {count} ta buyurtma',
  'orders_empty': 'Hali buyurtma yo\'q',
  'orders_title': 'Buyurtmalarim',
  'become_seller_title': 'Sotuvchi bo\'ling',
  'become_seller_subtitle': 'Woody\'da o\'z biznesingizni boshlang',
  'seller_pending_title': 'Ko\'rib chiqilmoqda',
  'seller_pending_body': 'Arizangiz 24 soat ichida ko\'rib chiqiladi.',
  'seller_approved_title': 'Do\'koningiz tasdiqlandi!',
  'seller_open_panel': 'Sotuvchi paneliga o\'tish',
  'seller_rejected_title': 'Ariza rad etildi',
  'seller_rejected_subtitle':
      'Ma\'lumotlarni to\'g\'rilab qayta yuborishingiz mumkin',
  'seller_rejected_reason_label': 'SABAB',
  'seller_resubmit': 'Qayta topshirish',
  'name_not_set': 'Ism kiritilmagan',
};

const Map<String, dynamic> profileRu = {
  'title': 'Профиль',
  'avatar_pick_failed': 'Не удалось выбрать изображение',
  'save_failed_retry': 'Не удалось сохранить. Попробуйте ещё раз',
  'edit_title': 'Редактировать профиль',
  'change_photo': 'Изменить фото',
  'label_full_name': 'Имя и фамилия',
  'validation_name_required': 'Введите имя',
  'hint_full_name': 'Ваше полное имя',
  'label_email_optional': 'Email (необязательно)',
  'validation_email_invalid': 'Неверный email',
  'label_phone': 'Номер телефона',
  'phone_locked_note':
      'Номер телефона — это ваш идентификатор для входа, его нельзя изменить.',
  'save': 'Сохранить',
  'help_title': 'Помощь и поддержка',
  'help_contact_section': 'Свяжитесь с нами',
  'help_faq_section': 'Часто задаваемые вопросы',
  'help_faq_general_title': 'Общие вопросы',
  'help_faq_delivery_time_q': 'Сколько времени занимает доставка?',
  'help_faq_delivery_time_a':
      'По Ташкенту 1–2 рабочих дня, в регионы 3–5 рабочих дней. Точный срок указывается на странице заказа.',
  'help_faq_delivery_price_q': 'Сколько стоит доставка?',
  'help_faq_delivery_price_a':
      'По Ташкенту от 25 000 сум. Для заказов свыше 500 000 сум — бесплатно.',
  'help_faq_payment_methods_q': 'Какие способы оплаты доступны?',
  'help_faq_payment_methods_a':
      'Наличные, Click, Payme, Uzcard и Humo. Также можно оплатить при доставке.',
  'help_faq_buyers_title': 'Для покупателей',
  'help_faq_cancel_q': 'Как отменить мой заказ?',
  'help_faq_cancel_a':
      'В разделе «Мои заказы» выберите нужный заказ и нажмите «Отменить». Отменить можно до отправки.',
  'help_faq_track_q': 'Как отследить статус заказа?',
  'help_faq_track_a':
      'В разделе «Мои заказы» виден текущий статус: Ожидает, Готовится, В пути, Доставлен.',
  'help_faq_refund_q': 'Как работает возврат средств?',
  'help_faq_refund_a':
      'При отмене средства возвращаются на карту в течение 3–5 рабочих дней. Наличные возвращаются сразу.',
  'help_faq_sellers_title': 'Для продавцов',
  'help_faq_become_seller_q': 'Как стать продавцом?',
  'help_faq_become_seller_a':
      'В разделе «Профиль» нажмите кнопку «Стать продавцом» и заполните анкету.',
  'help_faq_seller_reqs_q': 'Что требуется от продавцов?',
  'help_faq_seller_reqs_a':
      'Только качественные фото мебели, точные размеры и своевременная доставка.',
  'help_contact_online_chat': 'Онлайн-чат',
  'guest_welcome_title': 'Добро пожаловать!',
  'guest_welcome_body':
      'Войдите или зарегистрируйтесь, чтобы управлять заказами и отслеживать продажи вашего магазина.',
  'continue': 'Продолжить',
  'sell_on_woody_title': 'Продавайте на Woody',
  'sell_on_woody_subtitle': 'Представьте свой бизнес тысячам покупателей',
  'sell_on_woody_showcase_title': 'Продавайте на Woody! 🏪',
  'sell_on_woody_showcase_desc':
      'Откройте свой магазин и выходите на тысячи покупателей.',
  'menu_settings': 'Настройки',
  'menu_about': 'О приложении',
  'menu_application_status': 'Статус заявки',
  'sign_out_title': 'Выход из аккаунта',
  'sign_out_confirm': 'Вы хотите выйти из аккаунта?',
  'cancel': 'Отмена',
  'sign_out_action': 'Выйти',
  'delete_account_title': 'Удалить аккаунт',
  'delete_account_body':
      'Вы действительно хотите удалить аккаунт? Все ваши данные, история заказов и, при наличии, ваш магазин и товары будут безвозвратно удалены. Это действие нельзя отменить.',
  'delete_account_type_confirm': 'Для подтверждения введите слово DELETE:',
  'delete_account_error': 'Ошибка: {error}',
  'confirm': 'Подтвердить',
  'delete_blocked_active_orders':
      'Чтобы удалить аккаунт, сначала завершите или отмените все активные заказы.',
  'delete_blocked_has_debt':
      'Чтобы удалить аккаунт, сначала погасите задолженность.',
  'delete_blocked_unwithdrawn_funds':
      'Чтобы удалить аккаунт, сначала выведите средства из вашего кошелька.',
  'action_blocked_title': 'Действие невозможно',
  'understood': 'Понятно',
  'orders_active_count': '{count} активных заказов',
  'orders_total_count': 'Всего {count} заказов',
  'orders_empty': 'Заказов пока нет',
  'orders_title': 'Мои заказы',
  'become_seller_title': 'Стать продавцом',
  'become_seller_subtitle': 'Начните свой бизнес на Woody',
  'seller_pending_title': 'На рассмотрении',
  'seller_pending_body': 'Ваша заявка будет рассмотрена в течение 24 часов.',
  'seller_approved_title': 'Ваш магазин подтверждён!',
  'seller_open_panel': 'Перейти в панель продавца',
  'seller_rejected_title': 'Заявка отклонена',
  'seller_rejected_subtitle':
      'Вы можете исправить данные и отправить заявку заново',
  'seller_rejected_reason_label': 'ПРИЧИНА',
  'seller_resubmit': 'Подать заново',
  'name_not_set': 'Имя не указано',
};

const Map<String, dynamic> profileEn = {
  'title': 'Profile',
  'avatar_pick_failed': 'Couldn\'t pick the image',
  'save_failed_retry': 'Couldn\'t save. Please try again',
  'edit_title': 'Edit profile',
  'change_photo': 'Change photo',
  'label_full_name': 'Full name',
  'validation_name_required': 'Enter your name',
  'hint_full_name': 'Your full name',
  'label_email_optional': 'Email (optional)',
  'validation_email_invalid': 'Invalid email',
  'label_phone': 'Phone number',
  'phone_locked_note':
      'Your phone number is your login identifier and can\'t be changed.',
  'save': 'Save',
  'help_title': 'Help & Support',
  'help_contact_section': 'Get in touch',
  'help_faq_section': 'Frequently asked questions',
  'help_faq_general_title': 'General questions',
  'help_faq_delivery_time_q': 'How long does delivery take?',
  'help_faq_delivery_time_a':
      '1–2 business days within Tashkent, 3–5 business days to the regions. The exact time is shown on the order page.',
  'help_faq_delivery_price_q': 'How much does delivery cost?',
  'help_faq_delivery_price_a':
      'From 25,000 UZS within Tashkent. Free for orders over 500,000 UZS.',
  'help_faq_payment_methods_q': 'What payment methods are available?',
  'help_faq_payment_methods_a':
      'Cash, Click, Payme, Uzcard and Humo. Payment on delivery is also available.',
  'help_faq_buyers_title': 'For buyers',
  'help_faq_cancel_q': 'How do I cancel my order?',
  'help_faq_cancel_a':
      'In \'My orders\' select the order and tap \'Cancel\'. You can cancel until it\'s shipped.',
  'help_faq_track_q': 'How do I track my order status?',
  'help_faq_track_a':
      'In \'My orders\' you\'ll see the current status: Pending, Preparing, On the way, Delivered.',
  'help_faq_refund_q': 'How do refunds work?',
  'help_faq_refund_a':
      'On cancellation the payment returns to your card within 3–5 business days. Cash payments are refunded immediately.',
  'help_faq_sellers_title': 'For sellers',
  'help_faq_become_seller_q': 'How can I become a seller?',
  'help_faq_become_seller_a':
      'In the Profile section tap \'Become a seller\' and fill out the application.',
  'help_faq_seller_reqs_q': 'What\'s required of sellers?',
  'help_faq_seller_reqs_a':
      'Just quality furniture photos, accurate dimensions and on-time delivery.',
  'help_contact_online_chat': 'Online chat',
  'guest_welcome_title': 'Welcome!',
  'guest_welcome_body':
      'Sign in or register to manage your orders and track your store\'s sales.',
  'continue': 'Continue',
  'sell_on_woody_title': 'Sell on Woody',
  'sell_on_woody_subtitle': 'Reach thousands of buyers with your business',
  'sell_on_woody_showcase_title': 'Sell on Woody! 🏪',
  'sell_on_woody_showcase_desc':
      'Open your shop and reach thousands of buyers.',
  'menu_settings': 'Settings',
  'menu_about': 'About the app',
  'menu_application_status': 'Application status',
  'sign_out_title': 'Sign out',
  'sign_out_confirm': 'Do you want to sign out of your account?',
  'cancel': 'Cancel',
  'sign_out_action': 'Sign out',
  'delete_account_title': 'Delete account',
  'delete_account_body':
      'Are you sure you want to delete your account? All your data, order history and, if any, your store and products will be permanently deleted. This action can\'t be undone.',
  'delete_account_type_confirm': 'Type DELETE to confirm:',
  'delete_account_error': 'Error: {error}',
  'confirm': 'Confirm',
  'delete_blocked_active_orders':
      'To delete your account, first complete or cancel all active orders.',
  'delete_blocked_has_debt':
      'To delete your account, first pay off your outstanding debt.',
  'delete_blocked_unwithdrawn_funds':
      'To delete your account, first withdraw the funds from your wallet.',
  'action_blocked_title': 'Action not allowed',
  'understood': 'Got it',
  'orders_active_count': '{count} active orders',
  'orders_total_count': '{count} orders in total',
  'orders_empty': 'No orders yet',
  'orders_title': 'My orders',
  'become_seller_title': 'Become a seller',
  'become_seller_subtitle': 'Start your business on Woody',
  'seller_pending_title': 'Under review',
  'seller_pending_body': 'Your application will be reviewed within 24 hours.',
  'seller_approved_title': 'Your store is approved!',
  'seller_open_panel': 'Go to seller panel',
  'seller_rejected_title': 'Application rejected',
  'seller_rejected_subtitle': 'You can correct the details and resubmit',
  'seller_rejected_reason_label': 'REASON',
  'seller_resubmit': 'Resubmit',
  'name_not_set': 'Name not set',
};

const Map<String, dynamic> notificationsUz = {
  'title': 'Bildirishnomalar',
  'empty': 'Hech qanday bildirishnoma yo\'q',
  'empty_hint':
      'Buyurtma, do\'kon va promo haqidagi yangiliklar shu yerda paydo bo\'ladi',
  'login_required_title': 'Bildirishnomalar uchun kiring',
  'login_required_message':
      'Shaxsiy bildirishnomalarni ko\'rish uchun tizimga kiring',
  'orders_login_title': 'Buyurtma bildirishnomalari',
  'orders_login_message':
      'Buyurtmalaringiz haqidagi yangilanishlarni ko\'rish uchun tizimga kiring',
  'login_cta': 'Kirish',
  'mark_all_read': 'Hammasini o\'qildi',
  'tab_all': 'Barchasi',
  'tab_orders': 'Buyurtmalar',
  'tab_system': 'Tizim',
  'tab_empty': 'Bu turkumda hozircha bildirishnoma yo\'q',
  'simulator_title': 'Push simulyatori',
  'simulator_link_hint': '6 cross-mode holat (debug only)',
  'simulator_hint': 'Joriy rejim: {}. Quyidagi holatlardan birini tanlang.',
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
  'view_cta': 'Ko\'rish',
  'read_more': 'Batafsil',
  'read_less': 'Yopish',
  'placeholder_body_with_id':
      'Placeholder — id: {id}\nMaxsus ekran keyingi bosqichda qo\'shiladi.',
  'placeholder_body': 'Maxsus ekran keyingi bosqichda qo\'shiladi.',
  'go_home': 'Bosh sahifaga',
  'kind_promo_title': 'Aksiya',
  'kind_news_title': 'Yangiliklar',
  'kind_system_alert_title': 'Tizim ogohlantirishi',
};

const Map<String, dynamic> notificationsRu = {
  'title': 'Уведомления',
  'empty': 'Нет уведомлений',
  'empty_hint': 'Здесь появятся обновления заказов, магазина и акции',
  'login_required_title': 'Войдите, чтобы видеть уведомления',
  'login_required_message':
      'Чтобы получать личные уведомления, войдите в аккаунт',
  'orders_login_title': 'Уведомления о заказах',
  'orders_login_message': 'Войдите, чтобы видеть обновления по вашим заказам',
  'login_cta': 'Войти',
  'mark_all_read': 'Прочитать все',
  'tab_all': 'Все',
  'tab_orders': 'Заказы',
  'tab_system': 'Система',
  'tab_empty': 'В этой категории пока нет уведомлений',
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
    'same_foreground_hint': 'Тап по push в текущем режиме — прямой переход',
    'cross_foreground': '2. Приложение открыто, режим отличается',
    'cross_foreground_hint':
        'Push для другого режима — сохранение + switchAppMode',
    'same_background': '3. Приложение в фоне, режим совпадает',
    'same_background_hint':
        'Pending route stash, применяется при возврате в фокус',
    'cross_background': '4. Приложение в фоне, режим отличается',
    'cross_background_hint': 'Stash + после смены режима применяется',
    'same_cold': '5. Приложение полностью закрыто, режим совпадает',
    'same_cold_hint': 'Cold start: pending route применяется, режим тот же',
    'cross_cold': '6. Приложение полностью закрыто, режим отличается',
    'cross_cold_hint':
        'Cold start: app_mode override + pending route + switchAppMode',
  },
  'view_cta': 'Посмотреть',
  'read_more': 'Подробнее',
  'read_less': 'Свернуть',
  'placeholder_body_with_id':
      'Раздел в разработке — id: {id}\nОтдельный экран появится в следующем обновлении.',
  'placeholder_body': 'Отдельный экран появится в следующем обновлении.',
  'go_home': 'На главную',
  'kind_promo_title': 'Акция',
  'kind_news_title': 'Новости',
  'kind_system_alert_title': 'Системное уведомление',
};

const Map<String, dynamic> notificationsEn = {
  'title': 'Notifications',
  'empty': 'No notifications',
  'empty_hint': 'Order updates, shop news and promos show up here',
  'login_required_title': 'Sign in to see notifications',
  'login_required_message':
      'Log in to receive personal order and account alerts',
  'orders_login_title': 'Order notifications',
  'orders_login_message': 'Sign in to see updates about your orders',
  'login_cta': 'Sign in',
  'mark_all_read': 'Mark all read',
  'tab_all': 'All',
  'tab_orders': 'Orders',
  'tab_system': 'System',
  'tab_empty': 'Nothing in this category yet',
  'simulator_title': 'Push simulator',
  'simulator_link_hint': '6 cross-mode scenarios (debug only)',
  'simulator_hint': 'Current mode: {}. Pick a scenario below.',
  'simulator_done_same_mode': 'Same-mode push — navigated directly',
  'simulator_done_stash': 'Pending route saved — applied on next consume',
  'simulator_done_cold': 'Mode switch + pending route saved (cold start sim)',
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
  'view_cta': 'View',
  'read_more': 'Read more',
  'read_less': 'Show less',
  'placeholder_body_with_id':
      'Placeholder — id: {id}\nThe dedicated screen will be added in a future update.',
  'placeholder_body': 'The dedicated screen will be added in a future update.',
  'go_home': 'Go home',
  'kind_promo_title': 'Promotion',
  'kind_news_title': 'News',
  'kind_system_alert_title': 'System alert',
};
