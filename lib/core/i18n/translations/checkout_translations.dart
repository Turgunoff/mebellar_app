// Checkout flow plus delivery and payment method labels used inside it.

const Map<String, dynamic> checkoutUz = {
  'title': 'Buyurtmani rasmiylashtirish',
  'address_required': 'Iltimos, yetkazib berish manzilini kiriting',
  'step_review': 'Buyurtmani tekshiring',
  'step_address': 'Yetkazib berish manzili',
  'step_delivery': 'Yetkazib berish usuli',
  'step_payment': 'To\'lov usuli',
  'deferred_payment_note': 'Sotuvchi manzilni tekshirib yetkazib berish narxini kiritgach, to\'lovni amalga oshirishingiz mumkin.',
  'step_confirm': 'Tasdiqlash',
  'delivery_address': 'Yetkazib berish manzili',
  'delivery_fee': 'Yetkazib berish',
  'items_total': 'Mahsulotlar',
  'total': 'Umumiy',
  'place_order': 'Buyurtma berish',
  'multi_shop_note':
      'Savatchada {} ta do\'kon bor — har biriga alohida buyurtma yaratiladi.',
  'success_title': 'Buyurtma yaratildi!',
  'success_subtitle': '{} ta buyurtma muvaffaqiyatli rasmiylashtirildi.',
  'partial_title': 'Qisman muvaffaqiyat',
  'failure_title': 'Buyurtma yaratilmadi',
  'go_home': 'Asosiy sahifa',
  'appbar_title': 'Rasmiylashtirish',
  'success_multi_title': '{} ta buyurtma qabul qilindi!',
  'success_single_title': 'Buyurtmangiz qabul qilindi!',
  'success_multi_body':
      'Har bir do\'kondan alohida buyurtma joylashtirildi. Sotuvchilar tez orada siz bilan bog\'lanadi.',
  'success_single_body':
      'Buyurtmangiz muvaffaqiyatli joylashtirildi. Tez orada siz bilan bog\'lanamiz.',
  'view_my_orders': 'Buyurtmalarimni ko\'rish',
  'back_to_home': 'Asosiy sahifaga qaytish',
  'address_enter_prompt': 'Manzilni kiriting...',
  'address_select_hint': 'Yetkazib berish manzilini tanlang',
  'address_required_inline': 'Buyurtma uchun manzil talab qilinadi',
  'order_count_header': '{} ta buyurtma',
  'order_contents_header': 'Buyurtma tarkibi',
  'multi_shop_fees_note':
      'Har bir do\'kon uchun yetkazib berish va o\'rnatish alohida hisoblanadi',
  'order_index_label': 'Buyurtma {}',
  'group_total': 'Jami',
  'delivery_free': 'Tekin',
  'delivery_seller_sets': 'Sotuvchi belgilaydi',
  'order_summary_header': 'Buyurtma jami',
  'want_installation': 'Ustamiz o\'rnatib berishini xohlaysizmi?',
  'confirm_order': 'Buyurtmani tasdiqlash',
};

const Map<String, dynamic> checkoutRu = {
  'title': 'Оформление заказа',
  'address_required': 'Пожалуйста, укажите адрес доставки',
  'step_review': 'Проверьте заказ',
  'step_address': 'Адрес доставки',
  'step_delivery': 'Способ доставки',
  'step_payment': 'Способ оплаты',
  'deferred_payment_note': 'Оплатить можно после того, как продавец проверит адрес и укажет стоимость доставки.',
  'step_confirm': 'Подтверждение',
  'delivery_address': 'Адрес доставки',
  'delivery_fee': 'Доставка',
  'items_total': 'Товары',
  'total': 'Итого',
  'place_order': 'Оформить заказ',
  'multi_shop_note':
      'В корзине {} магазинов — для каждого создаётся отдельный заказ.',
  'success_title': 'Заказ оформлен!',
  'success_subtitle': 'Успешно создано {} заказов.',
  'partial_title': 'Частичный успех',
  'failure_title': 'Не удалось оформить заказ',
  'go_home': 'На главную',
  'appbar_title': 'Оформление',
  'success_multi_title': 'Принято заказов: {}!',
  'success_single_title': 'Ваш заказ принят!',
  'success_multi_body':
      'По каждому магазину оформлен отдельный заказ. Продавцы свяжутся с вами в ближайшее время.',
  'success_single_body':
      'Ваш заказ успешно оформлен. Мы свяжемся с вами в ближайшее время.',
  'view_my_orders': 'Посмотреть мои заказы',
  'back_to_home': 'Вернуться на главную',
  'address_enter_prompt': 'Укажите адрес...',
  'address_select_hint': 'Выберите адрес доставки',
  'address_required_inline': 'Для оформления заказа нужен адрес',
  'order_count_header': 'Заказов: {}',
  'order_contents_header': 'Состав заказа',
  'multi_shop_fees_note':
      'Доставка и установка рассчитываются отдельно для каждого магазина',
  'order_index_label': 'Заказ {}',
  'group_total': 'Итого',
  'delivery_free': 'Бесплатно',
  'delivery_seller_sets': 'Устанавливает продавец',
  'order_summary_header': 'Итого по заказу',
  'want_installation': 'Хотите, чтобы наш мастер выполнил установку?',
  'confirm_order': 'Подтвердить заказ',
};

