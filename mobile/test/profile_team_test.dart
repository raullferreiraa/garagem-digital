import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/messages/messages_repository.dart';
import 'package:garagem_mobile/features/profile/public_profile_screen.dart';
import 'package:garagem_mobile/features/profile/users_repository.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

class _Tokens implements TokenStorage {
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

void main() {
  testWidgets('perfil público mostra equipe atual com acesso ao detalhe',
      (tester) async {
    final api =
        ApiClient(baseUrl: 'http://localhost/api/v1', tokenStorage: _Tokens());
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.path.endsWith('/carros')) {
        handler.resolve(Response(requestOptions: options, data: <Object?>[]));
      } else {
        handler.resolve(Response(requestOptions: options, data: {
          'id': 'pessoa',
          'nome': 'Maria',
          'username': 'maria',
          'avatar_url': null,
          'bio': null,
          'cidade': null,
          'estado': null,
          'total_projetos': 0,
          'total_seguidores': 0,
          'total_seguindo': 0,
          'seguido_por_mim': false,
          'equipe_atual': {
            'id': 'equipe',
            'nome': 'Clássicos ES',
            'avatar_url': null
          },
        }));
      }
    }));
    await tester.pumpWidget(MaterialApp(
      home: PublicProfileScreen(
        userId: 'pessoa',
        currentUserId: 'eu',
        usersRepository: UsersRepository(api),
        carsRepository: CarsRepository(api),
        evolutionsRepository: EvolutionsRepository(api),
        messagesRepository: MessagesRepository(api),
        teamsRepository: TeamsRepository(api),
        onConversationChanged: () {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Clássicos ES'), findsOneWidget);
    expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Clássicos ES'))
            .onTap,
        isNotNull);
    expect(tester.takeException(), isNull);
  });
}
