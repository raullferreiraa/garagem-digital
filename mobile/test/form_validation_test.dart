import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/widgets/form_validation.dart';

void main() {
  testWidgets('salvar formulário longo revela campo inválido fora da tela',
      (tester) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Form(
      key: key,
      child: SingleChildScrollView(
          child: Column(children: [
        TextFormField(
            decoration: const InputDecoration(labelText: 'Nome'),
            validator: (value) =>
                value == null || value.isEmpty ? 'Informe o nome' : null),
        const SizedBox(height: 1400),
        FilledButton(
            onPressed: () => validateAndReveal(key),
            child: const Text('Salvar')),
      ])),
    ))));
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField).hitTestable(), findsOneWidget);
    expect(find.text('Informe o nome'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Raul');
    expect(validateAndReveal(key), isTrue);
  });
}
