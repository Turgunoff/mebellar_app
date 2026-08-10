import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woody_app/core/connectivity/network_cubit.dart';
import 'package:woody_app/core/di/service_locator.dart';
import 'package:woody_app/core/storage/app_settings.dart';
import 'package:woody_app/customer/customer_app.dart';
import 'package:woody_app/customer/features/home/bloc/home_bloc.dart';
import 'package:woody_app/customer/features/home/screens/home_screen.dart';
import 'package:woody_app/customer/features/notifications/cubit/notifications_cubit.dart';
import 'package:woody_app/customer/features/orders/cubit/unpaid_order_cubit.dart';
import 'package:woody_app/customer/widgets/view_mode_toggle.dart';
import 'package:woody_app/shared/widgets/error_state.dart';

/// Every dependency is mocked at the Bloc/Cubit boundary so the failure
/// branch renders without touching a repository or the network — mirrors
/// the pattern in `favorites_screen_widget_test.dart`.
class _MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {}

class _MockNotificationsCubit
    extends MockCubit<NotificationsState>
    implements NotificationsCubit {}

class _MockUnpaidOrderCubit extends MockCubit<UnpaidOrderState>
    implements UnpaidOrderCubit {}

class _MockNetworkCubit extends MockCubit<NetworkStatus>
    implements NetworkCubit {}

class _MockBox extends Mock implements Box {}

void main() {
  late _MockHomeBloc homeBloc;
  late _MockNotificationsCubit notificationsCubit;
  late _MockUnpaidOrderCubit unpaidOrderCubit;
  late _MockNetworkCubit networkCubit;

  setUp(() {
    // Both first-launch spotlights already "seen" — skips the async
    // ShowCaseWidget tour entirely so it can't leave a pending frame
    // callback dangling past the end of the test.
    SharedPreferences.setMockInitialValues(const {
      'has_seen_ar_demo': true,
      'has_seen_ai_showcase': true,
    });

    homeBloc = _MockHomeBloc();
    whenListen(
      homeBloc,
      const Stream<HomeState>.empty(),
      initialState: const HomeState(status: HomeStatus.failure),
    );

    notificationsCubit = _MockNotificationsCubit();
    whenListen(
      notificationsCubit,
      const Stream<NotificationsState>.empty(),
      initialState: const NotificationsState(),
    );

    unpaidOrderCubit = _MockUnpaidOrderCubit();
    whenListen(
      unpaidOrderCubit,
      const Stream<UnpaidOrderState>.empty(),
      initialState: const UnpaidOrderState(),
    );
    when(unpaidOrderCubit.refresh).thenAnswer((_) async {});

    networkCubit = _MockNetworkCubit();
    whenListen(
      networkCubit,
      const Stream<NetworkStatus>.empty(),
      initialState: NetworkStatus.online,
    );

    // HomeScreen resolves NotificationsCubit and ProductViewModeController
    // straight from the locator (not via ancestor BlocProvider), so both
    // must be registered before pump.
    sl.registerSingleton<NotificationsCubit>(notificationsCubit);
    sl.registerSingleton<UnpaidOrderCubit>(unpaidOrderCubit);
    sl.registerSingleton<ProductViewModeController>(
      ProductViewModeController(AppSettings(_MockBox())),
    );
  });

  tearDown(() => sl.reset());

  Widget harness() => MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<HomeBloc>.value(value: homeBloc),
        BlocProvider<UnpaidOrderCubit>.value(value: unpaidOrderCubit),
        BlocProvider<NetworkCubit>.value(value: networkCubit),
      ],
      child: CustomerShellScope(
        index: 0,
        goToTab: (_) {},
        child: const HomeScreen(),
      ),
    ),
  );

  testWidgets(
    'renders ErrorState on a cold-load failure',
    (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    },
  );
}
