import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/analytics/analytics_service.dart';
import 'package:woody_app/core/analytics/noop_analytics_service.dart';
import 'package:woody_app/core/auth/auth_cubit.dart';
import 'package:woody_app/core/di/service_locator.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/result/result.dart';
import 'package:woody_app/customer/features/cart/bloc/cart_bloc.dart';
import 'package:woody_app/customer/features/favorites/bloc/favorites_bloc.dart';
import 'package:woody_app/customer/features/product_list/screens/catalog_product_detail_screen.dart';
import 'package:woody_app/seller/features/products/data/attributes_repository.dart';
import 'package:woody_app/shared/models/attribute_definition.dart';
import 'package:woody_app/shared/models/attribute_option.dart';
import 'package:woody_app/shared/models/product_model.dart';
import 'package:woody_app/shared/repositories/customer_reviews_repository.dart';
import 'package:woody_app/shared/repositories/product_data_source.dart';

/// Pins the customer product-detail render: with the (now public) attribute
/// schema loaded, a furniture-set product must show the grouped "O'lchamlar
/// (sm)" card with Uzbek piece/measure labels and resolve attribute keys to
/// their Uzbek labels — NOT the humanised English raw keys the screen falls
/// back to when the schema is missing (the bug this whole change fixes).
class _MockCartBloc extends MockBloc<CartEvent, CartState> implements CartBloc {}

class _MockFavoritesBloc extends MockBloc<FavoritesEvent, FavoritesState>
    implements FavoritesBloc {}

class _MockAuthCubit extends MockCubit<AppAuthState> implements AuthCubit {}

/// `reviewsForProduct` stays pending forever so the reviews FutureBuilder
/// renders nothing — keeps the test focused on the attribute/dimension cards.
class _MockReviewsRepo extends Mock implements CustomerReviewsRepository {}

class _FakeAttributesRepository implements AttributesRepository {
  _FakeAttributesRepository(this.defs, {this.shouldThrow = false});

  final List<AttributeDefinition> defs;
  final bool shouldThrow;

  @override
  Future<List<AttributeDefinition>> loadForCategory({
    required String categoryId,
    String? subcategoryId,
  }) async {
    if (shouldThrow) throw Exception('schema load failed');
    return defs;
  }
}

AttributeDefinition _dimDef(String key, String labelUz) => AttributeDefinition(
  id: key,
  categoryId: 'cat-1',
  subcategoryId: null,
  key: key,
  labelUz: labelUz,
  labelRu: labelUz,
  dataType: AttributeDataType.number,
  // unit 'sm' + an em-dash label is what marks a per-piece dimension attribute
  // (see DimensionsCard.isDimensionAttribute), grouping it into the card.
  unit: 'sm',
  isRequired: false,
  sortOrder: 0,
);

