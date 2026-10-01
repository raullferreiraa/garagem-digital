import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garona_mobile/features/messages/message_history_screen.dart';
import 'package:garona_mobile/features/messages/message_reply.dart';

HistoryMessage entry(String id, String text, {bool deleted = false}) =>
    HistoryMessage(
      MessageReply(id: id, authorId: 'author', content: text, deleted: deleted),
      DateTime(2026, 9, 26, 10, 30),
    );

void main() {
  testWidgets(
      'busca ignora respostas antigas e limpar invalida pedido em andamento',
      (tester) async {
    final first = Completer<HistoryPage>();
    final second = Completer<HistoryPage>();
    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: MessageHistoryScreen(
      author: (_) => 'Raul',
      load: (query, cursor) {
        calls.add(query);
        return query == 'oficina' ? first.future : second.future;
      },
    )));
    await tester.enterText(find.byType(TextField), 'o');
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, isEmpty);
    await tester.enterText(find.byType(TextField), 'oficina');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'praça');
    await tester.pump(const Duration(milliseconds: 400));
    first.complete(HistoryPage([entry('old', 'Resultado antigo')], null));
    await tester.pump();
    expect(find.text('Resultado antigo'), findsNothing);
    await tester.tap(find.byTooltip('Limpar busca'));
    second.complete(HistoryPage([entry('new', 'Resultado atrasado')], null));
    await tester.pumpAndSettle();
    expect(find.text('Resultado atrasado'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('busca pagina sem duplicar e retorna mensagem escolhida',
      (tester) async {
    final calls = <String?>[];
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      child: const Text('Abrir'),
                      onPressed: () async {
                        selected = await Navigator.of(context)
                            .push<String>(MaterialPageRoute(
                                builder: (_) => MessageHistoryScreen(
                                      author: (_) => 'Raul',
                                      load: (query, cursor) async {
                                        calls.add(cursor);
                                        return cursor == null
                                            ? HistoryPage(
                                                [entry('2', 'Texto recente')],
                                                'next')
                                            : HistoryPage([
                                                entry('1', 'Texto antigo'),
                                                entry('2', 'Texto recente')
                                              ], null);
                                      },
                                    )));
                      }),
                ))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'texto');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carregar mais resultados'));
    await tester.pumpAndSettle();
    expect(calls, [null, 'next']);
    expect(find.text('Texto recente'), findsOneWidget);
    expect(find.text('Texto antigo'), findsOneWidget);
    await tester.tap(find.text('Texto antigo'));
    await tester.pumpAndSettle();
    expect(selected, '1');
  });

  testWidgets('falha da busca permite repetir sem ficar carregando',
      (tester) async {
    var fail = true;
    await tester.pumpWidget(MaterialApp(
        home: MessageHistoryScreen(
      author: (_) => 'Raul',
      load: (_, __) async {
        if (fail) throw Exception('offline');
        return const HistoryPage([], null);
      },
    )));
    await tester.enterText(find.byType(TextField), 'oficina');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    fail = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma mensagem encontrada.'), findsOneWidget);
  });
}
