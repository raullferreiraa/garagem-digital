import 'dart:async';

import 'package:dio/dio.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';

final class ApiClient {
  ApiClient({required String baseUrl, required TokenStorage tokenStorage})
      : _tokenStorage = tokenStorage,
        _refreshClient = Dio(BaseOptions(baseUrl: baseUrl)),
        dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            headers: const {'Accept': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: _authorize,
        onError: _recoverUnauthorized,
      ),
    );
  }

  final Dio dio;
  final Dio _refreshClient;
  final TokenStorage _tokenStorage;
  Future<bool>? _refreshing;

  Future<void> _authorize(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.readAccessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  Future<void> _recoverUnauthorized(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final mayRefresh = error.response?.statusCode == 401 &&
        request.extra['retried_after_refresh'] != true &&
        !request.path.contains('/auth/refresh');

    if (!mayRefresh || !await _refreshTokens()) {
      handler.next(error);
      return;
    }

    try {
      request.extra['retried_after_refresh'] = true;
      final token = await _tokenStorage.readAccessToken();
      request.headers['Authorization'] = 'Bearer $token';
      handler.resolve(await dio.fetch<Object?>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<bool> _refreshTokens() {
    return _refreshing ??= _performRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await _refreshClient.post<Map<String, Object?>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data;
      if (data == null) return false;
      await _tokenStorage.write(
        accessToken: data['access_token']! as String,
        refreshToken: data['refresh_token']! as String,
      );
      return true;
    } on DioException {
      await _tokenStorage.clear();
      return false;
    }
  }
}

String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, Object?>) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) return first['msg'] as String;
      }
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Nao foi possivel conectar a API.';
    }
  }
  return 'Algo deu errado. Tente novamente.';
}
