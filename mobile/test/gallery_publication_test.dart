import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garona_mobile/features/cars/acquisition_date.dart';
import 'package:garona_mobile/features/cars/cars_repository.dart';
import 'package:garona_mobile/features/cars/gallery_photo_flow.dart';
import 'project_garage_test.dart' as fixtures;
import 'package:garona_mobile/features/cars/project_garage.dart';
import 'package:garona_mobile/features/cars/project_garage_screen.dart';
import 'package:garona_mobile/features/evolutions/evolutions_repository.dart';

void main() {
  test('datas apresentam a precisão disponível', () {
    expect(formatAcquisitionDate('2020'), '2020');
    expect(formatAcquisitionDate('2020-02'), 'fevereiro de 2020');
    expect(formatAcquisitionDate('2020-02-29'), 'fevereiro de 2020');
  });
  testWidgets('seletor permite ano sem inventar dia ou mês e cancelar',
      (tester) async {
    String? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      result = await pickAcquisitionDate(context, '2020');
                    },
                    child: const Text('Abrir'))))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(result, '2020');
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
  for (final owner in [false, true]) {
    testWidgets('álbum em grade, controles do dono e navegação: $owner',
        (tester) async {
      tester.view.physicalSize = const Size(360, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = fixtures.api(
          intercept: (options, handler) =>
              handler.resolve(Response(requestOptions: options, data: {
                'fotos': [
                  for (var i = 0; i < 2; i++)
                    {
                      'id': '$i',
                      'url': 'http://localhost/$i.png',
                      'legenda': 'Foto $i'
                    }
                ],
                'etapas': <Object>[]
              })));
      await tester.pumpWidget(MaterialApp(
          home: ProjectGarageScreen(
              car: fixtures.car,
              repository: CarsRepository(client),
              evolutions: EvolutionsRepository(client),
              canManage: owner,
              currentUserId: owner ? 'me' : 'visitor')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Mover antes'), findsNothing);
      expect(find.text('Organizar'), owner ? findsOneWidget : findsNothing);
      if (owner) {
        await tester.tap(find.text('Organizar'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Mover antes'), findsNWidgets(2));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const MaterialApp(
          home: GalleryPhotoViewer(photos: [
        ProjectPhoto('0', 'http://localhost/0.png', 'Primeira'),
        ProjectPhoto('1', 'http://localhost/1.png', 'Segunda')
      ], initialIndex: 0)));
      await tester.pumpAndSettle();
      expect(find.text('Primeira'), findsOneWidget);
      await tester.tap(find.byTooltip('Próxima foto'));
      await tester.pumpAndSettle();
      expect(find.text('Segunda'), findsOneWidget);
      expect(find.text('2 de 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('publicação preserva foto e legenda após falha e envia juntas',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var attempts = 0;
    final client = fixtures.api(intercept: (options, handler) {
      attempts++;
      final form = options.data as FormData;
      expect(Map.fromEntries(form.fields)['legenda'], 'Primeiro passeio');
      expect(form.files.single.key, 'arquivo');
      if (attempts == 1) {
        handler.reject(DioException(
            requestOptions: options, type: DioExceptionType.connectionError));
      } else {
        handler.resolve(Response(
            requestOptions: options,
            statusCode: 201,
            data: {
              'id': 'photo',
              'url': '/photo.png',
              'legenda': 'Primeiro passeio',
              'ordem': 0
            }));
      }
    });
    final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=');
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<bool>(
                            builder: (_) => GalleryPhotoPublishScreen(
                                carId: 'car',
                                repository: CarsRepository(client),
                                bytes: bytes,
                                fileName: 'foto.png'))),
                    child: const Text('Abrir'))))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Primeiro passeio');
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Publicar foto'));
    await tester.tap(find.widgetWithText(FilledButton, 'Publicar foto'));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.text('Primeiro passeio'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Publicar foto'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Abrir'), findsOneWidget);
  });
}