const Map<String, dynamic> checkoutEn = {
  'title': 'Checkout',
  'address_required': 'Please enter a delivery address',
  'step_review': 'Review your order',
  'step_address': 'Delivery address',
  'step_delivery': 'Delivery method',
  'step_payment': 'Payment method',
  'deferred_payment_note': 'You can pay once the seller checks the address and enters the delivery fee.',
  'step_confirm': 'Confirm',
  'delivery_address': 'Delivery address',
  'delivery_fee': 'Delivery',
  'items_total': 'Items',
  'total': 'Total',
  'place_order': 'Place order',
  'multi_shop_note':
      'Cart contains {} shops — a separate order is created for each.',
  'success_title': 'Order placed!',
  'success_subtitle': 'Successfully created {} order(s).',
  'partial_title': 'Partial success',
  'failure_title': 'Order failed',
  'go_home': 'Go home',
  'appbar_title': 'Checkout',
  'success_multi_title': '{} orders accepted!',
  'success_single_title': 'Your order has been accepted!',
  'success_multi_body':
      'A separate order was placed for each shop. The sellers will contact you shortly.',
  'success_single_body':
      'Your order was placed successfully. We will contact you shortly.',
  'view_my_orders': 'View my orders',
  'back_to_home': 'Back to home',
  'address_enter_prompt': 'Enter address...',
  'address_select_hint': 'Select a delivery address',
  'address_required_inline': 'An address is required for the order',
  'order_count_header': '{} orders',
  'order_contents_header': 'Order contents',
  'multi_shop_fees_note':
      'Delivery and installation are calculated separately for each shop',
  'order_index_label': 'Order {}',
  'group_total': 'Total',
  'delivery_free': 'Free',
  'delivery_seller_sets': 'Set by seller',
  'order_summary_header': 'Order total',
  'want_installation': 'Would you like our specialist to install it?',
  'confirm_order': 'Confirm order',
};

const Map<String, dynamic> deliveryUz = {
  'standard': 'Standart yetkazib berish',
  'standard_hint': '2-3 kun, 50 000 so\'m',
  'express': 'Tezkor yetkazib berish',
  'express_hint': 'Bir kun ichida, 80 000 so\'m',
  'pickup': 'Do\'kondan olib ketish',
  'pickup_hint': 'Bepul, manzil — do\'kon ofisi',
};

const Map<String, dynamic> deliveryRu = {
  'standard': 'Стандартная доставка',
  'standard_hint': '2-3 дня, 50 000 сум',
  'express': 'Экспресс доставка',
  'express_hint': 'В течение дня, 80 000 сум',
  'pickup': 'Самовывоз',
  'pickup_hint': 'Бесплатно, в офисе магазина',
};

const Map<String, dynamic> deliveryEn = {
  'standard': 'Standard delivery',
  'standard_hint': '2-3 days, 50,000 UZS',
  'express': 'Express delivery',
  'express_hint': 'Same day, 80,000 UZS',
  'pickup': 'Pickup',
  'pickup_hint': "Free, at the shop's office",
};

