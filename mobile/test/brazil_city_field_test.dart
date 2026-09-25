import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/location/brazil_city.dart';
import 'package:garagem_mobile/core/widgets/brazil_city_field.dart';

void main() {
  test('catálogo local contém municípios e busca sem acentos', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final cities = await BrazilCities.load();
    expect(cities.length, greaterThan(5500));
    expect(
      BrazilCities.search(cities, 'vila velha', state: 'ES').single.label,
      'Vila Velha - ES',
    );
    expect(
      BrazilCities.search(cities, 'sao paulo', state: 'SP').single.label,
      'São Paulo - SP',
    );
    expect(BrazilCities.search(cities, 'campinas', state: 'ES'), isEmpty);
  });

  testWidgets('seleção preenche cidade e UF e preserva valor existente',
      (tester) async {
    final city = TextEditingController(text: 'Vitória');
    final state = TextEditingController(text: 'ES');
    addTearDown(city.dispose);
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BrazilCityField(cityController: city, stateController: state),
      ),
    ));
    expect(find.text('Vitória - ES'), findsOneWidget);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('Selecione o estado'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Espírito Santo'), 120,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Espírito Santo'));
    await tester.runAsync(() async => await BrazilCities.load());
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(
        find.text('Digite pelo menos 2 letras para buscar.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'campinas');
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma cidade encontrada.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'vila velha');
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma cidade encontrada.'), findsNothing);
    await tester.tap(find.text('Vila Velha'));
    await tester.pumpAndSettle();

    expect(city.text, 'Vila Velha');
    expect(state.text, 'ES');
    expect(find.text('Vila Velha - ES'), findsOneWidget);

    await tester.tap(find.byTooltip('Limpar cidade'));
    await tester.pumpAndSettle();
    expect(city.text, isEmpty);
    expect(state.text, isEmpty);
  });
}
