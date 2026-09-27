import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/evolutions/following_feed.dart';

final class _EmptyTokenStorage implements TokenStorage {
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<String?> readRefreshToken() async => null;
  @override
  Future<void> write(
      {required String accessToken, required String refreshToken}) async {}
  @override
  Future<void> clear() async {}
}

Map<String, Object?> _feedItem(String id) => {
      'evolucao': {
        'id': id,
        'carro_id': 'carro-1',
        'titulo': 'Evolução $id',
        'descricao': 'História do projeto',
        'criado_em': '2026-09-01T12:00:00Z',
        'fotos': <Object?>[],
        'autor': {'nome': 'Raul', 'username': 'raul'},
      },
      'carro': {
        'id': 'carro-1',
        'modelo': 'Omega',
        'proprietario': {
          'id': 'raul',
          'nome': 'Raul',
          'username': 'raul',
        },
      },
    };

void main() {
  testWidgets('Seguindo carrega mais e não repete evoluções', (tester) async {
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    final cursors = <String?>[];
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      expect(options.path, '/feed/seguindo/pagina');
      final cursor = options.queryParameters['cursor'] as String?;
      cursors.add(cursor);
      handler.resolve(Response(
        requestOptions: options,
        data: cursor == null
            ? {
                'itens': [_feedItem('primeira')],
                'proximo_cursor': 'pagina-2',
              }
            : {
                'itens': [_feedItem('primeira'), _feedItem('segunda')],
                'proximo_cursor': null,
              },
      ));
    }));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FollowingFeed(
          repository: EvolutionsRepository(api),
          onEvolutionTap: (_) async {},
          onProfileTap: (_) async {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Evolução primeira'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('Carregar mais atualizações'), 300);
    await tester.tap(find.text('Carregar mais atualizações'));
    await tester.pumpAndSettle();
    expect(cursors, [null, 'pagina-2']);
    expect(find.text('Evolução primeira'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Evolução segunda'), 300);
    expect(find.text('Evolução segunda'), findsOneWidget);
    expect(find.text('Carregar mais atualizações'), findsNothing);
  });
}
