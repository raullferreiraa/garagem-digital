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
  Future<void> write({required String accessToken, required String refreshToken})
      async {}

  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('atualiza as áreas do app depois de voltar do segundo plano',
      (tester) async {
    final requests = <String, int>{};
    final tokens = _EmptyTokenStorage();
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: tokens,
    );
    api.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.update(options.path, (count) => count + 1,
            ifAbsent: () => 1);
        final Object data = switch (options.path) {
          '/carros' => <String, Object?>{
              'itens': <Object?>[],
              'proximo_cursor': null,
            },
          '/notificacoes/nao-lidas' => <String, Object?>{'total': 0},
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
    expect(requests['/notificacoes'], 1);
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
    expect(requests['/notificacoes'], beforeResume['/notificacoes']! + 1);
    expect(
      requests['/notificacoes/nao-lidas'],
      beforeResume['/notificacoes/nao-lidas']! + 1,
    );
    expect(
      requests['/usuarios/raul'],
      1,
      reason: 'O perfil preserva o estado durante a atualização do restante.',
    );
  });
}
