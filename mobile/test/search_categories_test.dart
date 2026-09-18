import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/discovery/search_screen.dart';
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
  testWidgets('busca apenas a categoria selecionada', (tester) async {
    final paths = <String>[];
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    api.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        paths.add(options.path);
        final data = options.path == '/carros'
            ? <String, Object?>{'itens': <Object?>[]}
            : <Object?>[];
        handler.resolve(Response(requestOptions: options, data: data));
      },
    ));

    await tester.pumpWidget(MaterialApp(
      home: SearchScreen(
        carsRepository: CarsRepository(api),
        usersRepository: UsersRepository(api),
        teamsRepository: TeamsRepository(api),
        onCarTap: (_) async {},
        onUserTap: (_) async {},
        onTeamTap: (_) async {},
      ),
    ));

    await tester.enterText(find.byType(TextField), 'Omega');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(paths, ['/carros']);

    await tester.tap(find.text('Pessoas'));
    await tester.pumpAndSettle();
    expect(paths, ['/carros', '/usuarios']);

    await tester.tap(find.text('Equipes'));
    await tester.pumpAndSettle();
    expect(paths, ['/carros', '/usuarios', '/equipes']);
  });

  testWidgets('abre diretamente na busca de equipes', (tester) async {
    final paths = <String>[];
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    api.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        paths.add(options.path);
        handler.resolve(Response(
          requestOptions: options,
          data: <Object?>[],
        ));
      },
    ));

    await tester.pumpWidget(MaterialApp(
      home: SearchScreen(
        initialCategory: SearchCategory.teams,
        carsRepository: CarsRepository(api),
        usersRepository: UsersRepository(api),
        teamsRepository: TeamsRepository(api),
        onCarTap: (_) async {},
        onUserTap: (_) async {},
        onTeamTap: (_) async {},
      ),
    ));

    expect(find.text('Nome ou localização da equipe'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Turbo');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(paths, ['/equipes']);
  });
}
