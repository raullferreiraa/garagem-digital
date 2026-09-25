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
  testWidgets('busca cidade da edição e filtra comunidades com próxima data',
      (tester) async {
    final scheduled = community(scheduled: true)
      ..['edicao_cidade'] = 'Curitiba'
      ..['edicao_estado'] = 'PR';
    final unscheduled = community()
      ..['id'] = 'sem-data'
      ..['nome'] = 'Garagem Capixaba';
    final api =
        ApiClient(baseUrl: 'http://localhost/api/v1', tokenStorage: _Tokens());
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(
          Response(requestOptions: options, data: [unscheduled, scheduled]));
    }));
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: EventsScreen(
            repository: EventsRepository(api),
            teamsRepository: TeamsRepository(api),
            refreshRevision: 0)));
    await tester.pumpAndSettle();
    expect(find.text('Curitiba · PR'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Curitiba');
    await tester.pumpAndSettle();
    expect(find.text('Clássicos da Praia'), findsOneWidget);
    expect(find.text('Garagem Capixaba'), findsNothing);
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Próximos'));
    await tester.pumpAndSettle();
    expect(find.text('Clássicos da Praia'), findsOneWidget);
    expect(find.text('Garagem Capixaba'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('busca vazia oferece limpar filtros e recupera encontros',
      (tester) async {
    final api =
        ApiClient(baseUrl: 'http://localhost/api/v1', tokenStorage: _Tokens());
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response(requestOptions: options, data: [community()]));
    }));
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: EventsScreen(
            repository: EventsRepository(api),
            teamsRepository: TeamsRepository(api),
            refreshRevision: 0)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'inexistente');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum encontro encontrado.'), findsOneWidget);
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();
    expect(find.text('Clássicos da Praia'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha inicial não é apresentada como lista vazia',
      (tester) async {
    final api =
        ApiClient(baseUrl: 'http://localhost/api/v1', tokenStorage: _Tokens());
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.reject(DioException(
          requestOptions: options, type: DioExceptionType.connectionError));
    }));
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: EventsScreen(
            repository: EventsRepository(api),
            teamsRepository: TeamsRepository(api),
            refreshRevision: 0)));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(
        find.text('Explore outra busca ou crie o seu encontro.'), findsNothing);
  });
  testWidgets(
      'levar equipe exige confirmação explícita dos integrantes e separa ações',
      (tester) async {
    final data = community(scheduled: true)
      ..['minha_equipe_id'] = 'equipe'
      ..['minha_equipe_nome'] = 'Clássicos'
      ..['minha_equipe_papel'] = 'dono'
      ..['minha_equipe_total_integrantes'] = 3;
    final api =
        ApiClient(baseUrl: 'http://localhost/api/v1', tokenStorage: _Tokens());
    RequestOptions? sent;
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.method == 'PUT') {
        sent = options;
        data['minha_equipe_participacao'] = 'confirmada';
      }
      handler.resolve(Response(requestOptions: options, data: data));
    }));
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: EventCommunityScreen(
            event: GarageEvent.fromJson(data),
            repository: EventsRepository(api))));
    await tester.pumpAndSettle();
    final teamButton = find.widgetWithText(OutlinedButton, 'Levar Clássicos');
    await tester.scrollUntilVisible(teamButton, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    final presenceButton =
        find.widgetWithText(FilledButton, 'Confirmar minha presença');
    expect(
        tester.getTopLeft(teamButton).dy -
            tester.getBottomLeft(presenceButton).dy,
        greaterThanOrEqualTo(12));
    await tester.tap(teamButton);
    await tester.pumpAndSettle();
    expect(sent, isNull);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();
    expect(sent!.data, {'status': 'confirmada', 'confirmar_integrantes': true});
    expect(sent!.queryParameters, {'edicao_id': 'edicao'});
    expect(
        find.widgetWithText(OutlinedButton, 'Levar Clássicos'), findsNothing);
    expect(find.text('Equipe confirmada · Gerenciar'), findsOneWidget);
  });

  testWidgets('exclusão da comunidade pode ser cancelada sem enviar requisição',
      (tester) async {
    final data = community();
    var deletes = 0;
    final api =
        ApiClient(baseUrl: 'http://localhost/api/v1', tokenStorage: _Tokens());
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.method == 'DELETE') deletes++;
      handler.resolve(Response(requestOptions: options, data: data));
    }));
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: EventCommunityScreen(
            event: GarageEvent.fromJson(data),
            repository: EventsRepository(api))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Gerenciar encontro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir comunidade'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir comunidade?'), findsOneWidget);
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(deletes, 0);
  });

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
