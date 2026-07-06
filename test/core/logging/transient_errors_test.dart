import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/logging/transient_errors.dart';
import 'package:woody_app/core/network/api_error.dart';

void main() {
  group('isExpectedTransientError', () {
    test('treats network ApiError as transient', () {
      expect(
        isExpectedTransientError(ApiError(status: 0, code: 'network_error')),
        isTrue,
      );
      expect(
        isExpectedTransientError(
          ApiError(status: 504, code: 'gateway_timeout'),
        ),
        isTrue,
      );
      expect(
        isExpectedTransientError(ApiError(status: 401, code: 'unauthorized')),
        isTrue,
      );
    });

    test('keeps actionable ApiError as non-transient', () {
      expect(
        isExpectedTransientError(ApiError(status: 500, code: 'internal_error')),
        isFalse,
      );
    });

    test('treats socket and timeout as transient', () {
      expect(
        isExpectedTransientError(const SocketException('Failed host lookup')),
        isTrue,
      );
      expect(isExpectedTransientError(TimeoutException('timed out')), isTrue);
    });

    test('unwraps ParallelWaitError when every child is transient', () {
      final error = ParallelWaitError(
        [null, null],
        [
          AsyncError(
            ApiError(status: 504, code: 'gateway_timeout'),
            StackTrace.empty,
          ),
          AsyncError(TimeoutException('maintenance refresh'), StackTrace.empty),
        ],
      );
      expect(isExpectedTransientError(error), isTrue);
    });

    test('keeps ParallelWaitError when any child is actionable', () {
      final error = ParallelWaitError(
        [null, null],
        [
          AsyncError(
            ApiError(status: 504, code: 'gateway_timeout'),
            StackTrace.empty,
          ),
          AsyncError(
            ApiError(status: 500, code: 'internal_error'),
            StackTrace.empty,
          ),
        ],
      );
      expect(isExpectedTransientError(error), isFalse);
    });

    test('filters benign platform install failures', () {
      expect(
        isExpectedTransientError(
          PlatformException(
            code: 'TASK_FAILURE',
            message: 'Install Error(-10)',
          ),
        ),
        isTrue,
      );
    });

    test('filters apns-token-not-set on messaging', () {
      expect(
        isExpectedTransientError(
          FirebaseException(
            plugin: 'firebase_messaging',
            code: 'apns-token-not-set',
          ),
        ),
        isTrue,
      );
    });
  });
}
