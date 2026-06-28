import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Master switch for the console network-traffic blocks. Flip to `true` to get
/// the high-visibility request/response/error dumps back in the debug console.
/// Off by default — the dumps are extremely noisy. Independent of `kDebugMode`
/// (which still guards every format path), so a release build never logs even
/// if this is left on.
const bool kNetworkConsoleLogging = false;

/// Global network-traffic logger.
///
/// Reformats every Dio request / response / error into a high-visibility,
/// structurally-bounded console block. Attached to *all* Dio instances in the
/// app — the woody API client, the raw R2 upload client, and the CBU rate feed
/// — so no HTTP call goes unlogged.
///
/// Entirely a debug affordance: every print path is behind [kDebugMode] AND the
/// interceptor is only attached to the app-default clients in debug builds, so
/// a profile/release build never formats a block, never builds a string, and
/// never risks leaking a token. It is intentionally logger-free — raw,
/// dependency-light, console-only.
class NetworkLoggerInterceptor extends Interceptor {
  const NetworkLoggerInterceptor();

  /// Stashed on `RequestOptions.extra` in [onRequest] so the matching
  /// response/error can report wall-clock duration. Keyed on the request
  /// object, so interceptor ordering doesn't matter.
  static const _startKey = '__net_log_start_us';

  static const _rule =
      '======================================================================';
  static const _divider =
      '----------------------------------------------------------------------';

  /// Bodies past this are truncated — a 2 MB catalogue response shouldn't
  /// drown the console (or trip the debugPrint throttle).
  static const _maxBodyChars = 5000;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      options.extra[_startKey] = DateTime.now().microsecondsSinceEpoch;
      _emit(_requestBlock(options));
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (kDebugMode) {
      final status = response.statusCode ?? 0;
      // The woody client's `validateStatus` lets every status < 500 through
      // `onResponse` (only 5xx / transport failures reach `onError`). Surface a
      // 4xx as a failure block, not a green success.
      if (status >= 400) {
        _emit(
          _errorBlock(
            method: response.requestOptions.method,
            uri: response.requestOptions.uri,
            status: status,
            elapsed: _elapsed(response.requestOptions),
            errorDetails: 'Backend returned HTTP $status',
            payload: response.data,
            stack: null,
          ),
        );
      } else {
        _emit(_responseBlock(response));
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      _emit(
        _errorBlock(
          method: err.requestOptions.method,
          uri: err.requestOptions.uri,
          status: err.response?.statusCode,
          elapsed: _elapsed(err.requestOptions),
          errorDetails: _describeError(err),
          payload: err.response?.data,
          stack: err.stackTrace,
        ),
      );
    }
    handler.next(err);
  }

  // ── Block builders ────────────────────────────────────────────────────────

  String _requestBlock(RequestOptions o) {
    final b = StringBuffer()
      ..writeln(_rule)
      ..writeln('[GLOBAL API REQUEST] 🚀 OUTGOING NETWORK TRAFFIC')
      ..writeln(_divider)
      ..writeln('Timestamp: ${DateTime.now()}')
      ..writeln('API Endpoint: [${o.method}] ${o.uri}')
      ..writeln('Headers: ${_formatMap(_sanitizeHeaders(o.headers))}')
      ..writeln('Query Params: ${_formatMap(o.queryParameters)}')
      ..writeln('Request Payload body:')
      ..writeln(_formatBody(o.data))
      ..write(_rule);
    return b.toString();
  }

  String _responseBlock(Response<dynamic> r) {
    final o = r.requestOptions;
    final b = StringBuffer()
      ..writeln(_rule)
      ..writeln('[GLOBAL API RESPONSE] ✅ INCOMING NETWORK TRAFFIC')
      ..writeln(_divider)
      ..writeln(
        'HTTP Status Code: ${r.statusCode} ${_statusText(r.statusCode ?? 0)}',
      )
      ..writeln('Duration: ${_formatElapsed(_elapsed(o))}')
      ..writeln('API Endpoint: [${o.method}] ${o.uri}')
      ..writeln('Clean Response JSON Body:')
      ..writeln(_formatBody(r.data))
      ..write(_rule);
    return b.toString();
  }

