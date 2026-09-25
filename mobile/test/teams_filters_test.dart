import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/core/theme/app_theme.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/messages/messages_repository.dart';
import 'package:garagem_mobile/features/profile/users_repository.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';
import 'package:garagem_mobile/features/teams/teams_screen.dart';

final class _Tokens implements TokenStorage {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<String?> readRefreshToken() async => null;
  @override
  Future<void> write(
      {required String accessToken, required String refreshToken}) async {}
}

Map<String, Object?> _team(String name,
        {bool pending = false, bool invited = false}) =>
    {
      'id': name,
      'nome': name,
      'slug': name.toLowerCase(),
      'visibilidade': 'publica',
      'total_membros': 2,
      'minha_solicitacao': pending ? 'pendente' : null,
      'meu_convite': invited ? 'pendente' : null,
    };

void main() {
  for (final invite in [false, true]) {
    testWidgets(
        'filtro de ${invite ? 'convites' : 'pedidos'} volta ao diretório quando pendência desaparece',
        (tester) async {
      final api = ApiClient(
          baseUrl: 'http://localhost/api/v1', tokenStorage: _Tokens());
      var pending = true;
      api.dio.interceptors
          .add(InterceptorsWrapper(onRequest: (options, handler) {
        handler.resolve(Response(requestOptions: options, data: [
          _team('Pista',
              pending: pending && !invite, invited: pending && invite),
          _team('Oficina'),
        ]));
      }));
      Widget screen(int revision) => MaterialApp(
            theme: AppTheme.dark,
            home: TeamsScreen(
              repository: TeamsRepository(api),
              carsRepository: CarsRepository(api),
              evolutionsRepository: EvolutionsRepository(api),
              currentUserId: 'usuario',
              usersRepository: UsersRepository(api),
              messagesRepository: MessagesRepository(api),
              onConversationChanged: () {},
              unreadTeamMessages: 0,
              onTeamChatChanged: () {},
              refreshRevision: revision,
              onSearch: () {},
            ),
          );

      await tester.pumpWidget(screen(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text(invite ? 'Convites (1)' : 'Pedidos (1)'));
      await tester.pumpAndSettle();
      expect(find.text(invite ? 'Convites recebidos' : 'Pedidos enviados'),
          findsOneWidget);
      expect(find.text('Oficina'), findsNothing);

      pending = false;
      await tester.pumpWidget(screen(1));
      await tester.pumpAndSettle();
      expect(find.text('Equipes para conhecer'), findsOneWidget);
      expect(find.text('Oficina'), findsOneWidget);
      expect(find.text(invite ? 'Convites recebidos' : 'Pedidos enviados'),
          findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
