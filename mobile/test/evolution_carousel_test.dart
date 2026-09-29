import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';
import 'package:garagem_mobile/features/evolutions/evolution_carousel.dart';

Evolution _entry(String id, String title, String category, DateTime date) =>
    Evolution(
      id: id,
      carId: 'car',
      title: title,
      category: category,
      description: 'Uma etapa importante da história do projeto.',
      authorName: 'Raul',
      authorUsername: 'raul',
      createdAt: date,
    );

final _entries = [
  _entry('radiador', 'Troca de radiador', 'mecanica', DateTime(2026, 9, 29)),
  _entry('pneus', 'Troca dos pneus', 'manutencao', DateTime(2026, 8, 12)),
  _entry('pintura', 'Pintura completa', 'estetica', DateTime(2025, 12, 5)),
];

void main() {
  testWidgets(
      'desliza por evoluções e preserva seleção em atualização e exclusão',
      (tester) async {
    final items = ValueNotifier<List<Evolution>>(_entries);
    addTearDown(items.dispose);
    String? opened;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: SingleChildScrollView(
          child: Padding(
        padding: const EdgeInsets.all(20),
        child: ValueListenableBuilder<List<Evolution>>(
          valueListenable: items,
          builder: (_, entries, __) => EvolutionCarousel(
            evolutions: entries,
            onOpen: (entry) => opened = entry.id,
          ),
        ),
      )),
    )));
    await tester.pumpAndSettle();
    expect(find.text('1 de 3 evoluções'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 de 3 evoluções'), findsOneWidget);
    await tester.tap(find.text('Ver evolução').hitTestable().first);
    expect(opened, 'pneus');

    items.value = [
      _entry('nova', 'Nova etapa', 'mecanica', DateTime(2026, 10, 1)),
      ..._entries,
    ];
    await tester.pumpAndSettle();
    expect(find.text('3 de 4 evoluções'), findsOneWidget);
    await tester.tap(find.text('Ver evolução').hitTestable().first);
    expect(opened, 'pneus');

    items.value = items.value.where((entry) => entry.id != 'pneus').toList();
    await tester.pumpAndSettle();
    expect(find.text('3 de 3 evoluções'), findsOneWidget);
    await tester.tap(find.text('Ver evolução').hitTestable().first);
    expect(opened, 'pintura');
    expect(tester.takeException(), isNull);
  });

  testWidgets('período e categoria combinam filtros e reiniciam a posição',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: SingleChildScrollView(
          child: Padding(
        padding: const EdgeInsets.all(20),
        child: EvolutionCarousel(evolutions: _entries, onOpen: (_) {}),
      )),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agosto de 2026').last);
    await tester.pumpAndSettle();
    expect(find.text('1 de 1 evolução'), findsOneWidget);
    expect(find.text('Troca dos pneus'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mecânica'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma evolução neste período e categoria.'),
        findsOneWidget);
    await tester.tap(find.text('Limpar filtros'));
    await tester.pumpAndSettle();
    expect(find.text('1 de 3 evoluções'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Próxima evolução'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Próxima evolução'));
    await tester.pumpAndSettle();
    expect(find.text('2 de 3 evoluções'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Estética'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Estética'));
    await tester.pumpAndSettle();
    expect(find.text('1 de 1 evolução'), findsOneWidget);
    expect(find.text('Pintura completa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
