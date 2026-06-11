import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/cache/app_cache_cubit.dart';
import 'package:woody_app/core/cache/cache_service.dart';

const _mb = 1024 * 1024;

/// Fake that records every interaction. Lets a test assert the cubit's ONLY
/// collaborator is the cache service — so clearing the cache can never reach
/// secure storage, the token store, or the Hive boxes.
class _RecordingCacheService implements CacheService {
  _RecordingCacheService({this.size = 24 * _mb});

  int size;
  final List<String> calls = [];
  bool cleared = false;

  @override
  Future<int> sizeBytes() async {
    calls.add('sizeBytes');
    return cleared ? 0 : size;
  }

  @override
  Future<void> clear() async {
    calls.add('clear');
    cleared = true;
  }
}

void main() {
  group('formatCacheBytes', () {
    test('sub-megabyte (including an emptied cache) reads as "< 1 MB"', () {
      expect(formatCacheBytes(0), '< 1 MB');
      expect(formatCacheBytes(512 * 1024), '< 1 MB');
    });

    test('single-digit MB keeps one decimal', () {
      expect(formatCacheBytes(5 * _mb + 600 * 1024), '5.6 MB');
    });

    test('double-digit MB drops the decimal', () {
      expect(formatCacheBytes(24 * _mb), '24 MB');
    });

    test('gigabytes use two decimals', () {
      expect(formatCacheBytes(2 * 1024 * _mb), '2.00 GB');
    });
  });

  group('AppCacheCubit', () {
    blocTest<AppCacheCubit, AppCacheState>(
      'calculate() emits calculating then ready with the real size',
      build: () => AppCacheCubit(_RecordingCacheService(size: 24 * _mb)),
      act: (cubit) => cubit.calculate(),
      expect: () => [
        isA<AppCacheState>().having(
          (s) => s.status,
          'status',
          CacheStatus.calculating,
        ),
        isA<AppCacheState>()
            .having((s) => s.status, 'status', CacheStatus.ready)
            .having((s) => s.sizeBytes, 'sizeBytes', 24 * _mb)
            .having((s) => s.sizeLabel, 'sizeLabel', '24 MB'),
      ],
    );

    blocTest<AppCacheCubit, AppCacheState>(
      'clearCache() emits clearing then recomputes to the emptied size',
      build: () => AppCacheCubit(_RecordingCacheService(size: 24 * _mb)),
      act: (cubit) => cubit.clearCache(),
      expect: () => [
        isA<AppCacheState>().having(
          (s) => s.status,
          'status',
          CacheStatus.clearing,
        ),
        isA<AppCacheState>()
            .having((s) => s.status, 'status', CacheStatus.ready)
            .having((s) => s.sizeBytes, 'sizeBytes', 0)
            .having((s) => s.sizeLabel, 'sizeLabel', '< 1 MB'),
      ],
    );

    test('clearCache() only ever talks to the CacheService — safety guard',
        () async {
      final service = _RecordingCacheService();
      final cubit = AppCacheCubit(service);

      await cubit.clearCache();

      // Exactly: wipe the cache, then recompute. No other side-channels exist
      // because CacheService is the cubit's sole dependency — there is no path
      // from here to secure storage / tokens / Hive.
      expect(service.calls, ['clear', 'sizeBytes']);
      expect(service.cleared, isTrue);

      await cubit.close();
    });

    blocTest<AppCacheCubit, AppCacheState>(
      'calculate() is a no-op while a clear is already in flight',
      build: () => AppCacheCubit(_RecordingCacheService()),
      seed: () => const AppCacheState(status: CacheStatus.clearing),
      act: (cubit) => cubit.calculate(),
      expect: () => const <AppCacheState>[],
    );
  });
}
