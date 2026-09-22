import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/features/auth/auth_repository.dart';
import 'package:garagem_mobile/features/auth/session_controller.dart';
import 'package:garagem_mobile/features/auth/user.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/home/home_shell.dart';
import 'package:garagem_mobile/features/notifications/notifications_repository.dart';
import 'package:garagem_mobile/features/profile/users_repository.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

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

void main() {
  testWidgets('atualiza as áreas do app depois de voltar do segundo plano',
      (tester) async {
    final requests = <String, int>{};
    var unread = 107;
    var read = false;
    var evolutionNotice = false;
    var missingEvolution = false;
    RequestInterceptorHandler? pendingEvolution;
    final tokens = _EmptyTokenStorage();
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: tokens,
    );
    api.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.update(options.path, (count) => count + 1, ifAbsent: () => 1);
        if (options.path == '/carros/car/evolucoes/evo') {
          if (missingEvolution) {
            handler.reject(DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 404,
                data: <String, Object?>{
                  'detail': 'Evolucao nao encontrada.',
                },
              ),
            ));
            return;
          }
          pendingEvolution = handler;
          return;
        }
        if (options.path == '/notificacoes/lidas') {
          unread = 0;
          read = true;
        }
        final Object data = switch (options.path) {
          '/carros' => <String, Object?>{
              'itens': <Object?>[],
              'proximo_cursor': null,
            },
          '/notificacoes/nao-lidas' => <String, Object?>{'total': unread},
          '/notificacoes' => [
              {
                'id': 'notice',
                'tipo': evolutionNotice
                    ? 'curtida_evolucao'
                    : 'solicitacao_equipe_recusada',
                'mensagem': evolutionNotice
                    ? 'Nova curtida.'
                    : 'Seu pedido foi recusado.',
                'carro_id': evolutionNotice ? 'car' : null,
                'evolucao_id': evolutionNotice ? 'evo' : null,
                'criada_em': '2026-09-21T12:00:00Z',
                'lida_em': read ? '2026-09-21T13:00:00Z' : null,
              }
            ],
          '/usuarios/raul' => <String, Object?>{
              'id': 'raul',
              'nome': 'Raul',
              'username': 'raul',
              'avatar_url': null,
              'bio': null,
              'cidade': null,
              'estado': null,
              'total_projetos': 0,
              'total_seguidores': 0,
              'total_seguindo': 0,
              'seguido_por_mim': false,
            },
          _ => <Object?>[],
        };
        handler.resolve(Response(requestOptions: options, data: data));
      },
    ));

    final session = SessionController(
      repository: AuthRepository(api, tokens),
    )
      ..status = SessionStatus.authenticated
      ..user = const User(
        id: 'raul',
        name: 'Raul',
        username: 'raul',
        email: 'raul@example.com',
      );

    await tester.pumpWidget(MaterialApp(
      home: HomeShell(
        session: session,
        carsRepository: CarsRepository(api),
        evolutionsRepository: EvolutionsRepository(api),
        notificationsRepository: NotificationsRepository(api),
        teamsRepository: TeamsRepository(api),
        usersRepository: UsersRepository(api),
      ),
    ));
    await tester.pumpAndSettle();

    expect(requests['/carros'], 1);
    expect(requests['/carros/meus'], 2);
    expect(requests['/equipes'], 1);
    expect(requests['/notificacoes'], isNull);
    expect(requests['/notificacoes/nao-lidas'], 1);
    expect(requests['/usuarios/raul'], 1);

    await tester.tap(find.text('Garagem'));
    await tester.pumpAndSettle();
    expect(find.text('Sua garagem, sua história'), findsOneWidget);

    final beforeResume = Map<String, int>.from(requests);
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Sua garagem, sua história'), findsOneWidget);
    expect(requests['/carros'], beforeResume['/carros']! + 1);
    expect(requests['/carros/meus'], beforeResume['/carros/meus']! + 1);
    expect(requests['/equipes'], beforeResume['/equipes']! + 1);
    expect(requests['/notificacoes'], isNull);
    expect(
      requests['/notificacoes/nao-lidas'],
      beforeResume['/notificacoes/nao-lidas']! + 1,
    );
    expect(
      requests['/usuarios/raul'],
      1,
      reason: 'O perfil preserva o estado durante a atualização do restante.',
    );

    expect(find.byKey(const ValueKey('nav-4')), findsNothing);
    expect(find.byKey(const ValueKey('activity-bell')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();
    expect(find.text('99+'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('activity-bell')));
    await tester.pumpAndSettle();
    expect(find.text('Atividade'), findsOneWidget);
    expect(requests['/notificacoes'], 1);
    expect(requests['/notificacoes/lidas'], 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(requests['/notificacoes'], 2);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('99+'), findsNothing);
    expect(find.text('Projetos para descobrir'), findsOneWidget);

    // A refused private-team request returns to the team directory.
    await tester.tap(find.byKey(const ValueKey('activity-bell')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seu pedido foi recusado.'));
    await tester.pumpAndSettle();
    expect(find.text('Atividade'), findsNothing);
    expect(find.byKey(const ValueKey('activity-bell')), findsNothing);
    expect(find.byTooltip('Buscar equipes'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // A late destination response must not open a screen after leaving activity.
    evolutionNotice = true;
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity-bell')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova curtida.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova curtida.'));
    await tester.pumpAndSettle();
    expect(requests['/carros/car/evolucoes/evo'], 1);
    await tester.pageBack();
    await tester.pumpAndSettle();
    pendingEvolution!.resolve(Response(
      requestOptions: RequestOptions(path: '/carros/car/evolucoes/evo'),
      data: <String, Object?>{
        'id': 'evo',
        'carro_id': 'car',
        'titulo': 'Evolução tardia',
        'descricao': 'Descrição',
        'criado_em': '2026-09-21T12:00:00Z',
        'autor': <String, Object?>{'nome': 'Raul', 'username': 'raul'},
      },
    ));
    await tester.pumpAndSettle();
    expect(find.text('Evolução do projeto'), findsNothing);
    expect(find.byTooltip('Buscar'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Conteúdo removido recebe uma mensagem contextual em português correto.
    missingEvolution = true;
    await tester.tap(find.byKey(const ValueKey('activity-bell')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova curtida.'));
    await tester.pumpAndSettle();
    expect(
      find.text('Esta evolução não está mais disponível.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
