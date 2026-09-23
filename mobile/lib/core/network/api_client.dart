import 'dart:async';

import 'package:dio/dio.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';

final class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStorage tokenStorage,
    Dio? refreshClient,
  })  : _tokenStorage = tokenStorage,
        _refreshClient = refreshClient ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
                headers: const {'Accept': 'application/json'},
              ),
            ),
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

  static const _nonRefreshableAuthPaths = {
    '/auth/cadastro',
    '/auth/login',
    '/auth/logout',
    '/auth/refresh',
  };

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
    final requestPath = Uri.parse(request.path).path;
    final mayRefresh = error.response?.statusCode == 401 &&
        request.extra['retried_after_refresh'] != true &&
        !_nonRefreshableAuthPaths.contains(requestPath);

    if (!mayRefresh) {
      handler.next(error);
      return;
    }

    try {
      if (!await _refreshTokens()) {
        handler.next(error);
        return;
      }
    } on DioException catch (refreshError) {
      handler.next(refreshError);
      return;
    } catch (_) {
      handler.next(error);
      return;
    }

    try {
      request.extra['retried_after_refresh'] = true;
      if (request.data is FormData) {
        request.data = (request.data as FormData).clone();
      }
      final token = await _tokenStorage.readAccessToken();
      request.headers['Authorization'] = 'Bearer $token';
      handler.resolve(await _refreshClient.fetch<Object?>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (_) {
      handler.next(error);
    }
  }

  Future<bool> _refreshTokens() {
    return _refreshing ??=
        _performRefresh().whenComplete(() => _refreshing = null);
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
      // Uma resposta atrasada não pode restaurar uma conta após sair/trocá-la.
      if (await _tokenStorage.readRefreshToken() != refreshToken) return false;
      await _tokenStorage.write(
        accessToken: data['access_token']! as String,
        refreshToken: data['refresh_token']! as String,
      );
      return true;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        if (await _tokenStorage.readRefreshToken() == refreshToken) {
          await _tokenStorage.clear();
        }
        return false;
      }
      rethrow;
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
        if (first is Map) {
          final location = first['loc'];
          final field =
              location is List && location.isNotEmpty ? location.last : null;
          if (field == 'modelo' &&
              const {'string_too_short', 'missing'}.contains(first['type'])) {
            return 'Informe o modelo do projeto.';
          }
          return 'Confira os campos informados e tente novamente.';
        }
      }
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Não foi possível conectar à API.';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'A conexão demorou mais que o esperado. Tente novamente.';
    }
  }
  return 'Algo deu errado. Tente novamente.';
}
