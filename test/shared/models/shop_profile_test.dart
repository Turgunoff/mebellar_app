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
      });

      expect(shop.name, 'New Mebel');
      expect(shop.isVerified, isTrue);
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
    });
  });
}
