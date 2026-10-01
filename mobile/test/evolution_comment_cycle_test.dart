import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garona_mobile/core/network/api_client.dart';
import 'package:garona_mobile/core/storage/token_storage.dart';
import 'package:garona_mobile/features/evolutions/evolution.dart';
import 'package:garona_mobile/features/evolutions/evolution_detail_screen.dart';
import 'package:garona_mobile/features/evolutions/evolutions_repository.dart';

class _Tokens implements TokenStorage {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<String?> readRefreshToken() async => null;
  @override
  Future<void> write(
      {required String accessToken, required String refreshToken}) async {}
}

final _evolution = Evolution(
  id: 'evolution-1',
  carId: 'car-1',
  title: 'Reforma',
  description: 'Atualização do projeto.',
  authorName: 'Raul',
  authorUsername: 'raul',
  createdAt: DateTime(2026, 9, 1),
);

Map<String, Object?> _comment({String content = 'Comentário original'}) => {
      'id': 'comment-1',
      'evolucao_id': 'evolution-1',
      'comentario_pai_id': null,
      'conteudo': content,
      'criado_em': '2026-09-01T12:00:00Z',
      'total_curtidas': 1,
      'curtido_por_mim': false,
      'respostas': <Object?>[],
      'autor': {
        'id': 'me',
        'nome': 'Raul',
        'username': 'raul',
        'avatar_url': null,
      },
    };

void main() {
  testWidgets('autor pode corrigir comentário e mantém a curtida',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final api =
        ApiClient(baseUrl: 'http://localhost/api/v1', tokenStorage: _Tokens());
    String? submitted;
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.method == 'PATCH') {
        submitted =
            (options.data as Map<String, Object?>)['conteudo'] as String;
        handler.resolve(Response(requestOptions: options, data: {
          ..._comment(content: submitted!),
          'editado_em': '2026-09-02T13:00:00Z',
        }));
      } else {
        handler.resolve(Response(requestOptions: options, data: {
          'total_curtidas': 0,
          'curtido_por_mim': false,
          'comentarios': [_comment()],
        }));
      }
    }));
    await tester.pumpWidget(MaterialApp(
      home: EvolutionDetailScreen(
        evolution: _evolution,
        repository: EvolutionsRepository(api),
        currentUserId: 'me',
      ),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byTooltip('Opções do comentário'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('Opções do comentário'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Comentário corrigido');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(submitted, 'Comentário corrigido');
    expect(find.text('Comentário corrigido'), findsOneWidget);
    expect(find.text('· Editado'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('rascunho de resposta volta com vínculo após reabrir evolução',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final api =
        ApiClient(baseUrl: 'http://localhost/api/v1', tokenStorage: _Tokens());
    String? postedPath;
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.method == 'POST') {
        postedPath = options.path;
        handler.resolve(Response(requestOptions: options, data: {
          ..._comment(content: 'Ainda escrevendo'),
          'id': 'reply-1',
          'comentario_pai_id': 'comment-1',
        }));
        return;
      }
      handler.resolve(Response(requestOptions: options, data: {
        'total_curtidas': 0,
        'curtido_por_mim': false,
        'comentarios': [_comment()],
      }));
    }));
    Widget screen() => MaterialApp(
          home: EvolutionDetailScreen(
            evolution: _evolution,
            repository: EvolutionsRepository(api),
            currentUserId: 'me',
          ),
        );
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Responder'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(ListView).first, const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Responder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ainda escrevendo');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.text('Respondendo a @raul'), findsOneWidget);
    expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'Ainda escrevendo');
    await tester.tap(find.byTooltip('Publicar resposta'));
    await tester.pumpAndSettle();
    expect(postedPath, endsWith('/comentarios/comment-1/respostas'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.text('Respondendo a @raul'), findsNothing);
    expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty);
  });
}
