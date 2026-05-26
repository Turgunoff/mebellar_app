import 'dart:async';

import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import 'api_error.dart';
import 'token_store.dart';

/// HTTP client for `api.woody.uz`.
///
/// All FastAPI routes are mounted under `/api/v1` — [baseUrl] points at the
/// host root, [_apiV1Path] is prefixed onto every call. Every non-anonymous
/// request gets `Authorization: Bearer <access>` from [TokenStore].
///
/// On a 401, the client posts `/auth/refresh` once with the persisted refresh
/// token and replays the original request with `_skipRefresh = true` to
/// prevent recursion. If refresh fails, tokens are cleared and the error
/// surfaces as [ApiError.isUnauthorized] so the auth layer can demote.
///
/// Errors are normalised into [ApiError]. FastAPI's `{detail: "..."}`
/// envelope becomes [ApiError.code]; the `Retry-After` header populates
/// [ApiError.retryAfterSeconds] on 429.
class WoodyApiClient {
  WoodyApiClient({
    required this.tokens,
    Dio? dio,
  }) : _dio = dio ?? _defaultDio() {
    _dio.interceptors.add(_AuthInterceptor(this));
  }

  static const _apiV1Path = '/api/v1';
  static const _skipRefreshKey = '__woody_skip_refresh';
  static const _anonymousKey = '__woody_anonymous';

  final Dio _dio;
  final TokenStore tokens;

  /// Stream of forced sign-outs caused by refresh-token failure. The auth
  /// layer listens to this and transitions the cubit into a signed-out
  /// state without the user touching the UI.
  final StreamController<void> _forcedSignOut =
      StreamController<void>.broadcast();
  Stream<void> get forcedSignOuts => _forcedSignOut.stream;

  static Dio _defaultDio() {
    return Dio(
      BaseOptions(
        baseUrl: AppConfig.woodyApiUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool anonymous = false,
  }) =>
      _send<T>('GET', path, query: query, anonymous: anonymous);

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool anonymous = false,
  }) =>
      _send<T>('POST', path, body: body, query: query, anonymous: anonymous);

  Future<T> patch<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool anonymous = false,
  }) =>
      _send<T>('PATCH', path, body: body, query: query, anonymous: anonymous);

  Future<T> put<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool anonymous = false,
  }) =>
      _send<T>('PUT', path, body: body, query: query, anonymous: anonymous);

  Future<T> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool anonymous = false,
  }) =>
      _send<T>('DELETE', path, body: body, query: query, anonymous: anonymous);

  Future<T> _send<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool anonymous = false,
  }) async {
    final fullPath = '$_apiV1Path$path';
    try {
      final response = await _dio.request<dynamic>(
        fullPath,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          extra: {_anonymousKey: anonymous},
        ),
      );
      _ensureSuccess(response);
      return response.data as T;
    } on DioException catch (e) {
      throw _toApiError(e);
    }
  }

  void _ensureSuccess(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) return;
    throw _responseToApiError(response);
  }

  ApiError _toApiError(DioException e) {
    final response = e.response;
    if (response != null) return _responseToApiError(response);
    return ApiError(
      status: 0,
      code: 'network_error',
      message: e.message ?? e.error?.toString(),
    );
  }

  ApiError _responseToApiError(Response<dynamic> response) {
    final data = response.data;
    String code = 'http_error';
    String? message;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String) {
        code = detail;
        message = detail;
      } else if (detail is List && detail.isNotEmpty) {
        code = 'validation_error';
        message = detail.toString();
      } else if (data['code'] is String) {
        code = data['code'] as String;
        message = data['message'] as String?;
      }
    } else if (data is String && data.isNotEmpty) {
      message = data;
    }
    final retryAfterHeader =
        response.headers.value('retry-after') ??
            response.headers.value('Retry-After');
    return ApiError(
      status: response.statusCode ?? 0,
      code: code,
      message: message,
      retryAfterSeconds:
          retryAfterHeader == null ? null : int.tryParse(retryAfterHeader),
    );
  }

  Future<bool> _attemptRefresh() async {
    final current = await tokens.read();
    final refresh = current?.refreshToken;
    if (refresh == null) return false;
    try {
      final response = await _dio.post<dynamic>(
        '$_apiV1Path/auth/refresh',
        data: {'refresh_token': refresh},
        options: Options(extra: {_skipRefreshKey: true, _anonymousKey: true}),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        await _forceSignOut();
        return false;
      }
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        await _forceSignOut();
        return false;
      }
      final access = data['access_token'] as String?;
      final newRefresh = data['refresh_token'] as String?;
      final expiresIn = data['expires_in'];
      if (access == null || newRefresh == null) {
        await _forceSignOut();
        return false;
      }
      final expiresAt = expiresIn is int
          ? DateTime.now().add(Duration(seconds: expiresIn))
          : null;
      await tokens.write(
        TokenPair(
          accessToken: access,
          refreshToken: newRefresh,
          expiresAt: expiresAt,
        ),
      );
      return true;
    } on DioException {
      await _forceSignOut();
      return false;
    }
  }

  Future<void> _forceSignOut() async {
    await tokens.clear();
    if (!_forcedSignOut.isClosed) {
      _forcedSignOut.add(null);
    }
  }

  Future<void> dispose() async {
    await _forcedSignOut.close();
    _dio.close(force: true);
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._client);

  final WoodyApiClient _client;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final anonymous = options.extra[WoodyApiClient._anonymousKey] == true;
    if (!anonymous) {
      final pair = await _client.tokens.read();
      if (pair != null) {
        options.headers['Authorization'] = 'Bearer ${pair.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final status = response.statusCode ?? 0;
    final anonymous =
        response.requestOptions.extra[WoodyApiClient._anonymousKey] == true;
    final skipRefresh =
        response.requestOptions.extra[WoodyApiClient._skipRefreshKey] == true;
    if (status == 401 && !anonymous && !skipRefresh) {
      final refreshed = await _client._attemptRefresh();
      if (refreshed) {
        final retried = await _replay(response.requestOptions);
        return handler.resolve(retried);
      }
    }
    handler.next(response);
  }

  Future<Response<dynamic>> _replay(RequestOptions original) {
    final next = original.copyWith(
      extra: {...original.extra, WoodyApiClient._skipRefreshKey: true},
    );
    return _client._dio.fetch<dynamic>(next);
  }
}
