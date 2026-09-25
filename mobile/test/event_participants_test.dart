import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/features/events/event.dart';
import 'package:garagem_mobile/features/events/event_participants_screen.dart';
import 'package:garagem_mobile/features/events/events_repository.dart';

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
  testWidgets('edição mostra confirmados, carro e equipe', (tester) async {
    final api =
        ApiClient(baseUrl: 'http://localhost/api/v1', tokenStorage: _Tokens());
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      expect(options.path, '/eventos/encontro/edicoes/edicao/participantes');
      final teams = options.queryParameters['tipo'] == 'equipes';
      handler.resolve(Response(requestOptions: options, data: {
        'total_pessoas': 1,
        'total_equipes': 1,
        'pessoas': teams
            ? []
            : [
                {
                  'usuario': {
                    'id': 'pessoa',
                    'nome': 'Maria',
                    'username': 'maria',
                    'avatar_url': null,
                  },
                  'carro': {
                    'id': 'carro',
                    'modelo': 'FUSCA 1300',
                    'ano': 1975,
                    'foto_principal_url': null,
                  },
                },
              ],
        'equipes': teams
            ? [
                {'id': 'equipe', 'nome': 'Antigos ES', 'avatar_url': null},
              ]
            : [],
      }));
    }));
    String? openedPerson, openedTeam;
    await tester.pumpWidget(MaterialApp(
      home: EventParticipantsScreen(
        eventId: 'encontro',
        eventName: 'Clássicos da Praia',
        edition: EventEdition(
          id: 'edicao',
          startsAt: DateTime(2026, 10, 12),
          status: 'agendada',
          confirmedCount: 1,
        ),
        repository: EventsRepository(api),
        onPersonTap: (id) async => openedPerson = id,
        onTeamTap: (id) async => openedTeam = id,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Pessoas  1'), findsOneWidget);
    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('@maria · FUSCA 1300 1975'), findsOneWidget);
    await tester.tap(find.text('Maria'));
    expect(openedPerson, 'pessoa');
    await tester.tap(find.text('Equipes  1'));
    await tester.pumpAndSettle();
    expect(find.text('Antigos ES'), findsOneWidget);
    await tester.tap(find.text('Antigos ES'));
    expect(openedTeam, 'equipe');
    expect(tester.takeException(), isNull);
  });
}
