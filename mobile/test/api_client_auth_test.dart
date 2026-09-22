import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/core/theme/app_theme.dart';
import 'package:garagem_mobile/features/auth/auth_repository.dart';
import 'package:garagem_mobile/features/auth/login_screen.dart';
import 'package:garagem_mobile/features/auth/session_controller.dart';

final class _MemoryTokens implements TokenStorage {
  String? accessToken;
  String? refreshToken;

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> write({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }
}

final class _AuthAdapter implements HttpClientAdapter {
  int refreshRequests = 0;
  int protectedRequests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/auth/refresh')) {
      refreshRequests++;
      return _json(200, {
        'access_token': 'access-novo',
        'refresh_token': 'refresh-novo',
      });
    }
    if (path.endsWith('/auth/login')) {
      return _json(401, {
        'detail': 'Email, username ou senha incorretos.',
      });
    }
    if (path.endsWith('/auth/alterar-senha')) {
      return _json(400, {'detail': 'A senha atual está incorreta.'});
    }
    if (path.endsWith('/protegido')) {
      protectedRequests++;
      if (options.headers['Authorization'] == 'Bearer access-novo') {
        return _json(200, {'resultado': 'ok'});
      }
      return _json(401, {'detail': 'Token inválido.'});
    }
    return _json(404, {'detail': 'Não encontrado.'});
  }

  ResponseBody _json(int statusCode, Map<String, Object?> data) =>
      ResponseBody.fromString(
        jsonEncode(data),
        statusCode,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  void close({bool force = false}) {}
}

ApiClient _client(_MemoryTokens tokens, _AuthAdapter adapter) {
  final refreshClient = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
    ..httpClientAdapter = adapter;
  final client = ApiClient(
    baseUrl: 'http://localhost/api/v1',
    tokenStorage: tokens,
    refreshClient: refreshClient,
  );
  client.dio.httpClientAdapter = adapter;
  return client;
}

void main() {
  test('401 de credenciais não tenta renovar a sessão', () async {
    final tokens = _MemoryTokens()
      ..accessToken = 'access-antigo'
      ..refreshToken = 'refresh-antigo';
    final adapter = _AuthAdapter();
    final client = _client(tokens, adapter);

    await expectLater(
      client.dio.post<Object?>(
        '/auth/login',
        data: {
          'identificador': 'raul',
          'senha': 'errada-123',
        },
      ).timeout(const Duration(seconds: 1)),
      throwsA(isA<DioException>()),
    );

    expect(adapter.refreshRequests, 0);
    expect(tokens.refreshToken, 'refresh-antigo');
  });

  test('401 protegido renova uma vez e repete fora da fila original', () async {
    final tokens = _MemoryTokens()
      ..accessToken = 'access-antigo'
      ..refreshToken = 'refresh-antigo';
    final adapter = _AuthAdapter();
    final client = _client(tokens, adapter);

    final response = await client.dio
        .get<Map<String, Object?>>('/protegido')
        .timeout(const Duration(seconds: 1));

    expect(response.data, {'resultado': 'ok'});
    expect(adapter.refreshRequests, 1);
    expect(adapter.protectedRequests, 2);
    expect(tokens.accessToken, 'access-novo');
    expect(tokens.refreshToken, 'refresh-novo');
  });

  testWidgets('login incorreto deixa de carregar e apresenta a mensagem',
      (tester) async {
    final tokens = _MemoryTokens()
      ..accessToken = 'access-antigo'
      ..refreshToken = 'refresh-antigo';
    final adapter = _AuthAdapter();
    final client = _client(tokens, adapter);
    final session = SessionController(
      repository: AuthRepository(client, tokens),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LoginScreen(session: session),
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'raul');
    await tester.enterText(fields.at(1), 'senha-antiga-123');
    final submit = find.text('Entrar');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsOneWidget);
    expect(
      find.text('Email, username ou senha incorretos.'),
      findsOneWidget,
    );
    expect(adapter.refreshRequests, 0);
    expect(tester.takeException(), isNull);
  });
}
