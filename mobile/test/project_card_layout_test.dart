import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garona_mobile/core/theme/app_theme.dart';
import 'package:garona_mobile/features/cars/car.dart';
import 'package:garona_mobile/features/cars/project_card.dart';

void main() {
  for (final compact in [false, true]) {
    testWidgets('projeto com contadores grandes cabe em320 (compact=$compact)',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: Scaffold(
            body: ListView(padding: const EdgeInsets.all(20), children: [
              GaronaProjectCard(
                car: const Car(
                  id: 'car',
                  model: 'Chevrolet Omega CD 4.1',
                  year: 1996,
                  ownerId: 'owner',
                  ownerName: 'Raul',
                  ownerUsername: 'raul',
                  likesCount: 1234567,
                  commentsCount: 7654321,
                  projectStatus: 'Em evolução',
                ),
                compact: compact,
                onTap: () => opened = true,
              ),
            ]),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Abrir projeto'));
      await tester.tap(find.text('Abrir projeto'));
      expect(opened, isTrue);
    });
  }
}
