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
