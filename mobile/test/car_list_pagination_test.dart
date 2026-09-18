import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_list.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';

void main() {
  testWidgets('carrega a próxima página e permite tentar de novo após falha',
      (tester) async {
    final requestedCursors = <String?>[];
    final nextPages = <Completer<CarPage>>[];

    Future<CarPage> loadPage(String? cursor) {
      requestedCursors.add(cursor);
      if (cursor == null) {
        return Future.value(const CarPage(
          items: [
            Car(
              id: 'omega',
              model: 'Omega CD 4.1',
              ownerId: 'raul',
              ownerName: 'Raul',
              ownerUsername: 'raul',
            ),
          ],
          nextCursor: 'pagina-2',
        ));
      }
      final pending = Completer<CarPage>();
      nextPages.add(pending);
      return pending.future;
    }

    await tester.pumpWidget(MaterialApp(
      home: CarList(
        title: 'Explorar',
        emptyMessage: 'Nenhum projeto',
        loader: () => throw StateError('a primeira página usa pageLoader'),
        pageLoader: loadPage,
        onCarTap: (_) {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(requestedCursors, [null]);
    expect(find.text('Omega CD 4.1'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Carregar mais projetos'), 300);
    await tester.tap(find.text('Carregar mais projetos'));
    await tester.pump();
    expect(requestedCursors, [null, 'pagina-2']);

    nextPages[0].completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar mais projetos.'),
        findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    nextPages[1].complete(const CarPage(items: [
      Car(
        id: 'opala',
        model: 'Opala SS',
        ownerId: 'ana',
        ownerName: 'Ana',
        ownerUsername: 'ana',
      ),
    ]));
    await tester.pumpAndSettle();
    expect(requestedCursors, [null, 'pagina-2', 'pagina-2']);
    await tester.scrollUntilVisible(find.text('Omega CD 4.1'), -300);
    expect(find.text('Omega CD 4.1'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Opala SS'), 300);
    expect(find.text('Opala SS'), findsOneWidget);
    expect(find.text('Carregar mais projetos'), findsNothing);
  });
}
