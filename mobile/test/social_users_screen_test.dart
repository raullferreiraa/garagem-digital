import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/features/profile/public_profile.dart';
import 'package:garagem_mobile/features/profile/social_users_screen.dart';

void main() {
  testWidgets(
      'falha ao atualizar seguidores preserva lista e permite tentar de novo',
      (tester) async {
    var calls = 0;
    Future<List<SocialUser>> loader() async {
      calls++;
      if (calls == 2) throw Exception('Sem conexão');
      return const [SocialUser(id: 'a', name: 'Ana', username: 'ana')];
    }

    await tester.pumpWidget(MaterialApp(
      home: SocialUsersScreen(
        title: 'Seguidores',
        loader: loader,
        onUserTap: (_) {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);

    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(calls, 3);
    expect(tester.takeException(), isNull);
  });
}
