import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garona_mobile/core/network/api_client.dart';
import 'package:garona_mobile/core/storage/token_storage.dart';
import 'package:garona_mobile/features/cars/cars_repository.dart';
import 'package:garona_mobile/features/discovery/search_screen.dart';
import 'package:garona_mobile/features/profile/users_repository.dart';
import 'package:garona_mobile/features/teams/teams_repository.dart';

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

Map<String, Object?> _car(String id, String model, int year) => {
      'id': id,
      'modelo': model,
      'ano': year,
      'proprietario': <String, Object?>{
        'id': 'dono',
        'nome': 'Dono',
        'username': 'dono',
      },
    };

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

  testWidgets('mostra em qual dado do projeto a busca encontrou o termo',
      (tester) async {
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    api.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(Response(
          requestOptions: options,
          data: <String, Object?>{
            'itens': <Object?>[
              <String, Object?>{
                'id': 'omega',
                'modelo': 'OMEGA CD 4.1',
                'ano': 1996,
                'cor': 'BORDÔ',
                'proprietario': <String, Object?>{
                  'id': 'raul',
                  'nome': 'Raul',
                  'username': 'raul.omega',
                  'avatar_url': null,
                },
              },
            ],
            'proximo_cursor': null,
          },
        ));
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

    await tester.enterText(find.byType(TextField), 'bordô');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('OMEGA CD 4.1 1996'), findsOneWidget);
    expect(find.textContaining('Cor: BORDÔ'), findsOneWidget);
  });

  testWidgets('busca carrega mais projetos sem duplicar resultados',
      (tester) async {
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    final queries = <Map<String, dynamic>>[];
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      queries.add(options.queryParameters);
      final more = options.queryParameters['cursor'] == 'next';
      handler.resolve(Response(
        requestOptions: options,
        data: <String, Object?>{
          'itens': more
              ? [
                  _car('omega-1', 'OMEGA CD', 1996),
                  _car('omega-2', 'OMEGA GLS', 1998)
                ]
              : [_car('omega-1', 'OMEGA CD', 1996)],
          'proximo_cursor': more ? null : 'next',
        },
      ));
    }));
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
    await tester.tap(find.text('Carregar mais projetos'));
    await tester.pumpAndSettle();

    expect(queries, hasLength(2));
    expect(queries.last['busca'], 'Omega');
    expect(queries.last['cursor'], 'next');
    expect(find.text('OMEGA CD 1996'), findsOneWidget);
    expect(find.text('OMEGA GLS 1998'), findsOneWidget);
    expect(find.text('Carregar mais projetos'), findsNothing);
  });

  testWidgets('busca aplica faixa de ano e valida intervalo', (tester) async {
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    final queries = <Map<String, dynamic>>[];
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      queries.add(options.queryParameters);
      handler.resolve(Response(
        requestOptions: options,
        data: <String, Object?>{
          'itens': [_car('omega-1', 'OMEGA CD', 1996)],
          'proximo_cursor': null,
        },
      ));
    }));
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
    await tester.tap(find.text('Filtrar por ano'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '2000');
    await tester.enterText(find.byType(TextField).at(2), '1990');
    await tester.tap(find.text('Aplicar filtro'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Use anos entre 1886'), findsOneWidget);
    expect(queries, hasLength(1));

    await tester.enterText(find.byType(TextField).at(1), '1990');
    await tester.enterText(find.byType(TextField).at(2), '1999');
    await tester.tap(find.text('Aplicar filtro'));
    await tester.pumpAndSettle();
    expect(queries.last['ano_min'], 1990);
    expect(queries.last['ano_max'], 1999);
    expect(find.text('Ano: 1990–1999'), findsOneWidget);

    await tester.tap(find.text('Ano: 1990–1999'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar filtro de ano'));
    await tester.pumpAndSettle();
    expect(queries.last.containsKey('ano_min'), isFalse);
    expect(queries.last.containsKey('ano_max'), isFalse);
    expect(find.text('Filtrar por ano'), findsOneWidget);
  });
}
