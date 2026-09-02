import 'package:dio/dio.dart';

/// A network/API failure translated into something worth showing a user.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors, this.isNetwork = false});

  final String message;
  final int? statusCode;
  final List<String>? errors;
  final bool isNetwork;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  factory ApiException.from(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          'The server took too long to respond. Check your connection and try again.',
          isNetwork: true,
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return ApiException(
          'Cannot reach the server. Make sure the backend is running and you are on the same network.',
          isNetwork: true,
        );
      case DioExceptionType.cancel:
        return ApiException('Request cancelled.');
      case DioExceptionType.transformTimeout:
        return ApiException(
          'The response took too long to process. Please try again.',
          isNetwork: true,
        );
      case DioExceptionType.badCertificate:
        return ApiException('The server certificate could not be verified.');
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        final code = e.response?.statusCode;
        if (data is Map) {
          final raw = data['errors'];
          return ApiException(
            (data['message'] as String?) ?? _fallbackFor(code),
            statusCode: code,
            errors: raw is List ? raw.map((x) => x.toString()).toList() : null,
          );
        }
        return ApiException(_fallbackFor(code), statusCode: code);
    }
  }

  static String _fallbackFor(int? code) => switch (code) {
        400 => 'That request was not valid.',
        401 => 'Your session has expired. Please log in again.',
        403 => 'You do not have permission to do that.',
        404 => 'We could not find what you were looking for.',
        409 => 'That conflicts with an existing record.',
        final c? when c >= 500 =>
          'The server ran into a problem. Please try again shortly.',
        _ => 'Something went wrong. Please try again.',
      };

  @override
  String toString() => message;
}
