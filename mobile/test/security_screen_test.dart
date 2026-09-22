import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/core/theme/app_theme.dart';
import 'package:garagem_mobile/features/auth/auth_repository.dart';
import 'package:garagem_mobile/features/auth/session_controller.dart';
import 'package:garagem_mobile/features/profile/security_screen.dart';

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

void main() {
  testWidgets('valida confirmação e renova os tokens ao alterar a senha',
      (tester) async {
    final tokens = _MemoryTokens()
      ..accessToken = 'access-antigo'
      ..refreshToken = 'refresh-antigo';
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: tokens,
    );
    Map<String, Object?>? payload;
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          payload = Map<String, Object?>.from(options.data! as Map);
          handler.resolve(
            Response<Map<String, Object?>>(
              requestOptions: options,
              data: {
                'access_token': 'access-novo',
                'refresh_token': 'refresh-novo',
                'usuario': {
                  'id': 'usuario',
                  'nome': 'Raul',
                  'username': 'raul',
                  'email': 'raul@example.com',
                },
              },
            ),
          );
        },
      ),
    );
    final session = SessionController(
      repository: AuthRepository(api, tokens),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: SecurityScreen(session: session),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'senha-atual-123');
    await tester.enterText(fields.at(1), 'senha-nova-456');
    await tester.enterText(fields.at(2), 'senha-diferente-789');
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atualizar senha'));
    await tester.pumpAndSettle();

    expect(find.text('As senhas não coincidem.'), findsOneWidget);
    expect(payload, isNull);

    await tester.enterText(fields.at(2), 'senha-nova-456');
    await tester.tap(find.text('Atualizar senha'));
    await tester.pumpAndSettle();

    expect(payload, {
      'senha_atual': 'senha-atual-123',
      'nova_senha': 'senha-nova-456',
    });
    expect(tokens.accessToken, 'access-novo');
    expect(tokens.refreshToken, 'refresh-novo');
    expect(session.user?.username, 'raul');
    expect(find.byType(SecurityScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
