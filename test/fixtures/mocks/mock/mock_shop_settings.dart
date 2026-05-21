import '../models/multilingual_text.dart';
import '../models/shop_service.dart';
import '../models/shop_service_config.dart';
import '../models/shop_settings.dart';
import '../models/working_hours.dart';
import 'mock_data.dart';
import 'mock_orders_data.dart';

/// Default shop the seller dashboard ships with — pre-filled enough that the
/// shop settings screen is meaningful out of the box even without onboarding
/// being completed.
class MockShopSettings {
  const MockShopSettings._();

  static ShopSettings defaultSettings() {
    final shop = MockData.shops.firstWhere((s) => s.id == 'shop-mh');
    return ShopSettings(
      id: shop.id,
      slug: shop.slug,
      name: shop.name,
      description: shop.description ??
          const MultilingualText(
            uz: 'Yevropadan import qilingan zamonaviy mebellar',
            ru: 'Современная мебель из Европы',
            en: 'Modern furniture imported from Europe',
          ),
      logoUrl: shop.logoUrl,
      coverUrl: 'https://picsum.photos/seed/shop-mh-cover/1200/400',
      contactPhone: shop.contactPhone,
      contactEmail: 'info@mebelhouse.uz',
      telegramUsername: shop.telegramUsername,
      brandColor: '#5E35B1',
      region: MockOrdersData.tashkentCity,
      city: MockOrdersData.tashkentCity,
      district: MockOrdersData.chilanzar,
      streetLine: 'Bunyodkor 24',
      lat: 41.2829,
      lng: 69.2167,
      workingHours: WeeklyHours.weekdays9to6().setDay(
        DayOfWeek.saturday,
        const DayHours(open: '10:00', close: '15:00'),
      ),
    );
  }

  /// Default service set — most of the time `Mebel House` does delivery,
  /// assembly and warranty. Sellers can flip them on the services screen.
  static List<ShopServiceConfig> defaultServices() {
    return [
      const ShopServiceConfig(
        service: ShopService.freeDelivery,
        enabled: true,
        minOrderAmount: 1_500_000,
      ),
      const ShopServiceConfig(
        service: ShopService.assembly,
        enabled: true,
        feeAmount: 250_000,
      ),
      const ShopServiceConfig(
        service: ShopService.warranty,
        enabled: true,
        warrantyMonths: 12,
      ),
      const ShopServiceConfig(
        service: ShopService.installment,
        enabled: false,
        installmentMonths: 6,
      ),
      const ShopServiceConfig(
        service: ShopService.express,
        enabled: false,
        feeAmount: 80_000,
      ),
      const ShopServiceConfig(
        service: ShopService.customOrder,
        enabled: false,
      ),
    ];
  }
}
