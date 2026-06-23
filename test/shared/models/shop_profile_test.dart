import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/shared/models/shop_profile.dart';
import 'package:woody_app/shared/models/working_hours.dart';

void main() {
  group('ShopProfile.fromJson', () {
    test('parses the full enriched public payload', () {
      final shop = ShopProfile.fromJson({
        'id': 'shop-1',
        'name': 'New Mebel',
        'description': 'Zamonaviy mebellar',
        'logo_url': 'https://example.com/logo.png',
        'cover_url': 'https://example.com/cover.png',
        'brand_color': '#C27A5F',
        'contact_phone': '+998901234567',
        'telegram_username': 'newmebel',
        'is_verified': true,
        'address': 'Toshkent, Chilonzor',
        'latitude': 41.31,
        'longitude': 69.24,
        'working_hours': {
          'monday': {'open': '09:00', 'close': '18:00', 'closed': false},
        },
        'created_at': '2024-06-01T00:00:00Z',
        'product_count': 12,
        'rating': 4.5,
        'review_count': 8,
        'unlocked_achievements': [
          {
            'code': 'first_sale',
            'title_uz': 'Birinchi savdo',
            'title_ru': 'Первая продажа',
            'description_uz': 'Do\'kon birinchi savdosini amalga oshirdi',
            'icon': 'medal',
          },
          {
            'code': 'ten_products',
            'title_uz': '10 ta mahsulot',
            'title_ru': '10 товаров',
            'icon': 'box',
          },
        ],
      });

      expect(shop.name, 'New Mebel');
      expect(shop.isVerified, isTrue);
      expect(shop.unlockedAchievements, hasLength(2));
      expect(shop.unlockedAchievements.first.code, 'first_sale');
      expect(shop.unlockedAchievements.first.icon, 'medal');
      expect(
        shop.unlockedAchievements.first.descriptionUz,
        "Do'kon birinchi savdosini amalga oshirdi",
      );
      expect(shop.unlockedAchievements[1].descriptionUz, isNull);
      expect(shop.hasPhone, isTrue);
      expect(shop.hasTelegram, isTrue);
      expect(shop.hasAddress, isTrue);
      expect(shop.hasLocation, isTrue);
      expect(shop.hasRating, isTrue);
      expect(shop.rating, 4.5);
      expect(shop.reviewCount, 8);
      expect(shop.productCount, 12);
      expect(shop.createdAt?.year, 2024);
      expect(shop.workingHours[DayOfWeek.monday].open, '09:00');
      expect(shop.workingHours.hasAnyOpenDay, isTrue);
    });

    test('a bare payload with no reviews leaves rating null', () {
      final shop = ShopProfile.fromJson({
        'id': 'shop-2',
        'name': 'Solo',
        'is_verified': false,
        'product_count': 0,
        'review_count': 0,
        'working_hours': null,
      });

      expect(shop.hasRating, isFalse);
      expect(shop.rating, isNull);
      expect(shop.hasPhone, isFalse);
      expect(shop.hasTelegram, isFalse);
      expect(shop.hasLocation, isFalse);
      expect(shop.workingHours.hasAnyOpenDay, isFalse);
      expect(shop.unlockedAchievements, isEmpty);
    });
  });
}
