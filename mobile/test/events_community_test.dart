import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/core/theme/app_theme.dart';
import 'package:garagem_mobile/features/events/event.dart';
import 'package:garagem_mobile/features/events/events_repository.dart';
import 'package:garagem_mobile/features/events/events_screen.dart';
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

Map<String, Object?> community({bool scheduled = false}) => {
      'id': 'comunidade',
      'edicao_id': scheduled ? 'edicao' : null,
      'nome': 'Clássicos da Praia',
      'descricao': 'Pessoas apaixonadas por histórias e projetos automotivos.',
      'inicio': scheduled
          ? DateTime.now().add(const Duration(days: 7)).toIso8601String()
          : null,
      'termino': null,
      'cidade': 'Vila Velha',
      'estado': 'ES',
      'visibilidade': 'publico',
      'organizador_tipo': 'usuario',
      'organizador_nome': 'Raul',
      'organizador_id': 'raul',
      'total_confirmados': 0,
      'total_equipes': 0,
      'posso_gerenciar': true,
      'total_seguidores': 1,
      'seguindo': true,
      'edicoes': <Object?>[],
    };

void main() {
  test('comunidade sem data não cria uma edição implicitamente', () {
    const input = EventInput(
        name: 'Encontro',
        startsAt: null,
        organizer: 'usuario',
        visibility: 'publico');
    expect(input.toJson().containsKey('proxima_edicao'), isFalse);
    expect(GarageEvent.fromJson(community()).startsAt, isNull);
  });

  test('edição pode usar local diferente da região da comunidade', () {
    final data = community(scheduled: true)
      ..['endereco_publico'] = 'Autódromo'
      ..['edicao_cidade'] = 'Curitiba'
      ..['edicao_estado'] = 'PR'
      ..['edicoes'] = <Object?>[
        {
          'id': 'edicao',
          'inicio':
              DateTime.now().add(const Duration(days: 7)).toIso8601String(),
          'termino': null,
          'endereco_publico': 'Autódromo',
          'cidade': 'Curitiba',
          'estado': 'PR',
          'status': 'agendada',
          'total_confirmados': 3,
          'total_equipes': 1,
        }
      ];
    final event = GarageEvent.fromJson(data);
    expect(event.location, 'Autódromo · Curitiba · PR');
    expect(event.editions.single.status, 'agendada');
    expect(event.editions.single.location(), 'Autódromo · Curitiba · PR');
  });

  for (final scheduled in [false, true]) {
    testWidgets(
        'comunidade com data=$scheduled cabe em tela estreita e fonte ampliada',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ApiClient(
          baseUrl: 'http://localhost/api/v1', tokenStorage: _Tokens());
      api.dio.interceptors
          .add(InterceptorsWrapper(onRequest: (options, handler) {
        handler.resolve(Response(
            requestOptions: options, data: community(scheduled: scheduled)));
      }));
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!),
          home: EventCommunityScreen(
              event: GarageEvent.fromJson(community(scheduled: scheduled)),
              repository: EventsRepository(api))));
      await tester.pumpAndSettle();
      expect(find.text('Clássicos da Praia'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Edições anteriores'), 350,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Edições anteriores'), findsOneWidget);
    });
  }

  testWidgets('lista mantém comunidades visíveis se o refresh falhar',
      (tester) async {
    final api =
        ApiClient(baseUrl: 'http://localhost/api/v1', tokenStorage: _Tokens());
    var fail = false;
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (fail) {
        handler.reject(DioException(
            requestOptions: options, type: DioExceptionType.connectionError));
        return;
      }
      handler.resolve(Response(requestOptions: options, data: [community()]));
    }));
    Widget screen(int revision) => MaterialApp(
        theme: AppTheme.dark,
        home: EventsScreen(
            repository: EventsRepository(api),
            teamsRepository: TeamsRepository(api),
            refreshRevision: revision));
    await tester.pumpWidget(screen(0));
    await tester.pumpAndSettle();
    expect(find.text('Clássicos da Praia'), findsOneWidget);
    fail = true;
    await tester.pumpWidget(screen(1));
    await tester.pumpAndSettle();
    expect(find.text('Clássicos da Praia'), findsOneWidget);
    expect(find.text('Não foi possível conectar à API.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
