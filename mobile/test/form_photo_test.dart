import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/widgets/form_photo.dart';

void main() {
  testWidgets('seleção oferece câmera e galeria e pode ser cancelada',
      (tester) async {
    var changes = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FormPhoto(
                label: 'Foto', bytes: null, onChanged: (_) => changes++))));
    await tester.tap(find.text('Foto (opcional)'));
    await tester.pumpAndSettle();
    expect(find.text('Escolher da galeria'), findsOneWidget);
    expect(find.text('Usar a câmera'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(changes, 0);
    expect(find.text('Foto (opcional)'), findsOneWidget);
  });
  testWidgets(
      'prévias compactas preservam recorte quadrado e proporção da capa',
      (tester) async {
    final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');
    for (final ratio in [1.0, 16 / 9]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SizedBox(
                  width: 320,
                  child: FormPhoto(
                      label: 'Imagem',
                      bytes: bytes,
                      compact: true,
                      aspectRatio: ratio,
                      onChanged: (_) {})))));
      await tester.pumpAndSettle();
      final size = tester.getSize(find.byType(Image));
      expect(size.width, ratio == 1 ? 80 : 192);
      expect(size.width / size.height, closeTo(ratio, .01));
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('falha na foto repete somente upload e mantém cadastro salvo',
      (tester) async {
    var creations = 0;
    var uploads = 0;
    String? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: FilledButton(
                      onPressed: () async {
                        creations++;
                        result = await uploadFormPhoto(context, 'cadastro',
                            () async {
                          uploads++;
                          if (uploads == 1) throw Exception('offline');
                          return 'cadastro com foto';
                        });
                      },
                      child: const Text('Salvar')),
                ))));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Cadastro salvo; foto não enviada'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(creations, 1);
    expect(uploads, 2);
    expect(result, 'cadastro com foto');
  });

  testWidgets('usuário pode continuar com cadastro salvo sem foto',
      (tester) async {
    String? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: FilledButton(
                      onPressed: () async {
                        result = await uploadFormPhoto<String>(context, 'salvo',
                            () async => throw Exception('offline'));
                      },
                      child: const Text('Salvar')),
                ))));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar sem foto'));
    await tester.pumpAndSettle();
    expect(result, 'salvo');
  });

  testWidgets('salvamento bloqueia voltar até a operação terminar',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const FormSaveGuard(
                                  saving: true,
                                  child: Scaffold(body: Text('Salvando'))))),
                      child: const Text('Abrir')),
                ))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Salvando'), findsOneWidget);
  });
}
