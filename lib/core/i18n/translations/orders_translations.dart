// Customer-facing orders list and the shared order_status enum labels.

const Map<String, dynamic> ordersUz = {
  'title': 'Buyurtmalar',
  'tab_all': 'Barchasi',
  'tab_active': 'Aktiv',
  'tab_completed': 'Yetkazilgan',
  'tab_cancelled': 'Bekor qilingan',
  'empty': 'Hali buyurtma yo\'q',
  'empty_hint': 'Mahsulot tanlang va birinchi buyurtmangizni yarating',
  'items': 'Mahsulotlar',
  'timeline': 'Buyurtma holati',
  'expected': 'Yetkaziladi: {}',
  'cancel': 'Bekor qilish',
  'cancel_title': 'Buyurtmani bekor qilasizmi?',
  'cancel_subtitle': 'Sababni yozib qoldiring (ixtiyoriy):',
  'cancel_reason': 'Bekor qilish sababi',
  'cancel_reason_hint': 'Masalan: Boshqa do\'kondan oldim',
  'cancel_reason_default': 'Sababsiz',
  'realtime': 'Onlayn',
};

const Map<String, dynamic> ordersRu = {
  'title': 'Заказы',
  'tab_all': 'Все',
  'tab_active': 'Активные',
  'tab_completed': 'Доставленные',
  'tab_cancelled': 'Отменённые',
  'empty': 'Заказов пока нет',
  'empty_hint': 'Выберите товар и оформите первый заказ',
  'items': 'Товары',
  'timeline': 'Статус заказа',
  'expected': 'Доставка: {}',
  'cancel': 'Отменить',
  'cancel_title': 'Отменить заказ?',
  'cancel_subtitle': 'Укажите причину (опционально):',
  'cancel_reason': 'Причина отмены',
  'cancel_reason_hint': 'Например: Купил в другом магазине',
  'cancel_reason_default': 'Без причины',
  'realtime': 'Онлайн',
};

const Map<String, dynamic> ordersEn = {
  'title': 'Orders',
  'tab_all': 'All',
  'tab_active': 'Active',
  'tab_completed': 'Delivered',
  'tab_cancelled': 'Cancelled',
  'empty': 'No orders yet',
  'empty_hint': 'Pick a product and place your first order',
  'items': 'Items',
  'timeline': 'Order status',
  'expected': 'Expected: {}',
  'cancel': 'Cancel',
  'cancel_title': 'Cancel this order?',
  'cancel_subtitle': 'Optionally tell us why:',
  'cancel_reason': 'Cancel reason',
  'cancel_reason_hint': 'e.g. Bought it elsewhere',
  'cancel_reason_default': 'No reason',
  'realtime': 'Live',
};

const Map<String, dynamic> orderStatusUz = {
  'pending': 'Kutilmoqda',
  'confirmed': 'Tasdiqlandi',
  'preparing': 'Tayyorlanmoqda',
  'shipped': 'Yo\'lda',
  'delivered': 'Yetkazildi',
  'cancelled': 'Bekor qilingan',
};

const Map<String, dynamic> orderStatusRu = {
  'pending': 'Ожидает',
  'confirmed': 'Подтверждён',
  'preparing': 'Готовится',
  'shipped': 'В пути',
  'delivered': 'Доставлен',
  'cancelled': 'Отменён',
};

const Map<String, dynamic> orderStatusEn = {
  'pending': 'Pending',
  'confirmed': 'Confirmed',
  'preparing': 'Preparing',
  'shipped': 'Shipped',
  'delivered': 'Delivered',
  'cancelled': 'Cancelled',
};
