import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/discovery/explore_screen.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';

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

Map<String, Object?> _car(String id, String model) => {
      'id': id,
      'modelo': model,
      'proprietario': {
        'id': 'owner',
        'nome': 'Raul',
        'username': 'raul',
      },
    };

void main() {
  testWidgets('Em alta carrega a próxima página mantendo a ordenação',
      (tester) async {
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    final requests = <Map<String, dynamic>>[];
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options.queryParameters);
      final trending = options.queryParameters['ordem'] == 'em_alta';
      final next = options.queryParameters['cursor'] == 'pagina-2';
      handler.resolve(Response(requestOptions: options, data: {
        'itens': trending
            ? [next ? _car('second', 'Opala SS') : _car('first', 'Omega CD')]
            : <Object?>[],
        'proximo_cursor': trending && !next ? 'pagina-2' : null,
      }));
    }));
    await tester.pumpWidget(MaterialApp(
      home: ExploreScreen(
        carsRepository: CarsRepository(api),
        evolutionsRepository: EvolutionsRepository(api),
        onCarTap: (_) async {},
        onEvolutionTap: (_) async {},
        onProfileTap: (_) async {},
        onSearch: () {},
        refreshRevision: 0,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Em alta'));
    await tester.pumpAndSettle();
    expect(find.text('Omega CD'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Carregar mais projetos'), 250);
    await tester.tap(find.text('Carregar mais projetos'));
    await tester.pumpAndSettle();
    expect(requests.last['ordem'], 'em_alta');
    expect(requests.last['cursor'], 'pagina-2');
    await tester.scrollUntilVisible(find.text('Opala SS'), 250);
    expect(find.text('Opala SS'), findsOneWidget);
    expect(find.text('Carregar mais projetos'), findsNothing);
  });
}