void main() {
  setUpAll(() {
    // The bottom bar's CTAs use tr(); init so the self-purchase copy resolves.
    AppTranslations.setInstance(AppTranslations.forLocale(const Locale('uz')));
  });

  late _MockCartBloc cart;
  late _MockFavoritesBloc favorites;
  late _MockAuthCubit auth;

  // A bedroom set: two per-piece bed dimensions + one select attribute. Owned
  // by seller 'u-7' so the self-purchase test can match the logged-in user.
  final product = ProductModel(
    id: 'p1',
    categoryId: 'cat-1',
    sellerId: 'u-7',
    name: "LONDON yotoq to'plami",
    price: 1000000,
    images: const [],
    stock: 5,
    createdAt: DateTime(2026, 1, 1),
    attributes: const {
      'bed_width_cm': 220,
      'bed_height_cm': 130,
      'frame_material': 'mdf',
    },
  );

  final schema = <AttributeDefinition>[
    _dimDef('bed_width_cm', 'Krovat — Kengligi'),
    _dimDef('bed_height_cm', 'Krovat — Balandligi'),
    const AttributeDefinition(
      id: 'frame_material',
      categoryId: 'cat-1',
      subcategoryId: null,
      key: 'frame_material',
      labelUz: 'Karkas materiali',
      labelRu: 'Karkas materiali',
      dataType: AttributeDataType.select,
      unit: null,
      isRequired: false,
      sortOrder: 1,
      options: [
        AttributeOption(
          id: 'o1',
          attributeId: 'frame_material',
          value: 'mdf',
          labelUz: 'MDF',
          labelRu: 'MDF',
          sortOrder: 0,
        ),
      ],
    ),
  ];

  void registerCommon() {
    final reviews = _MockReviewsRepo();
    when(
      () => reviews.reviewsForProduct(any()),
    ).thenAnswer((_) => Completer<Result<ProductReviewSummary>>().future);
    sl.registerSingleton<AnalyticsService>(const NoopAnalyticsService());
    sl.registerSingleton<ProductDataSource>(MockProductDataSource());
    sl.registerSingleton<CustomerReviewsRepository>(reviews);
  }

  setUp(() {
    cart = _MockCartBloc();
    favorites = _MockFavoritesBloc();
    auth = _MockAuthCubit();
    whenListen(
      cart,
      const Stream<CartState>.empty(),
      initialState: const CartState(),
    );
    whenListen(
      favorites,
      const Stream<FavoritesState>.empty(),
      initialState: const FavoritesState(),
    );
    // Default: a guest — the buy CTA stays normal. The self-purchase test
    // overrides this with an authenticated owner before pumping.
    whenListen(
      auth,
      const Stream<AppAuthState>.empty(),
      initialState: const AppAuthUnauthenticated(),
    );
  });

  tearDown(() => sl.reset());

  Future<void> pumpScreen(WidgetTester tester) async {
    // Tall viewport so the full sliver tree (collapsing app bar + every content
    // card) lays out within one screen — otherwise the cards sit below the fold
    // in the CustomScrollView and aren't built for `find.text`.
    tester.view.physicalSize = const Size(500, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<CartBloc>.value(value: cart),
              BlocProvider<FavoritesBloc>.value(value: favorites),
              BlocProvider<AuthCubit>.value(value: auth),
            ],
            child: CatalogProductDetailScreen(product: product),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(); // resolve the schema future + setState
    await tester.pump(const Duration(milliseconds: 500)); // drain similar timer
  }

  testWidgets('renders the grouped dimensions card with Uzbek labels', (
    tester,
  ) async {
    registerCommon();
    sl.registerSingleton<AttributesRepository>(
      _FakeAttributesRepository(schema),
    );

    await pumpScreen(tester);

    // Grouped per-piece dimensions card with its Uzbek headers/measures.
    expect(find.text("O'lchamlar (sm)"), findsOneWidget);
    expect(find.text('Krovat'), findsOneWidget);
    expect(find.text('Kengligi'), findsOneWidget);
    expect(find.text('220 sm'), findsOneWidget);
    // Select attribute resolved to its Uzbek label + option, not the raw key.
    expect(find.text('Karkas materiali'), findsOneWidget);
    expect(find.text('MDF'), findsOneWidget);
    // The humanised English raw key must NOT appear anywhere.
    expect(find.text('Bed width cm'), findsNothing);
  });

  testWidgets('degrades gracefully when the schema fails to load', (
    tester,
  ) async {
    registerCommon();
    sl.registerSingleton<AttributesRepository>(
      _FakeAttributesRepository(const [], shouldThrow: true),
    );

    await pumpScreen(tester);

    // No schema → the grouped dimensions card cannot be built…
    expect(find.text("O'lchamlar (sm)"), findsNothing);
    // …but the screen still renders (no crash) and falls back to the flat
    // humanised key rather than throwing.
    expect(find.byType(CatalogProductDetailScreen), findsOneWidget);
    expect(find.text('Bed width cm'), findsOneWidget);
  });

  testWidgets('greys out the buy CTA on the viewer\'s OWN product', (
    tester,
  ) async {
    registerCommon();
    sl.registerSingleton<AttributesRepository>(
      _FakeAttributesRepository(const []),
    );
    // The logged-in user IS the product's seller (sellerId 'u-7').
    whenListen(
      auth,
      const Stream<AppAuthState>.empty(),
      initialState: const AppAuthAuthenticated('u-7'),
    );

    await pumpScreen(tester);

    // The disabled "your own product" CTA replaces the add-to-cart button.
    expect(find.text("O'zingizning mahsulotingiz"), findsOneWidget);
    expect(find.text("Savatchaga qo'shish"), findsNothing);
  });

  testWidgets('keeps the normal add-to-cart CTA for a different user', (
    tester,
  ) async {
    registerCommon();
    sl.registerSingleton<AttributesRepository>(
      _FakeAttributesRepository(const []),
    );
    whenListen(
      auth,
      const Stream<AppAuthState>.empty(),
      initialState: const AppAuthAuthenticated('someone-else'),
    );

    await pumpScreen(tester);

    expect(find.text("O'zingizning mahsulotingiz"), findsNothing);
    expect(find.text("Savatchaga qo'shish"), findsOneWidget);
  });
}
