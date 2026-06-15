// Common UI strings, generic errors, and language names. Shared across both
// customer and seller modes — kept together because they're trivially small
// and used everywhere.

const Map<String, dynamic> commonUz = {
  'save': 'Saqlash',
  'cancel': 'Bekor qilish',
  'loading': 'Yuklanmoqda...',
  'retry': 'Qayta urinish',
  'back': 'Orqaga',
  'next': 'Keyingi',
  'done': 'Tayyor',
  'skip': 'O\'tkazib yuborish',
  'ok': 'OK',
  'close': 'Yopish',
  'yes': 'Ha',
  'no': 'Yo\'q',
  'all': 'Hammasi',
};

const Map<String, dynamic> commonRu = {
  'save': 'Сохранить',
  'cancel': 'Отмена',
  'loading': 'Загрузка...',
  'retry': 'Повторить',
  'back': 'Назад',
  'next': 'Далее',
  'done': 'Готово',
  'skip': 'Пропустить',
  'ok': 'ОК',
  'close': 'Закрыть',
  'yes': 'Да',
  'no': 'Нет',
  'all': 'Все',
};

const Map<String, dynamic> commonEn = {
  'save': 'Save',
  'cancel': 'Cancel',
  'loading': 'Loading...',
  'retry': 'Retry',
  'back': 'Back',
  'next': 'Next',
  'done': 'Done',
  'skip': 'Skip',
  'ok': 'OK',
  'close': 'Close',
  'yes': 'Yes',
  'no': 'No',
  'all': 'All',
};

const Map<String, dynamic> errorUz = {
  'network': 'Tarmoq xatosi. Internet aloqasini tekshiring',
  'server': 'Server xatosi. Birozdan keyin urinib ko\'ring',
  'unknown': 'Xatolik yuz berdi',
  'validation_error': 'Noto\'g\'ri ma\'lumot',
  'rate_limited': 'Juda ko\'p so\'rov. Birozdan keyin urinib ko\'ring',
  'forbidden': 'Bu amalga ruxsat yo\'q',
  'product_unavailable': 'Mahsulot hozir mavjud emas',
  'seller_unavailable': 'Sotuvchi hozir buyurtma qabul qila olmaydi',
  'order_not_delivered': 'Buyurtma yetkazilgandan keyin baholay olasiz',
  'already_reviewed': 'Siz bu mahsulotni allaqachon baholagansiz',
  'multi_shop_cart': 'Har do\'kon mahsulotlari alohida buyurtma qilinadi',
  'attachment_invalid': 'Rasmni yuborib bo\'lmadi. Qaytadan urinib ko\'ring',
  'wallet_suspended': 'Hisobingiz qarz tufayli vaqtincha muzlatilgan',
};

const Map<String, dynamic> errorRu = {
  'network': 'Ошибка сети. Проверьте подключение к интернету',
  'server': 'Ошибка сервера. Попробуйте позже',
  'unknown': 'Произошла ошибка',
  'validation_error': 'Некорректные данные',
  'rate_limited': 'Слишком много запросов. Попробуйте позже',
  'forbidden': 'Нет доступа к этому действию',
  'product_unavailable': 'Товар сейчас недоступен',
  'seller_unavailable': 'Продавец сейчас не может принять заказ',
  'order_not_delivered': 'Оставить отзыв можно после доставки заказа',
  'already_reviewed': 'Вы уже оставили отзыв на этот товар',
  'multi_shop_cart': 'Товары каждого магазина оформляются отдельным заказом',
  'attachment_invalid': 'Не удалось отправить изображение. Попробуйте снова',
  'wallet_suspended': 'Ваш счёт временно заморожен из-за задолженности',
};

const Map<String, dynamic> errorEn = {
  'network': 'Network error. Check your internet connection',
  'server': 'Server error. Please try again later',
  'unknown': 'Something went wrong',
  'validation_error': 'Invalid input',
  'rate_limited': 'Too many requests. Please try again later',
  'forbidden': 'You don\'t have access to this action',
  'product_unavailable': 'This product is currently unavailable',
  'seller_unavailable': 'The seller can\'t take orders right now',
  'order_not_delivered': 'You can leave a review after the order is delivered',
  'already_reviewed': 'You\'ve already reviewed this product',
  'multi_shop_cart': 'Items from each shop are ordered separately',
  'attachment_invalid': 'Couldn\'t send the image. Please try again',
  'wallet_suspended': 'Your account is temporarily frozen due to debt',
};

const Map<String, dynamic> langUz = {
  'uz': 'O\'zbekcha',
  'ru': 'Русский',
  'en': 'English',
};

const Map<String, dynamic> langRu = {
  'uz': 'O\'zbekcha',
  'ru': 'Русский',
  'en': 'English',
};

const Map<String, dynamic> langEn = {
  'uz': 'O\'zbekcha',
  'ru': 'Русский',
  'en': 'English',
};
