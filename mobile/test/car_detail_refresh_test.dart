import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garona_mobile/core/network/api_client.dart';
import 'package:garona_mobile/core/storage/token_storage.dart';
import 'package:garona_mobile/features/cars/car.dart';
import 'package:garona_mobile/features/cars/car_detail_screen.dart';
import 'package:garona_mobile/features/cars/cars_repository.dart';
import 'package:garona_mobile/features/evolutions/evolution.dart';
import 'package:garona_mobile/features/evolutions/evolutions_repository.dart';

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

Map<String, Object?> _carJson(String model) => {
      'id': 'omega',
      'modelo': model,
      'foto_principal_url': null,
      'placa': null,
      'proprietario': <String, Object?>{
        'id': 'raul',
        'nome': 'Raul',
        'username': 'raul.omega',
        'avatar_url': null,
      },
    };

Map<String, Object?> _evolutionJson() => {
      'id': 'evolution-1',
      'carro_id': 'omega',
      'titulo': 'Revisão completa',
      'descricao': 'Óleo, filtros e velas substituídos.',
      'categoria': 'manutencao',
      'ocorreu_em': '2026-09-05T12:00:00Z',
      'quilometragem_km': 185000,
      'fotos': <Object?>[],
      'criado_em': '2026-09-05T13:00:00Z',
      'autor': <String, Object?>{
        'id': 'raul',
        'nome': 'Raul',
        'username': 'raul.omega',
        'avatar_url': null,
      },
    };

