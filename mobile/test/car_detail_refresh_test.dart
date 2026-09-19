import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_detail_screen.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';

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
}
