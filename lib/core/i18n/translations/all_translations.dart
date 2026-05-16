// Aggregates per-domain translation maps into the three flat bundles consumed
// by [AppTranslations]. Add a new domain in two places: import its file here,
// then map the top-level key in each language map below. Order matches the
// legacy translations_<lang>.dart files so diffs stay readable.

import 'address_translations.dart';
import 'auth_translations.dart';
import 'beta_translations.dart';
import 'cart_translations.dart';
import 'catalog_translations.dart';
import 'checkout_translations.dart';
import 'common_translations.dart';
import 'home_translations.dart';
import 'mode_translations.dart';
import 'notifications_translations.dart';
import 'onboarding_translations.dart';
import 'orders_translations.dart';
import 'product_translations.dart';
import 'seller_orders_translations.dart';
import 'seller_translations.dart';
import 'shop_settings_translations.dart';
import 'shop_translations.dart';
import 'system_translations.dart';
import 'tariff_translations.dart';
import 'tutorial_translations.dart';

const Map<String, dynamic> uzTranslations = {
  'common': commonUz,
  'auth': authUz,
  'beta': betaUz,
  'mode': modeUz,
  'home': homeUz,
  'catalog': catalogUz,
  'search': searchUz,
  'product': productUz,
  'shop': shopUz,
  'cart': cartUz,
  'favorites': favoritesUz,
  'attributes': attributesUz,
  'address': addressUz,
  'region': regionUz,
  'checkout': checkoutUz,
  'delivery': deliveryUz,
  'payment': paymentUz,
  'orders': ordersUz,
  'order_status': orderStatusUz,
  'seller_orders': sellerOrdersUz,
  'shop_settings': shopSettingsUz,
  'services': servicesUz,
  'day': dayUz,
  'seller': sellerUz,
  'seller_product_status': sellerProductStatusUz,
  'dashboard': dashboardUz,
  'analytics': analyticsUz,
  'tariff': tariffUz,
  'onboarding': onboardingUz,
  'business_type': businessTypeUz,
  'verification': verificationUz,
  'profile': profileUz,
  'notifications': notificationsUz,
  'offline': offlineUz,
  'deep_links': deepLinksUz,
  'tutorial': tutorialUz,
  'error': errorUz,
  'lang': langUz,
};

const Map<String, dynamic> ruTranslations = {
  'common': commonRu,
  'auth': authRu,
  'beta': betaRu,
  'mode': modeRu,
  'home': homeRu,
  'catalog': catalogRu,
  'search': searchRu,
  'product': productRu,
  'shop': shopRu,
  'cart': cartRu,
  'favorites': favoritesRu,
  'attributes': attributesRu,
  'address': addressRu,
  'region': regionRu,
  'checkout': checkoutRu,
  'delivery': deliveryRu,
  'payment': paymentRu,
  'orders': ordersRu,
  'order_status': orderStatusRu,
  'seller_orders': sellerOrdersRu,
  'shop_settings': shopSettingsRu,
  'services': servicesRu,
  'day': dayRu,
  'seller': sellerRu,
  'seller_product_status': sellerProductStatusRu,
  'dashboard': dashboardRu,
  'analytics': analyticsRu,
  'tariff': tariffRu,
  'onboarding': onboardingRu,
  'business_type': businessTypeRu,
  'verification': verificationRu,
  'profile': profileRu,
  'notifications': notificationsRu,
  'offline': offlineRu,
  'deep_links': deepLinksRu,
  'tutorial': tutorialRu,
  'error': errorRu,
  'lang': langRu,
};

const Map<String, dynamic> enTranslations = {
  'common': commonEn,
  'auth': authEn,
  'beta': betaEn,
  'mode': modeEn,
  'home': homeEn,
  'catalog': catalogEn,
  'search': searchEn,
  'product': productEn,
  'shop': shopEn,
  'cart': cartEn,
  'favorites': favoritesEn,
  'attributes': attributesEn,
  'address': addressEn,
  'region': regionEn,
  'checkout': checkoutEn,
  'delivery': deliveryEn,
  'payment': paymentEn,
  'orders': ordersEn,
  'order_status': orderStatusEn,
  'seller_orders': sellerOrdersEn,
  'shop_settings': shopSettingsEn,
  'services': servicesEn,
  'day': dayEn,
  'seller': sellerEn,
  'seller_product_status': sellerProductStatusEn,
  'dashboard': dashboardEn,
  'analytics': analyticsEn,
  'tariff': tariffEn,
  'onboarding': onboardingEn,
  'business_type': businessTypeEn,
  'verification': verificationEn,
  'profile': profileEn,
  'notifications': notificationsEn,
  'offline': offlineEn,
  'deep_links': deepLinksEn,
  'tutorial': tutorialEn,
  'error': errorEn,
  'lang': langEn,
};
