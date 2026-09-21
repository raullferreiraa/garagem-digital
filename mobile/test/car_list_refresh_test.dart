import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_list.dart';

void main() {
  testWidgets('atualiza os cards sem apagar a lista enquanto consulta a API',
      (tester) async {
    final requests = <Completer<List<Car>>>[];
    Future<List<Car>> load() {
      final request = Completer<List<Car>>();
      requests.add(request);
      return request.future;
    }

    Widget screen(int revision) => MaterialApp(
          home: CarList(
            title: 'Garagem',
            emptyMessage: 'Nenhum carro',
            loader: load,
            onCarTap: (_) {},
            mode: CarListMode.garage,
            refreshRevision: revision,
          ),
        );

    const omega = Car(
      id: 'omega',
      model: 'Omega CD 4.1',
      ownerId: 'raul',
      ownerName: 'Raul',
      ownerUsername: 'raul',
    );
    const opala = Car(
      id: 'opala',
      model: 'Opala SS',
      ownerId: 'raul',
      ownerName: 'Raul',
      ownerUsername: 'raul',
    );

    await tester.pumpWidget(screen(0));
    requests[0].complete([omega]);
    await tester.pumpAndSettle();
    expect(find.text('Omega CD 4.1'), findsOneWidget);

    await tester.pumpWidget(screen(1));
    expect(requests, hasLength(2));
    expect(find.text('Omega CD 4.1'), findsOneWidget);

    requests[1].complete([opala]);
    await tester.pumpAndSettle();
    expect(find.text('Opala SS'), findsOneWidget);
    expect(find.text('Omega CD 4.1'), findsNothing);

    await tester.pumpWidget(screen(2));
    requests[2].completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Opala SS'), findsOneWidget);
    expect(find.text('Não foi possível atualizar a lista.'), findsOneWidget);
  });
}
