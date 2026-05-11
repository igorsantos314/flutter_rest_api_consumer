import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_rest_api_consumer/data/network/api_exceptions.dart';
import 'package:flutter_rest_api_consumer/data/network/auth_token_store.dart';
import 'package:flutter_rest_api_consumer/data/network/network_activity_notifier.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

class DioClient {
  DioClient({
    required Dio dio,
    required AuthTokenStore tokenStore,
    required NetworkActivityNotifier networkActivity,
    this.baseUrl = 'http://localhost:3000/api/v1',
  }) : _dio = dio,
       _tokenStore = tokenStore,
       _networkActivity = networkActivity,
       _refreshDio = Dio() {
    _dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      responseType: ResponseType.json,
    );

    _refreshDio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      responseType: ResponseType.json,
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final skipLoader = options.extra['skipGlobalLoader'] == true;
          if (!skipLoader) {
            _networkActivity.startRequest();
          }

          final requiresAuth = options.extra['requiresAuth'] != false;
          if (requiresAuth && _tokenStore.hasAccessToken) {
            options.headers['Authorization'] =
                'Bearer ${_tokenStore.accessToken}';
          }

          handler.next(options);
        },
        onResponse: (response, handler) {
          final skipLoader =
              response.requestOptions.extra['skipGlobalLoader'] == true;
          if (!skipLoader) {
            _networkActivity.finishRequest();
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          final skipLoader =
              error.requestOptions.extra['skipGlobalLoader'] == true;
          if (!skipLoader) {
            _networkActivity.finishRequest();
          }

          final shouldRefresh =
              error.response?.statusCode == 401 &&
              error.requestOptions.extra['retryAfterRefresh'] != false &&
              (error.requestOptions.extra['isRefreshCall'] != true);

          if (shouldRefresh) {
            final retried = await _retryWithRefresh(error.requestOptions);
            if (retried != null) {
              handler.resolve(retried);
              return;
            }
          }

          handler.reject(_mapDioError(error));
        },
      ),
    );

    _dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        compact: true,
        enabled: !kReleaseMode,
      ),
    );
  }

  final Dio _dio;
  final Dio _refreshDio;
  final AuthTokenStore _tokenStore;
  final NetworkActivityNotifier _networkActivity;
  final String baseUrl;

  bool _isRefreshing = false;
  Completer<void>? _refreshCompleter;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    bool skipGlobalLoader = false,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
      options: Options(
        extra: {
          'requiresAuth': requiresAuth,
          'skipGlobalLoader': skipGlobalLoader,
          'retryAfterRefresh': true,
        },
      ),
    );

    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    bool skipGlobalLoader = false,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(
        extra: {
          'requiresAuth': requiresAuth,
          'skipGlobalLoader': skipGlobalLoader,
          'retryAfterRefresh': true,
        },
      ),
    );

    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    bool skipGlobalLoader = false,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(
        extra: {
          'requiresAuth': requiresAuth,
          'skipGlobalLoader': skipGlobalLoader,
          'retryAfterRefresh': true,
        },
      ),
    );

    return response.data ?? <String, dynamic>{};
  }

  Future<Response<dynamic>?> _retryWithRefresh(
    RequestOptions requestOptions,
  ) async {
    final refreshToken = _tokenStore.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      _tokenStore.clear();
      return null;
    }

    if (_isRefreshing) {
      await _refreshCompleter?.future;
    } else {
      _isRefreshing = true;
      _refreshCompleter = Completer<void>();
      try {
        final refreshed = await _refreshDio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
          options: Options(
            extra: {'isRefreshCall': true, 'requiresAuth': false},
          ),
        );

        final data = refreshed.data ?? <String, dynamic>{};
        final payload = data['data'];
        if (payload is! Map<String, dynamic>) {
          throw const UnauthorizedException('Resposta de refresh invalida');
        }

        final newAccessToken = payload['accessToken'];
        if (newAccessToken is! String || newAccessToken.isEmpty) {
          throw const UnauthorizedException('Access token invalido');
        }

        _tokenStore.setTokens(accessToken: newAccessToken);
        _refreshCompleter?.complete();
      } catch (_) {
        _tokenStore.clear();
        _refreshCompleter?.completeError(const UnauthorizedException());
      } finally {
        _isRefreshing = false;
      }
    }

    if (!_tokenStore.hasAccessToken) {
      return null;
    }

    final headers = Map<String, dynamic>.from(requestOptions.headers);
    headers['Authorization'] = 'Bearer ${_tokenStore.accessToken}';

    final retryOptions = Options(
      method: requestOptions.method,
      headers: headers,
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
      extra: {...requestOptions.extra, 'retryAfterRefresh': false},
    );

    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: retryOptions,
    );
  }

  DioException _mapDioError(DioException error) {
    final responseData = error.response?.data;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return error.copyWith(error: const NetworkException());
    }

    final status = error.response?.statusCode ?? 0;
    if (status == 401) {
      return error.copyWith(error: const UnauthorizedException());
    }

    if (status == 400 || status == 422) {
      final message = responseData is Map<String, dynamic>
          ? ((responseData['error'] as Map<String, dynamic>?)?['message']
                as String?)
          : null;
      return error.copyWith(
        error: ValidationApiException(message ?? 'Erro de validacao da API'),
      );
    }

    if (status >= 500) {
      return error.copyWith(error: const ServerException());
    }

    return error.copyWith(
      error: ApiException(error.message ?? 'Erro inesperado de rede'),
    );
  }
}
