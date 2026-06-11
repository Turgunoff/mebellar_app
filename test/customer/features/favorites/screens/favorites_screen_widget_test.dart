import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/customer/features/favorites/bloc/favorites_bloc.dart';
import 'package:woody_app/customer/features/favorites/screens/favorites_screen.dart';
import 'package:woody_app/shared/widgets/brand_refresh_indicator.dart';

/// FavoritesBloc is replaced by a MockBloc so each render state (loading /
/// empty) is pinned without a repository or network. The loaded grid is not
/// exercised here — it builds full Product snapshots, which the bloc-level
/// tests already cover.
class _MockFavoritesBloc extends MockBloc<FavoritesEvent, FavoritesState>
    implements FavoritesBloc {}

void main() {
  late _MockFavoritesBloc bloc;

  setUp(() => bloc = _MockFavoritesBloc());

  Widget harness() => MaterialApp(
    home: Scaffold(
      body: BlocProvider<FavoritesBloc>.value(
        value: bloc,
        child: const FavoritesScreen(),
      ),
    ),
  );

  testWidgets('shows the brand loading indicator while loading', (
    tester,
  ) async {
    whenListen(
      bloc,
      const Stream<FavoritesState>.empty(),
      initialState: const FavoritesState(status: FavoritesStatus.loading),
    );

    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byType(BrandLoadingIndicator), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no favourites', (
    tester,
  ) async {
    whenListen(
      bloc,
      const Stream<FavoritesState>.empty(),
      initialState: const FavoritesState(status: FavoritesStatus.ready),
    );

    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text("Sevimlilar ro'yxati bo'sh"), findsOneWidget);
    // CTA back to the catalog is part of the empty state.
    expect(find.text("Mahsulotlarni ko'rish"), findsOneWidget);
  });
}
