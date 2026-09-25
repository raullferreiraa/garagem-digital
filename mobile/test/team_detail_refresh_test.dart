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
import 'package:garagem_mobile/features/teams/team_detail_screen.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

final class _EmptyTokenStorage implements TokenStorage {
  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> write({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {}
}

Map<String, Object?> _teamDetail({required bool blocked}) => {
      'id': 'equipe',
      'nome': 'Equipe da Pista',
      'slug': 'equipe-da-pista',
      'visibilidade': 'publica',
      'total_membros': 1,
      'meu_papel': 'dono',
      'dono_id': 'dono',
      'membros': <Object?>[],
      'carros': <Object?>[],
      'solicitacoes_pendentes': <Object?>[
        {
          'id': 'pedido',
          'usuario': {
            'id': 'pessoa',
            'nome': 'João',
            'username': 'joao',
          },
          'bloqueio_para_aprovacao': blocked,
        },
      ],
    };

void main() {
  testWidgets('minha equipe oferece atalho para seus encontros',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response(
        requestOptions: options,
        data: _teamDetail(blocked: false),
      ));
    }));
    var opened = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.6)),
        child: child!,
      ),
      home: TeamDetailScreen(
        teamId: 'equipe',
        repository: TeamsRepository(api),
        carsRepository: CarsRepository(api),
        evolutionsRepository: EvolutionsRepository(api),
        currentUserId: 'dono',
        usersRepository: UsersRepository(api),
        messagesRepository: MessagesRepository(api),
        onConversationChanged: () {},
        isMyTeamHome: true,
        onTeamEventsTap: () => opened = true,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Encontros'), 300);
    await tester.ensureVisible(find.text('Encontros'));
    await tester.pumpAndSettle();
    final chatButton = find
        .ancestor(
          of: find.text('Conversa'),
          matching: find.byType(Material),
        )
        .first;
    final eventsButton = find
        .ancestor(
          of: find.text('Encontros'),
          matching: find.byType(Material),
        )
        .first;
    expect(tester.getSize(chatButton).height, inInclusiveRange(90, 115));
    expect(tester.getSize(chatButton).width,
        greaterThan(tester.getSize(eventsButton).width));
    await tester.tap(find.text('Encontros'));
    expect(opened, isTrue);
    await tester.scrollUntilVisible(find.text('Escolher carro'), 300);
    expect(find.text('Escolher carro'), findsOneWidget);
    expect(find.text('Escolher meu carro para a equipe'), findsNothing);
    await tester.scrollUntilVisible(find.text('Convidar integrante'), 300);
    expect(find.text('Convidar integrante'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('garagem e integrantes permanecem compactos em tela estreita',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final detail = _teamDetail(blocked: false)
      ..['carros'] = [
        {
          'id': 'carro',
          'modelo': 'OMEGA',
          'ano': 1996,
          'proprietario': {
            'id': 'dono',
            'nome': 'Raul',
            'username': 'raul',
          },
        },
      ]
      ..['membros'] = [
        {
          'papel': 'dono',
          'usuario': {
            'id': 'dono',
            'nome': 'Raul',
            'username': 'raul',
          },
        },
      ];
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response(requestOptions: options, data: detail));
    }));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.6)),
        child: child!,
      ),
      home: TeamDetailScreen(
        teamId: 'equipe',
        repository: TeamsRepository(api),
        carsRepository: CarsRepository(api),
        evolutionsRepository: EvolutionsRepository(api),
        currentUserId: 'dono',
        usersRepository: UsersRepository(api),
        messagesRepository: MessagesRepository(api),
        onConversationChanged: () {},
        isMyTeamHome: true,
        onTeamEventsTap: () {},
      ),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('OMEGA 1996'), 300);
    final carCard = find.ancestor(
      of: find.text('OMEGA 1996'),
      matching: find.byType(Card),
    );
    expect(tester.getSize(carCard.first).height, lessThan(150));
    await tester.scrollUntilVisible(
      find.text('Raul'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final nameY = tester.getTopLeft(find.text('Raul')).dy;
    final roleY = tester.getTopLeft(find.text('Dono').last).dy;
    expect((nameY - roleY).abs(), lessThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pedido é atualizado após falha de aprovação por bloqueio',
      (tester) async {
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    var blocked = false;
    var details = 0;
    api.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/equipes/equipe' && options.method == 'GET') {
          details++;
          handler.resolve(Response(
            requestOptions: options,
            data: _teamDetail(blocked: blocked),
          ));
          return;
        }
        if (options.path == '/equipes/equipe/solicitacoes/pedido' &&
            options.method == 'PATCH') {
          blocked = true;
          handler.reject(DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 403,
              data: {
                'detail': 'Não é possível aprovar enquanto houver bloqueio.'
              },
            ),
            type: DioExceptionType.badResponse,
          ));
          return;
        }
        handler.reject(DioException(requestOptions: options));
      },
    ));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: TeamDetailScreen(
        teamId: 'equipe',
        repository: TeamsRepository(api),
        carsRepository: CarsRepository(api),
        evolutionsRepository: EvolutionsRepository(api),
        currentUserId: 'dono',
        usersRepository: UsersRepository(api),
        messagesRepository: MessagesRepository(api),
        onConversationChanged: () {},
      ),
    ));
    await tester.pumpAndSettle();
    final approve = find.widgetWithText(FilledButton, 'Aprovar');
    await tester.ensureVisible(approve);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(approve).onPressed, isNotNull);

    await tester.tap(approve);
    await tester.pumpAndSettle();

    expect(details, greaterThan(1));
    expect(tester.widget<FilledButton>(approve).onPressed, isNull);
    expect(
        find.textContaining('A aprovação ficará disponível'), findsOneWidget);
  });

  testWidgets('detalhe da equipe atualiza quando a aba é revisitada',
      (tester) async {
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    var blocked = false;
    api.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/equipes/equipe' && options.method == 'GET') {
          handler.resolve(Response(
            requestOptions: options,
            data: _teamDetail(blocked: blocked),
          ));
          return;
        }
        handler.reject(DioException(requestOptions: options));
      },
    ));
    final repository = TeamsRepository(api);
    Widget screen(int revision) => MaterialApp(
          theme: AppTheme.dark,
          home: TeamDetailScreen(
            teamId: 'equipe',
            repository: repository,
            carsRepository: CarsRepository(api),
            evolutionsRepository: EvolutionsRepository(api),
            currentUserId: 'dono',
            usersRepository: UsersRepository(api),
            messagesRepository: MessagesRepository(api),
            onConversationChanged: () {},
            refreshRevision: revision,
          ),
        );

    await tester.pumpWidget(screen(0));
    await tester.pumpAndSettle();
    blocked = true;
    await tester.pumpWidget(screen(1));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('A aprovação ficará disponível'), findsOneWidget);
  });
}
