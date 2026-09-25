import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/cars/saved_projects_screen.dart';
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

Map<String, Object?> _carJson() => {
      'id': 'opala',
      'modelo': 'OPALA',
      'ano': 1979,
      'foto_principal_url': null,
      'proprietario': <String, Object?>{
        'id': 'dono',
        'nome': 'Dono',
        'username': 'dono',
      },
    };

void main() {
  testWidgets('projeto salvo abre e pode ser removido da coleção',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var saved = true;
    var savedListRequests = 0;
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.path == '/carros/salvos') {
        savedListRequests++;
        handler.resolve(Response(
          requestOptions: options,
          data: <String, Object?>{
            'itens': saved ? <Object?>[_carJson()] : <Object?>[],
            'proximo_cursor': null,
          },
        ));
      } else if (options.path == '/carros/opala/salvo') {
        if (options.method == 'DELETE') saved = false;
        handler.resolve(Response(
          requestOptions: options,
          statusCode: options.method == 'GET' ? 200 : 204,
          data: options.method == 'GET'
              ? <String, Object?>{'salvo': saved}
              : null,
        ));
      } else if (options.path == '/carros/opala') {
        handler.resolve(Response(requestOptions: options, data: _carJson()));
      } else if (options.path == '/carros/opala/evolucoes') {
        handler.resolve(Response(requestOptions: options, data: <Object?>[]));
      } else {
        handler.reject(DioException(
          requestOptions: options,
          error: 'Rota inesperada: ${options.path}',
        ));
      }
    }));

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.4)),
        child: child!,
      ),
      home: SavedProjectsScreen(
        repository: CarsRepository(api),
        evolutionsRepository: EvolutionsRepository(api),
        currentUserId: 'visitante',
        onProfileTap: (_) {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('OPALA 1979'), findsOneWidget);
    await tester.tap(find.text('OPALA 1979'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remover dos salvos'), findsOneWidget);
    await tester.tap(find.byTooltip('Remover dos salvos'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Salvar projeto'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(savedListRequests, greaterThanOrEqualTo(2));
    expect(find.textContaining('Nenhum projeto salvo ainda'), findsOneWidget);
  });
}