const Map<String, dynamic> paymentUz = {
  'cash': 'Qabul qilganda naqd',
  'cash_hint': 'Yetkazib bergan kuriyerga to\'lov',
  'pay_with_payme': 'Payme ilovasi orqali to\'lash',
  'pay_with_click': 'Click ilovasi orqali to\'lash',
  // Pending external-payment reconciliation (PaymentRecoveryGate).
  'recovery': {
    'checking': 'To\'lov holati tekshirilmoqda...',
    'paid_title': 'To\'lov muvaffaqiyatli!',
    'pending_title': 'To\'lov jarayonda',
    'paid_body_order': 'Buyurtmangiz uchun to\'lov qabul qilindi.',
    'paid_body_account': 'To\'lovingiz muvaffaqiyatli qabul qilindi.',
    'pending_body_order':
        'To\'lov hali tasdiqlanmadi yoki jarayonda. Buni Buyurtmalar bo\'limida kuzatishingiz mumkin.',
    'pending_body_account':
        'To\'lov hali tasdiqlanmadi. Tasdiqlash biroz vaqt olishi mumkin.',
    // Cold-start (app was killed during payment) variants.
    'cold_paid_title': 'To\'lov qabul qilindi!',
    'cold_pending_title': 'To\'lov holati',
    'cold_paid_body_order':
        'Oxirgi buyurtmangiz uchun to\'lov muvaffaqiyatli qabul qilindi!',
    'cold_paid_body_account':
        'Oxirgi to\'lovingiz muvaffaqiyatli qabul qilindi!',
    'cold_pending_body_order':
        'Oxirgi to\'lovingiz amalga oshmagan ko\'rinadi. Iltimos, Buyurtmalar bo\'limini tekshiring.',
    'cold_pending_body_account':
        'Oxirgi to\'lovingiz amalga oshmagan ko\'rinadi. Hisobingizni tekshiring.',
    'view_orders': 'Buyurtmalarni ko\'rish',
    'dismiss': 'Yopish',
  },
};

const Map<String, dynamic> paymentRu = {
  'cash': 'Наличными при получении',
  'cash_hint': 'Оплата курьеру при доставке',
  'pay_with_payme': 'Оплатить через приложение Payme',
  'pay_with_click': 'Оплатить через приложение Click',
  'recovery': {
    'checking': 'Проверяем статус оплаты...',
    'paid_title': 'Оплата прошла успешно!',
    'pending_title': 'Оплата обрабатывается',
    'paid_body_order': 'Оплата вашего заказа принята.',
    'paid_body_account': 'Ваш платёж успешно принят.',
    'pending_body_order':
        'Оплата ещё не подтверждена или обрабатывается. Вы можете отследить её в разделе «Заказы».',
    'pending_body_account':
        'Оплата ещё не подтверждена. Подтверждение может занять некоторое время.',
    'cold_paid_title': 'Оплата принята!',
    'cold_pending_title': 'Статус оплаты',
    'cold_paid_body_order': 'Оплата вашего последнего заказа успешно принята!',
    'cold_paid_body_account': 'Ваш последний платёж успешно принят!',
    'cold_pending_body_order':
        'Похоже, ваш последний платёж не прошёл. Пожалуйста, проверьте раздел «Заказы».',
    'cold_pending_body_account':
        'Похоже, ваш последний платёж не прошёл. Проверьте свой счёт.',
    'view_orders': 'Перейти к заказам',
    'dismiss': 'Закрыть',
  },
};

const Map<String, dynamic> paymentEn = {
  'cash': 'Cash on delivery',
  'cash_hint': 'Pay the courier on delivery',
  'pay_with_payme': 'Pay with the Payme app',
  'pay_with_click': 'Pay with the Click app',
  'recovery': {
    'checking': 'Checking payment status...',
    'paid_title': 'Payment successful!',
    'pending_title': 'Payment processing',
    'paid_body_order': 'Payment for your order has been received.',
    'paid_body_account': 'Your payment was received successfully.',
    'pending_body_order':
        "Payment isn't confirmed yet or is still processing. You can track it in the Orders section.",
    'pending_body_account':
        "Payment isn't confirmed yet. Confirmation may take a little while.",
    'cold_paid_title': 'Payment received!',
    'cold_pending_title': 'Payment status',
    'cold_paid_body_order':
        'Payment for your last order was received successfully!',
    'cold_paid_body_account': 'Your last payment was received successfully!',
    'cold_pending_body_order':
        "Your last payment doesn't seem to have gone through. Please check the Orders section.",
    'cold_pending_body_account':
        "Your last payment doesn't seem to have gone through. Please check your account.",
    'view_orders': 'View orders',
    'dismiss': 'Close',
  },
};