void main() {
  testWidgets('editar evolução mantém o cartão selecionado no diário',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final second = {
      ..._evolutionJson(),
      'id': 'evolution-2',
      'titulo': 'Pintura nova',
      'ocorreu_em': '2026-08-02T12:00:00Z',
    };
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response(
        requestOptions: options,
        data: options.path == '/carros/omega'
            ? _carJson('OMEGA')
            : <Object?>[_evolutionJson(), second],
      ));
    }));
    await tester.pumpWidget(MaterialApp(
      home: CarDetailScreen(
        car: const Car(
          id: 'omega',
          model: 'OMEGA',
          ownerId: 'raul',
          ownerName: 'Raul',
          ownerUsername: 'raul.omega',
        ),
        repository: CarsRepository(api),
        evolutionsRepository: EvolutionsRepository(api),
        canManage: true,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(PageView), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byType(PageView));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 de 2 evoluções'), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('evolution-2')),
      matching: find.byTooltip('Opções da evolução'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Editar evolução'))).pop(
      Evolution.fromJson({...second, 'titulo': 'Pintura concluída'}),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 de 2 evoluções'), findsOneWidget);
    expect(find.text('Pintura concluída'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('diário filtra evoluções por categoria', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response(
        requestOptions: options,
        data: options.path == '/carros/omega'
            ? _carJson('OMEGA')
            : <Object?>[
                _evolutionJson(),
                {
                  ..._evolutionJson(),
                  'id': 'evolution-2',
                  'titulo': 'Pintura nova',
                  'categoria': 'estetica',
                  'ocorreu_em': '2025-08-02T12:00:00Z',
                },
              ],
      ));
    }));
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.4),
        ),
        child: child!,
      ),
      home: CarDetailScreen(
        car: const Car(
          id: 'omega',
          model: 'OMEGA',
          ownerId: 'raul',
          ownerName: 'Raul',
          ownerUsername: 'raul.omega',
        ),
        repository: CarsRepository(api),
        evolutionsRepository: EvolutionsRepository(api),
        canManage: true,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ChoiceChip, 'Estética'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Estética'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Estética'));
    await tester.pumpAndSettle();
    expect(find.text('Pintura nova'), findsOneWidget);
    expect(find.text('Revisão completa'), findsNothing);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Todas'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Todas'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Revisão completa'));
    await tester.pumpAndSettle();
    expect(find.text('Revisão completa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'projeto próprio aberto pelo feed libera edição e busca placa privada',
      (tester) async {
    final requested = <String>[];
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requested.add(options.path);
      handler.resolve(Response(
        requestOptions: options,
        data: options.path == '/carros/omega/meu'
            ? {..._carJson('OMEGA'), 'placa': 'ABC1D23', 'placa_visivel': false}
            : <Object?>[],
      ));
    }));
    await tester.pumpWidget(MaterialApp(
      home: CarDetailScreen(
        car: const Car(
          id: 'omega',
          model: 'OMEGA',
          ownerId: 'raul',
          ownerName: 'Raul',
          ownerUsername: 'raul.omega',
        ),
        repository: CarsRepository(api),
        evolutionsRepository: EvolutionsRepository(api),
        canManage: false,
        currentUserId: 'raul',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Salvar projeto'), findsNothing);
    expect(find.byTooltip('Alterar foto principal'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byTooltip('Registrar evolução'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byTooltip('Registrar evolução'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar projeto'));
    await tester.pumpAndSettle();
    expect(requested, contains('/carros/omega/meu'));
    expect(find.text('Editar carro'), findsOneWidget);
    expect(find.text('ABC1D23'), findsWidgets);
  });

  testWidgets('foto principal abre inteira sem substituir ação de edição',
      (tester) async {
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response(
        requestOptions: options,
        data: options.path == '/carros/omega'
            ? {
                ..._carJson('OMEGA'),
                'foto_principal_url': 'https://example.com/omega.jpg'
              }
            : <Object?>[],
      ));
    }));

    await tester.pumpWidget(MaterialApp(
      home: CarDetailScreen(
        car: const Car(
          id: 'omega',
          model: 'OMEGA',
          ownerId: 'raul',
          ownerName: 'Raul',
          ownerUsername: 'raul.omega',
          photoUrl: 'https://example.com/omega.jpg',
        ),
        repository: CarsRepository(api),
        evolutionsRepository: EvolutionsRepository(api),
        canManage: true,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Alterar foto principal'), findsOneWidget);
    await tester.tap(find.byTooltip('Ver foto inteira'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('Alterar foto principal'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Alterar foto principal'), findsOneWidget);
  });

  testWidgets('atualiza o projeto ao abrir e ao puxar a tela', (tester) async {
    var carRequests = 0;
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    api.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/carros/omega') {
          carRequests++;
          final model = carRequests == 1 ? 'OMEGA ATUAL' : 'OMEGA TURBO';
          handler.resolve(Response(
            requestOptions: options,
            data: _carJson(model),
          ));
          return;
        }
        if (options.path == '/carros/omega/evolucoes') {
          handler.resolve(Response(
            requestOptions: options,
            data: <Object?>[_evolutionJson()],
          ));
          return;
        }
        handler.resolve(Response(
          requestOptions: options,
          data: <Object?>[],
        ));
      },
    ));

    await tester.pumpWidget(MaterialApp(
      home: CarDetailScreen(
        car: const Car(
          id: 'omega',
          model: 'OMEGA ANTIGO',
          ownerId: 'raul',
          ownerName: 'Raul',
          ownerUsername: 'raul.omega',
          plate: 'ABC1D23',
          plateVisible: false,
        ),
        repository: CarsRepository(api),
        evolutionsRepository: EvolutionsRepository(api),
        canManage: true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('OMEGA ATUAL'), findsWidgets);
    expect(find.text('OMEGA ANTIGO'), findsNothing);
    expect(carRequests, 1);

    final refresh = tester.state<RefreshIndicatorState>(
      find.byType(RefreshIndicator),
    );
    final refreshFuture = refresh.show();
    await tester.pumpAndSettle();
    await refreshFuture;

    expect(find.text('OMEGA TURBO'), findsWidgets);
    expect(find.text('OMEGA ATUAL'), findsNothing);
    expect(carRequests, 2);
    await tester.scrollUntilVisible(
      find.text('1 registro'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 registro'), findsOneWidget);
    expect(find.text('05/09/2026'), findsWidgets);
    expect(find.text('185.000 km'), findsWidgets);
  });

  testWidgets('ignora resposta inicial antiga depois da edição',
      (tester) async {
    final carRequests = <RequestInterceptorHandler>[];
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    api.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/carros/omega') {
          carRequests.add(handler);
          return;
        }
        handler.resolve(Response(
          requestOptions: options,
          data: <Object?>[],
        ));
      },
    ));

    await tester.pumpWidget(MaterialApp(
      home: CarDetailScreen(
        car: const Car(
          id: 'omega',
          model: 'OMEGA INICIAL',
          ownerId: 'raul',
          ownerName: 'Raul',
          ownerUsername: 'raul.omega',
        ),
        repository: CarsRepository(api),
        evolutionsRepository: EvolutionsRepository(api),
        canManage: true,
      ),
    ));
    await tester.pumpAndSettle();
    expect(carRequests, hasLength(1));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar projeto'));
    await tester.pumpAndSettle();
    expect(find.text('Editar carro'), findsOneWidget);

    Navigator.of(tester.element(find.text('Editar carro'))).pop(const Car(
      id: 'omega',
      model: 'OMEGA NOVO',
      ownerId: 'raul',
      ownerName: 'Raul',
      ownerUsername: 'raul.omega',
    ));
    await tester.pumpAndSettle();
    expect(find.text('OMEGA NOVO'), findsWidgets);

    carRequests[0].resolve(Response(
      requestOptions: RequestOptions(path: '/carros/omega'),
      data: _carJson('OMEGA ANTIGO'),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('OMEGA NOVO'), findsWidgets);
    expect(find.text('OMEGA ANTIGO'), findsNothing);
  });
}
