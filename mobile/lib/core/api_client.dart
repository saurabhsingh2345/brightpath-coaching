import 'dart:async';
import 'package:dio/dio.dart';
import 'api_exception.dart';
import 'config.dart';
import 'token_store.dart';

/// Single Dio instance for the whole app.
///
/// Attaches the bearer token, and on a 401 transparently refreshes once and
/// replays the original request. If the refresh also fails, [onSessionExpired]
/// fires so the UI can bounce the user to the login screen.
class ApiClient {
  ApiClient(this.tokens) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {'Accept': 'application/json'},
        // Let the interceptor decide - never throw for 401 before we retry.
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = tokens.accessToken;
          if (token != null && options.extra['skipAuth'] != true) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          final status = response.statusCode ?? 0;

          if (status == 401 &&
              response.requestOptions.extra['isRetry'] != true &&
              response.requestOptions.extra['skipAuth'] != true &&
              tokens.refreshToken != null) {
            final refreshed = await _refresh();
            if (refreshed) {
              try {
                final retried = await _replay(response.requestOptions);
                return handler.resolve(retried);
              } catch (e) {
                if (e is DioException && e.response != null) {
                  return handler.resolve(e.response!);
                }
                return handler.reject(
                  DioException(
                    requestOptions: response.requestOptions,
                    response: response,
                  ),
                );
              }
            }
            await tokens.clear();
            onSessionExpired?.call();
          }

          if (status >= 400) {
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
          }
          handler.next(response);
        },
      ),
    );
  }

  final TokenStore tokens;
  late final Dio dio;

  /// Called when the refresh token is dead and the user must log in again.
  void Function()? onSessionExpired;

  Completer<bool>? _refreshing;

  Future<bool> _refresh() {
    // Collapse concurrent 401s into one refresh call.
    if (_refreshing != null) return _refreshing!.future;
    final completer = Completer<bool>();
    _refreshing = completer;

    Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl))
        .post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': tokens.refreshToken},
        )
        .then((res) async {
          final data = res.data;
          if (data == null ||
              data['accessToken'] == null ||
              data['refreshToken'] == null) {
            completer.complete(false);
          } else {
            await tokens.updateTokens(
              access: data['accessToken'] as String,
              refresh: data['refreshToken'] as String,
            );
            completer.complete(true);
          }
        })
        .catchError((_) => completer.complete(false))
        .whenComplete(() => _refreshing = null);

    return completer.future;
  }

  Future<Response<dynamic>> _replay(RequestOptions o) {
    return dio.request<dynamic>(
      o.path,
      data: o.data,
      queryParameters: o.queryParameters,
      options: Options(
        method: o.method,
        headers: {...o.headers, 'Authorization': 'Bearer ${tokens.accessToken}'},
        contentType: o.contentType,
        responseType: o.responseType,
        extra: {...o.extra, 'isRetry': true},
      ),
    );
  }

  // ── verbs ───────────────────────────────────────────────────

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _run<T>(() => dio.get<T>(path, queryParameters: _clean(query)));

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool skipAuth = false,
  }) =>
      _run<T>(
        () => dio.post<T>(
          path,
          data: body,
          queryParameters: _clean(query),
          options: Options(extra: {'skipAuth': skipAuth}),
        ),
      );

  Future<T> patch<T>(String path, {Object? body}) =>
      _run<T>(() => dio.patch<T>(path, data: body));

  Future<T> delete<T>(String path) => _run<T>(() => dio.delete<T>(path));

  Future<T> postMultipart<T>(String path, FormData form) =>
      _run<T>(() => dio.post<T>(path, data: form));

  Future<T> _run<T>(Future<Response<T>> Function() call) async {
    try {
      final res = await call();
      return res.data as T;
    } on DioException catch (e) {
      throw ApiException.from(e);
    } catch (e) {
      throw ApiException('Unexpected error: $e');
    }
  }

  static Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    final out = <String, dynamic>{};
    q.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      out[k] = v;
    });
    return out.isEmpty ? null : out;
  }
}