  String _errorBlock({
    required String method,
    required Uri uri,
    required int? status,
    required Duration? elapsed,
    required String errorDetails,
    required Object? payload,
    required StackTrace? stack,
  }) {
    final b = StringBuffer()
      ..writeln(_rule)
      ..writeln('[GLOBAL API ERROR] ❌ NETWORK TRAFFIC FAILURE')
      ..writeln(_divider)
      ..writeln(
        'HTTP Status Code: ${status ?? 'n/a'} ${_statusText(status ?? 0)}',
      )
      ..writeln('Duration: ${_formatElapsed(elapsed)}')
      ..writeln('Target Endpoint: [$method] $uri')
      ..writeln('Error Details: $errorDetails')
      ..writeln('Server Error Response Payload:')
      ..writeln(_formatBody(payload));
    if (stack != null) {
      b
        ..writeln('Stack Trace:')
        ..writeln(_truncate(stack.toString(), _maxBodyChars));
    }
    b.write(_rule);
    return b.toString();
  }

  // ── Formatting helpers ────────────────────────────────────────────────────

  /// Pretty-prints JSON-shaped payloads; summarises anything that isn't text
  /// (multipart uploads, raw byte streams) so a binary body never floods the
  /// console.
  String _formatBody(Object? data) {
    if (data == null) return '(empty)';
    if (data is FormData) {
      final fields = data.fields.map((e) => '${e.key}=${e.value}').join(', ');
      final files = data.files
          .map(
            (e) =>
                '${e.key}=<file ${e.value.filename ?? '?'} '
                '${e.value.length}b>',
          )
          .join(', ');
      return 'FormData{fields: {$fields}, files: [$files]}';
    }
    // R2 PUTs stream the bytes (`Stream.fromIterable([bytes])`); a raw byte
    // list or stream has no readable representation.
    if (data is Stream || data is List<int>) {
      final n = data is List<int> ? '${data.length} bytes' : 'stream';
      return '<binary body: $n>';
    }
    String text;
    if (data is Map || data is List) {
      text = _tryEncode(data);
    } else if (data is String) {
      text = _looksLikeJson(data) ? _tryEncode(_tryDecode(data) ?? data) : data;
    } else {
      text = data.toString();
    }
    return _truncate(text, _maxBodyChars);
  }

  String _formatMap(Map<String, dynamic> map) =>
      map.isEmpty ? '{}' : _tryEncode(map);

  /// Redacts the bearer token (and cookies) down to a fingerprint — the block
  /// is still useful for "was an Authorization header attached?" without
  /// dumping a full JWT into the log.
  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final out = <String, dynamic>{};
    headers.forEach((key, value) {
      final lower = key.toLowerCase();
      if (lower == 'authorization' ||
          lower == 'cookie' ||
          lower == 'set-cookie') {
        final s = value.toString();
        out[key] = s.length > 24
            ? '${s.substring(0, 16)}…(${s.length} chars)'
            : s;
      } else {
        out[key] = value;
      }
    });
    return out;
  }

  Duration? _elapsed(RequestOptions o) {
    final start = o.extra[_startKey];
    if (start is int) {
      return Duration(
        microseconds: DateTime.now().microsecondsSinceEpoch - start,
      );
    }
    return null;
  }

  String _formatElapsed(Duration? d) =>
      d == null ? 'n/a' : '${d.inMilliseconds}ms';

  String _describeError(DioException err) {
    final detail = err.message ?? err.error?.toString() ?? '';
    return 'DioException [${err.type.name}]${detail.isEmpty ? '' : ': $detail'}';
  }

  String _tryEncode(Object? value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  Object? _tryDecode(String value) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeJson(String s) {
    final t = s.trimLeft();
    return t.startsWith('{') || t.startsWith('[');
  }

  String _statusText(int status) {
    switch (status) {
      case 200:
        return 'OK';
      case 201:
        return 'Created';
      case 202:
        return 'Accepted';
      case 204:
        return 'No Content';
      case 301:
        return 'Moved Permanently';
      case 302:
        return 'Found';
      case 304:
        return 'Not Modified';
      case 400:
        return 'Bad Request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not Found';
      case 409:
        return 'Conflict';
      case 422:
        return 'Unprocessable Entity';
      case 429:
        return 'Too Many Requests';
      case 500:
        return 'Internal Server Error';
      case 502:
        return 'Bad Gateway';
      case 503:
        return 'Service Unavailable';
      case 504:
        return 'Gateway Timeout';
      default:
        if (status == 0) return '';
        if (status >= 500) return 'Server Error';
        if (status >= 400) return 'Client Error';
        if (status >= 300) return 'Redirect';
        return 'OK';
    }
  }

  String _truncate(String text, int max) => text.length <= max
      ? text
      : '${text.substring(0, max)}\n… (${text.length - max} more chars truncated)';

  /// `debugPrint` (not `print`) so the framework's throttle keeps Android
  /// logcat from dropping lines of a large block. No-ops unless
  /// [kNetworkConsoleLogging] is on, so the dumps stay silent by default.
  void _emit(String block) {
    if (!kNetworkConsoleLogging) return;
    debugPrint(block);
  }
}
