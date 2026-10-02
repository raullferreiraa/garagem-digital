import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garona_mobile/core/network/api_client.dart';
import 'package:garona_mobile/core/storage/token_storage.dart';
import 'package:garona_mobile/core/theme/app_theme.dart';
import 'package:garona_mobile/features/cars/car.dart';
import 'package:garona_mobile/features/cars/car_detail_screen.dart';
import 'package:garona_mobile/features/cars/car_form_screen.dart';
import 'package:garona_mobile/features/cars/cars_repository.dart';
import 'package:garona_mobile/features/cars/project_garage_screen.dart';
import 'package:garona_mobile/features/evolutions/evolutions_repository.dart';

class _Tokens implements TokenStorage {
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<String?> readRefreshToken() async => null;
  @override
  Future<void> clear() async {}
  @override
  Future<void> write(
      {required String accessToken, required String refreshToken}) async {}
}

const car = Car(
    id: 'omega',
    model: 'OMEGA GLS',
    year: 1996,
    projectName: 'O seis da família',
    proposal: 'De volta à rua, no meu tempo.',
    history:
        'O carro ficou na família. Agora, cada fim de semana é uma parte dessa volta.',
    engine: '2.0',
    originalSpec: 'Motor e interior originais.',
    modifications: 'Suspensão revisada e rodas aro 15.',
    ownerId: 'me',
    ownerName: 'Raul',
    ownerUsername: 'raul');
final carJson = <String, Object?>{
  'id': 'omega',
  'modelo': car.model,
  'ano': car.year,
  'nome_projeto': car.projectName,
  'proposta': car.proposal,
  'historia': car.history,
  'motor': car.engine,
  'configuracao_original': car.originalSpec,
  'modificacoes': car.modifications,
  'proprietario': {'id': 'me', 'nome': 'Raul', 'username': 'raul'},
};

ApiClient api(
    {void Function(RequestOptions, RequestInterceptorHandler)? intercept}) {
  final api = ApiClient(baseUrl: 'http://localhost', tokenStorage: _Tokens());
  api.dio.interceptors.add(InterceptorsWrapper(
      onRequest: intercept ??
          (options, handler) {
            final Object data = options.path.endsWith('/garagem')
                ? {
                    'fotos': <Object?>[],
                    'etapas': [
                      {
                        'id': 'a',
                        'titulo': 'Revisar o arrefecimento',
                        'descricao':
                            'Mangueiras, radiador e uma revisão sem pressa.',
                        'status': 'em_andamento'
                      },
                      {
                        'id': 'b',
                        'titulo': 'Primeiro encontro com a equipe',
                        'status': 'planejada'
                      },
                      {
                        'id': 'c',
                        'titulo': 'Acertar a suspensão',
                        'status': 'concluida'
                      },
                    ],
                  }
                : options.path.endsWith('/evolucoes')
                    ? <Object?>[]
                    : carJson;
            handler.resolve(Response(requestOptions: options, data: data));
          }));
  return api;
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('GARONA_CAPTURE')) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/garage-preview/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('GARONA_CAPTURE')) return;
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final entry in {
      'Manrope': 'Manrope-Variable.ttf',
      'BarlowCondensed': 'BarlowCondensed-Bold.ttf'
    }.entries) {
      await (FontLoader(entry.key)
            ..addFont(rootBundle.load('assets/fonts/${entry.value}')))
          .load();
    }
  });
  for (final owner in [false, true]) {
    testWidgets(
        'galeria e etapas respeitam proprietário $owner em tela estreita',
        (tester) async {
      tester.view.physicalSize = const Size(360, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = api();
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.dark,
              home: ProjectGarageScreen(
                  car: car,
                  repository: CarsRepository(client),
                  evolutions: EvolutionsRepository(client),
                  canManage: owner,
                  currentUserId: owner ? 'me' : 'visitor'))));
      await tester.pumpAndSettle();
      expect(
          find.text('Adicionar foto'), owner ? findsOneWidget : findsNothing);
      await capture(tester, key, 'galeria');
      await tester.tap(find.text('Etapas'));
      await tester.pumpAndSettle();
      expect(find.text('1 de 3 etapas concluídas'), findsOneWidget);
      expect(
          find.text('Adicionar etapa'), owner ? findsOneWidget : findsNothing);
      await capture(tester, key, 'etapas');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('projeto mantém apresentação curta e detalhes expansíveis',
      (tester) async {
    tester.view.physicalSize = const Size(360, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = api();
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            home: CarDetailScreen(
                car: car,
                repository: CarsRepository(client),
                evolutionsRepository: EvolutionsRepository(client),
                canManage: true,
                currentUserId: 'me'))));
    await tester.pumpAndSettle();
    expect(find.text(car.projectName!), findsOneWidget);
    expect(find.text(car.history!), findsNothing);
    await capture(tester, key, 'projeto');
    await tester.ensureVisible(find.text('Sobre o projeto'));
    await tester.tap(find.text('Sobre o projeto'));
    await tester.pumpAndSettle();
    expect(find.text(car.history!), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('falha ao salvar etapa mantém texto e permite repetir',
      (tester) async {
    var attempts = 0;
    final client = api(intercept: (options, handler) {
      if (options.method == 'POST') {
        attempts++;
        if (attempts == 1) {
          handler.reject(DioException(requestOptions: options));
          return;
        }
        expect((options.data as Map)['titulo'], 'Revisar freios');
        handler.resolve(Response(requestOptions: options, data: {}));
      } else {
        handler.resolve(Response(requestOptions: options, data: <Object?>[]));
      }
    });
    await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => ProjectStageForm(
                            car: car,
                            repository: CarsRepository(client),
                            evolutions: EvolutionsRepository(client)))),
                child: const Text('Abrir')))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Revisar freios');
    await tester.ensureVisible(find.text('Salvar etapa'));
    await tester.tap(find.text('Salvar etapa'));
    await tester.pumpAndSettle();
    expect(find.text('Revisar freios'), findsOneWidget);
    expect(find.text('Algo deu errado. Tente novamente.'), findsOneWidget);
    await tester.ensureVisible(find.text('Salvar etapa'));
    await tester.tap(find.text('Salvar etapa'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Abrir'), findsOneWidget);
  });
  testWidgets('prévia preserva identidade e voltar protege preenchimento',
      (tester) async {
    final client = api();
    await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => CarFormScreen(
                            car: car, repository: CarsRepository(client)))),
                child: const Text('Abrir')))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome do projeto (opcional)'),
        'Seis canecos');
    await tester.tap(find.byTooltip('Prévia do projeto'));
    await tester.pumpAndSettle();
    expect(find.text('Seis canecos'), findsWidgets);
    Navigator.of(tester.element(find.text('PRÉVIA / PROJETO'))).pop();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsOneWidget);
    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(find.text('Seis canecos'), findsOneWidget);
  });
}
