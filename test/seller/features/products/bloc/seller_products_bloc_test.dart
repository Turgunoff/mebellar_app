import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/seller/features/products/bloc/seller_products_bloc.dart';
import '../../../../fixtures/mocks/mock/mock_seller_product_repository.dart';
import 'package:woody_app/shared/models/seller_product.dart';
import 'package:woody_app/shared/repositories/seller_product_repository.dart';

void main() {
  group('SellerProductsBloc (mock repository)', () {
    test('opens on the approved tab by default', () {
      expect(const SellerProductsState().filter.statuses, {
        SellerProductStatus.approved,
      });
    });

    blocTest<SellerProductsBloc, SellerProductsState>(
      'first search keystroke widens scope to all statuses',
      build: () => SellerProductsBloc(MockSellerProductRepository()),
      act: (bloc) async {
        bloc.add(const SellerProductsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 500));
        bloc.add(const SellerProductsSearchChanged('MH'));
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        expect(bloc.state.filter.statuses, isEmpty);
        expect(bloc.state.filter.search, 'MH');
      },
    );

    blocTest<SellerProductsBloc, SellerProductsState>(
      'status chip picked mid-search survives later keystrokes',
      build: () => SellerProductsBloc(MockSellerProductRepository()),
      act: (bloc) async {
        bloc.add(const SellerProductsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 500));
        bloc.add(const SellerProductsSearchChanged('M'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(
          SellerProductsFilterChanged(
            bloc.state.filter.copyWith(
              statuses: {SellerProductStatus.rejected},
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const SellerProductsSearchChanged('MH'));
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        expect(bloc.state.filter.statuses, {SellerProductStatus.rejected});
        expect(bloc.state.filter.search, 'MH');
      },
    );

    blocTest<SellerProductsBloc, SellerProductsState>(
      'fetch -> 12 seeded products',
      build: () => SellerProductsBloc(MockSellerProductRepository()),
      act: (bloc) => bloc.add(const SellerProductsRequested()),
      wait: const Duration(milliseconds: 500),
      verify: (bloc) {
        expect(bloc.state.status, SellerProductsStatus.ready);
        expect(bloc.state.products.length, 12);
      },
    );

    blocTest<SellerProductsBloc, SellerProductsState>(
      'filter by status returns only matching products',
      build: () => SellerProductsBloc(MockSellerProductRepository()),
      act: (bloc) async {
        bloc.add(const SellerProductsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 500));
        bloc.add(
          const SellerProductsFilterChanged(
            SellerProductFilter(statuses: {SellerProductStatus.rejected}),
          ),
        );
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        expect(
          bloc.state.visibleProducts.every(
            (p) => p.status == SellerProductStatus.rejected,
          ),
          isTrue,
        );
        expect(bloc.state.visibleProducts.length, greaterThan(0));
      },
    );

    blocTest<SellerProductsBloc, SellerProductsState>(
      'fetch populates whole-catalogue status counts for the filter chips',
      build: () => SellerProductsBloc(MockSellerProductRepository()),
      act: (bloc) => bloc.add(const SellerProductsRequested()),
      wait: const Duration(milliseconds: 500),
      verify: (bloc) {
        // "Barchasi" badge = sum of every bucket = the 12 seeded products.
        expect(bloc.state.countFor(null), 12);
        final summed = SellerProductStatus.values
            .map((s) => bloc.state.countFor(s) ?? 0)
            .fold<int>(0, (a, b) => a + b);
        expect(summed, 12);
      },
    );

    blocTest<SellerProductsBloc, SellerProductsState>(
      'archive moves one product between chip-count buckets',
      build: () => SellerProductsBloc(MockSellerProductRepository()),
      act: (bloc) async {
        bloc.add(const SellerProductsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final approvedBefore = bloc.state.countFor(
          SellerProductStatus.approved,
        )!;
        final archivedBefore = bloc.state.countFor(
          SellerProductStatus.archived,
        )!;
        final live = bloc.state.products.firstWhere(
          (p) => p.status == SellerProductStatus.approved,
        );
        bloc.add(SellerProductArchived(live.id));
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(
          bloc.state.countFor(SellerProductStatus.approved),
          approvedBefore - 1,
        );
        expect(
          bloc.state.countFor(SellerProductStatus.archived),
          archivedBefore + 1,
        );
        expect(bloc.state.countFor(null), 12);
      },
    );

    blocTest<SellerProductsBloc, SellerProductsState>(
      'archive transitions an approved product -> archived in the list',
      build: () => SellerProductsBloc(MockSellerProductRepository()),
      act: (bloc) async {
        bloc.add(const SellerProductsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final live = bloc.state.products.firstWhere(
          (p) => p.status == SellerProductStatus.approved,
        );
        bloc.add(SellerProductArchived(live.id));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      },
      verify: (bloc) {
        expect(bloc.state.status, SellerProductsStatus.ready);
        expect(bloc.state.error, isNull);
        expect(
          bloc.state.products
              .where((p) => p.status == SellerProductStatus.archived)
              .length,
          greaterThan(0),
        );
      },
    );

    blocTest<SellerProductsBloc, SellerProductsState>(
      'restore transitions an archived product -> pending_review',
      build: () => SellerProductsBloc(MockSellerProductRepository()),
      act: (bloc) async {
        bloc.add(const SellerProductsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 500));
        // Archive an approved product first so there's a known archived id.
        final live = bloc.state.products.firstWhere(
          (p) => p.status == SellerProductStatus.approved,
        );
        bloc.add(SellerProductArchived(live.id));
        await Future<void>.delayed(const Duration(milliseconds: 500));
        bloc.add(SellerProductRestored(live.id));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      },
      verify: (bloc) {
        expect(bloc.state.status, SellerProductsStatus.ready);
        expect(bloc.state.error, isNull);
        // The restored product is back in moderation, not archived.
        expect(
          bloc.state.products.any(
            (p) => p.status == SellerProductStatus.pendingReview,
          ),
          isTrue,
        );
      },
    );

    blocTest<SellerProductsBloc, SellerProductsState>(
      'delete removes an archived product from the list for good',
      build: () => SellerProductsBloc(MockSellerProductRepository()),
      act: (bloc) async {
        bloc.add(const SellerProductsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 500));
        // Archive an approved product first so there's a known archived id.
        final live = bloc.state.products.firstWhere(
          (p) => p.status == SellerProductStatus.approved,
        );
        bloc.add(SellerProductArchived(live.id));
        await Future<void>.delayed(const Duration(milliseconds: 500));
        bloc.add(SellerProductDeleted(live.id));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      },
      verify: (bloc) {
        expect(bloc.state.status, SellerProductsStatus.ready);
        expect(bloc.state.error, isNull);
        expect(bloc.state.products.length, 11);
      },
    );

    blocTest<SellerProductsBloc, SellerProductsState>(
      'submit for review transitions rejected -> pending',
      build: () => SellerProductsBloc(MockSellerProductRepository()),
      act: (bloc) async {
        bloc.add(const SellerProductsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final rejected = bloc.state.products.firstWhere(
          (p) => p.status == SellerProductStatus.rejected,
        );
        bloc.add(SellerProductSubmitted(rejected.id));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      },
      verify: (bloc) {
        // The earlier rejected product should now be pending review.
        final pendingCount = bloc.state.products
            .where((p) => p.status == SellerProductStatus.pendingReview)
            .length;
        expect(
          pendingCount,
          greaterThan(3),
          reason:
              'Seed has 3 pending products; submit should add at least 1 more',
        );
      },
    );
  });
}
