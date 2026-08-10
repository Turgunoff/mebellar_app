import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/connectivity/network_cubit.dart';
import 'package:woody_app/core/di/service_locator.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/storage/app_settings.dart';
import 'package:woody_app/customer/features/product_list/cubit/product_list_cubit.dart';
import 'package:woody_app/customer/features/product_list/screens/product_list_screen.dart';
import 'package:woody_app/customer/widgets/view_mode_toggle.dart';
import 'package:woody_app/shared/widgets/error_state.dart';

/// Pins the product-list failure UI on the shared [ErrorState] widget while
/// keeping this screen's contextual title override
/// ("Mahsulotlarni yuklab bo'lmadi") intact.
class _MockProductListCubit extends MockCubit<ProductListState>
    implements ProductListCubit {}

class _MockNetworkCubit extends MockCubit<NetworkStatus>
    implements NetworkCubit {}

class _MockAppSettings extends Mock implements AppSettings {}

void main() {
  setUpAll(() {
    AppTranslations.setInstance(AppTranslations.forLocale(const Locale('uz')));
  });

  late _MockProductListCubit cubit;
  late _MockNetworkCubit networkCubit;

  setUp(() {
    cubit = _MockProductListCubit();
    networkCubit = _MockNetworkCubit();
    whenListen(
      networkCubit,
      const Stream<NetworkStatus>.empty(),
      initialState: NetworkStatus.online,
    );

    // ProductListScreen reads this DI singleton in its State's field
    // initializer (before build), so it must be registered even though the
    // failure branch under test never touches the toggle itself.
    final settings = _MockAppSettings();
    when(() => settings.productViewModeName).thenReturn('grid');
    when(
      () => settings.setProductViewModeName(any()),
    ).thenAnswer((_) async {});
    sl.registerSingleton<ProductViewModeController>(
      ProductViewModeController(settings),
    );
  });

  tearDown(() => sl.reset());

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ProductListCubit>.value(value: cubit),
            BlocProvider<NetworkCubit>.value(value: networkCubit),
          ],
          child: const ProductListScreen(
            categoryId: 'cat-1',
            categoryName: 'Divanlar',
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    "failure state renders ErrorState with the screen's contextual title",
    (tester) async {
      whenListen(
        cubit,
        const Stream<ProductListState>.empty(),
        initialState: const ProductListState(
          status: ProductListStatus.failure,
          error: 'Tarmoq xatosi',
        ),
      );

      await pumpScreen(tester);

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text("Mahsulotlarni yuklab bo'lmadi"), findsOneWidget);
    },
  );
}
