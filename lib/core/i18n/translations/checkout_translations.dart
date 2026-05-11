// Checkout flow plus delivery and payment method labels used inside it.

const Map<String, dynamic> checkoutUz = {
  'title': 'Buyurtmani rasmiylashtirish',
  'step_review': 'Buyurtmani tekshiring',
  'step_address': 'Yetkazib berish manzili',
  'step_delivery': 'Yetkazib berish usuli',
  'step_payment': 'To\'lov usuli',
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
};

const Map<String, dynamic> checkoutRu = {
  'title': 'Оформление заказа',
  'step_review': 'Проверьте заказ',
  'step_address': 'Адрес доставки',
  'step_delivery': 'Способ доставки',
  'step_payment': 'Способ оплаты',
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
};

const Map<String, dynamic> checkoutEn = {
  'title': 'Checkout',
  'step_review': 'Review your order',
  'step_address': 'Delivery address',
  'step_delivery': 'Delivery method',
  'step_payment': 'Payment method',
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
  'card': 'Karta orqali',
  'card_disabled': 'Tez orada qo\'shiladi',
};

const Map<String, dynamic> paymentRu = {
  'cash': 'Наличными при получении',
  'cash_hint': 'Оплата курьеру при доставке',
  'card': 'Картой',
  'card_disabled': 'Скоро будет доступно',
};

const Map<String, dynamic> paymentEn = {
  'cash': 'Cash on delivery',
  'cash_hint': 'Pay the courier on delivery',
  'card': 'Card',
  'card_disabled': 'Coming soon',
};
