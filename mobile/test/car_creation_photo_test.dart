import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/widgets/form_photo.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_form_screen.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';

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

void main() {
  testWidgets(
      'nome vazio não é enviado com ficha técnica aberta e formulário rolado',
      (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api =
        ApiClient(baseUrl: 'http://localhost/api/v1', tokenStorage: _Tokens());
    var requests = 0;
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests++;
      handler.reject(DioException(requestOptions: options));
    }));
    await tester.pumpWidget(
        MaterialApp(home: CarFormScreen(repository: CarsRepository(api))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(ExpansionTile));
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Adicionar à garagem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar à garagem'));
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(find.byType(TextFormField).first.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'criação envia foto ao mesmo projeto e retorna resultado atualizado',
      (tester) async {
    final api =
        ApiClient(baseUrl: 'http://localhost/api/v1', tokenStorage: _Tokens());
    final requests = <String>[];
    final car = <String, Object?>{
      'id': 'novo',
      'modelo': 'FUSCA',
      'proprietario': {'id': 'usuario', 'nome': 'Raul', 'username': 'raul'}
    };
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options.path);
      handler.resolve(Response(requestOptions: options, data: {
        ...car,
        if (options.data is FormData) 'foto_principal_url': '/media/foto.jpg',
      }));
    }));
    Car? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        result = await Navigator.push<Car>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CarFormScreen(
                                    repository: CarsRepository(api))));
                      },
                      child: const Text('Novo')),
                ))));
    await tester.tap(find.text('Novo'));
    await tester.pumpAndSettle();
    tester.widget<FormPhoto>(find.byType(FormPhoto)).onChanged(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'FUSCA');
    await tester.scrollUntilVisible(find.text('Adicionar à garagem'), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Adicionar à garagem'));
    await tester.pumpAndSettle();
    expect(requests, ['/carros', '/carros/novo/foto-principal']);
    expect(result?.id, 'novo');
    expect(result?.photoUrl, endsWith('/media/foto.jpg'));
  });
}
