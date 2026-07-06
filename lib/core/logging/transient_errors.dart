import 'dart:async';
import 'dart:io' show SocketException;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

import '../network/api_error.dart';

/// Returns true for routine mobile conditions that must not pollute Crashlytics
/// (offline blips, expired sessions, gateway timeouts, sideload install errors).
bool isExpectedTransientError(Object error) {
  if (error is ParallelWaitError) {
    final nested = _nestedParallelWaitErrors(error);
    if (nested.isEmpty) return false;
    return nested.every(isExpectedTransientError);
  }

  if (error is ApiError) {
    return error.status == 0 ||
        error.code == 'network_error' ||
        error.isUnauthorized ||
        error.status == 408 ||
        error.status == 502 ||
        error.status == 503 ||
        error.status == 504;
  }

  if (error is SocketException || error is TimeoutException) {
    return true;
  }

  if (error is PlatformException) {
    return _isBenignPlatformException(error);
  }

  if (error is FirebaseException) {
    return _isBenignFirebaseException(error);
  }

  return false;
}

bool _isBenignPlatformException(PlatformException error) {
  final code = error.code.toLowerCase();
  final message = (error.message ?? '').toLowerCase();

  if (code == 'task_failure') return true;
  if (message.contains('install error')) return true;
  if (message.contains('not owned by any user')) return true;
  if (message.contains('download/install is not allowed')) return true;

  return false;
}

bool _isBenignFirebaseException(FirebaseException error) {
  if (!(error.plugin == 'firebase_messaging')) return false;
  final code = error.code.toLowerCase();
  return code == 'apns-token-not-set' || code.endsWith('apns-token-not-set');
}

Iterable<Object> _nestedParallelWaitErrors(ParallelWaitError error) sync* {
  final raw = error.errors;
  if (raw is Iterable) {
    for (final entry in raw) {
      if (entry == null) continue;
      if (entry is AsyncError) {
        yield entry.error;
      } else {
        yield entry as Object;
      }
    }
  }
}
