import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/connectivity/network_cubit.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/customer/customer_app.dart';
import 'package:woody_app/customer/features/categories/bloc/categories_bloc.dart';
import 'package:woody_app/customer/features/categories/screens/categories_screen.dart';
import 'package:woody_app/shared/widgets/error_state.dart';

/// CategoriesBloc/NetworkCubit are replaced by MockBloc/MockCubit so the
/// first-load failure state (no cache, nothing to show) is pinned without a
/// repository or real connectivity plumbing.
class _MockCategoriesBloc extends MockBloc<CategoriesEvent, CategoriesState>
    implements CategoriesBloc {}

class _MockNetworkCubit extends MockCubit<NetworkStatus>
    implements NetworkCubit {}

void main() {
  setUpAll(() {
    AppTranslations.setInstance(AppTranslations.forLocale(const Locale('uz')));
  });

  late _MockCategoriesBloc bloc;
  late _MockNetworkCubit networkCubit;

  setUp(() {
    bloc = _MockCategoriesBloc();
    networkCubit = _MockNetworkCubit();
    whenListen(
      networkCubit,
      const Stream<NetworkStatus>.empty(),
      initialState: NetworkStatus.online,
    );
  });

  Widget harness() => MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<CategoriesBloc>.value(value: bloc),
        BlocProvider<NetworkCubit>.value(value: networkCubit),
      ],
      // NetworkErrorGate's isActive predicate reads CustomerShellScope
      // (categories is the tab-1 screen), so it must be in the tree.
      child: CustomerShellScope(
        goToTab: (_) {},
        index: 1,
        child: const Scaffold(body: CategoriesScreen()),
      ),
    ),
  );

  testWidgets(
    'shows ErrorState on first-load failure',
    (tester) async {
      whenListen(
        bloc,
        const Stream<CategoriesState>.empty(),
        initialState: const CategoriesState(
          status: CategoriesStatus.failure,
          error: 'boom',
        ),
      );

      await tester.pumpWidget(harness());
      await tester.pump();

      expect(find.byType(ErrorState), findsOneWidget);
    },
  );

  testWidgets('ErrorState retry taps CategoriesRequested', (tester) async {
    whenListen(
      bloc,
      const Stream<CategoriesState>.empty(),
      initialState: const CategoriesState(
        status: CategoriesStatus.failure,
        error: 'boom',
      ),
    );

    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    verify(() => bloc.add(const CategoriesRequested())).called(1);
  });
}
