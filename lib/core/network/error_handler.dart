import 'package:dio/dio.dart';

import '../error/failure.dart';

Failure mapDioError(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.connectionError:
      return NetworkFailure(message: error.message ?? 'Network error');
    case DioExceptionType.badResponse:
      final data = error.response?.data;
      String? code;
      String? message;
      if (data is Map<String, dynamic>) {
        final err = data['error'];
        if (err is Map<String, dynamic>) {
          code = err['code'] as String?;
          message = err['message'] as String?;
        }
      }
      return ServerFailure(
        message: message ?? 'Server error',
        code: code,
        statusCode: error.response?.statusCode,
      );
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return UnknownFailure(message: error.message ?? 'Unknown error');
  }
}
