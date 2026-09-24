import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/core/theme/app_theme.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/messages/messages_repository.dart';
import 'package:garagem_mobile/features/profile/blocked_users_screen.dart';
import 'package:garagem_mobile/features/profile/public_profile_screen.dart';
import 'package:garagem_mobile/features/profile/users_repository.dart';

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

void main() {
  test('envia denúncia de perfil com motivo e detalhes normalizados', () async {
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    RequestOptions? request;
    api.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        request = options;
        handler
            .resolve(Response<void>(requestOptions: options, statusCode: 204));
      },
    ));

    await UsersRepository(api).report(
      'usuario-alvo',
      reason: 'assedio',
      details: '  Mensagens insistentes  ',
    );

    expect(request?.method, 'POST');
    expect(request?.path, '/usuarios/usuario-alvo/denuncias');
    expect(request?.data, {
      'motivo': 'assedio',
      'detalhes': 'Mensagens insistentes',
    });
  });

  testWidgets('perfil público oferece denúncia com confirmação',
      (tester) async {
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    var reports = 0;
    api.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/usuarios/alvo') {
          handler.resolve(Response(
            requestOptions: options,
            data: <String, Object?>{
              'id': 'alvo',
              'nome': 'Perfil Alvo',
              'username': 'perfil.alvo',
              'avatar_url': null,
              'bio': null,
              'cidade': null,
              'estado': null,
              'total_projetos': 0,
              'total_seguidores': 0,
              'total_seguindo': 0,
              'seguido_por_mim': false,
            },
          ));
          return;
        }
        if (options.path == '/usuarios/alvo/carros') {
          handler.resolve(Response(requestOptions: options, data: <Object?>[]));
          return;
        }
        if (options.path == '/usuarios/alvo/denuncias') {
          reports++;
          handler.resolve(
              Response<void>(requestOptions: options, statusCode: 204));
          return;
        }
        handler.reject(DioException(requestOptions: options));
      },
    ));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: PublicProfileScreen(
        userId: 'alvo',
        currentUserId: 'eu',
        usersRepository: UsersRepository(api),
        carsRepository: CarsRepository(api),
        evolutionsRepository: EvolutionsRepository(api),
        messagesRepository: MessagesRepository(api),
        onConversationChanged: () {},
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Denunciar perfil'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'A denúncia será analisada. O perfil não será avisado sobre quem denunciou.'),
        findsOneWidget);
    await tester.tap(find.text('Enviar denúncia'));
    await tester.pumpAndSettle();

    expect(reports, 1);
    expect(find.text('Denúncia enviada para análise.'), findsOneWidget);
  });

  testWidgets('bloqueio de perfil exige confirmação e pode ser desfeito',
      (tester) async {
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    var blocked = false;
    var blocks = 0;
    var unblocks = 0;
    var failNextProfileRefresh = false;
    api.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/usuarios/alvo' && options.method == 'GET') {
          if (failNextProfileRefresh) {
            failNextProfileRefresh = false;
            handler.reject(DioException(requestOptions: options));
            return;
          }
          handler.resolve(Response(
            requestOptions: options,
            data: <String, Object?>{
              'id': 'alvo',
              'nome': 'Perfil Alvo',
              'username': 'perfil.alvo',
              'total_projetos': 0,
              'total_seguidores': 0,
              'total_seguindo': 0,
              'seguido_por_mim': false,
              'bloqueado_por_mim': blocked,
            },
          ));
          return;
        }
        if (options.path == '/usuarios/alvo/carros') {
          handler.resolve(Response(requestOptions: options, data: <Object?>[]));
          return;
        }
        if (options.path == '/usuarios/alvo/bloqueio') {
          if (options.method == 'PUT') {
            blocked = true;
            blocks++;
            failNextProfileRefresh = true;
          } else if (options.method == 'DELETE') {
            blocked = false;
            unblocks++;
            failNextProfileRefresh = true;
          }
          handler.resolve(
              Response<void>(requestOptions: options, statusCode: 204));
          return;
        }
        handler.reject(DioException(requestOptions: options));
      },
    ));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: PublicProfileScreen(
        userId: 'alvo',
        currentUserId: 'eu',
        usersRepository: UsersRepository(api),
        carsRepository: CarsRepository(api),
        evolutionsRepository: EvolutionsRepository(api),
        messagesRepository: MessagesRepository(api),
        onConversationChanged: () {},
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bloquear perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Bloquear perfil?'), findsOneWidget);
    await tester.tap(find.text('Bloquear', skipOffstage: false));
    await tester.pumpAndSettle();
    expect(blocks, 1);
    expect(find.textContaining('Você bloqueou este perfil'), findsOneWidget);
    expect(find.text('Algo deu errado. Tente novamente.'), findsNothing);

    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desbloquear perfil'));
    await tester.pumpAndSettle();
    expect(unblocks, 1);
    expect(find.textContaining('Você bloqueou este perfil'), findsNothing);
    expect(find.text('Algo deu errado. Tente novamente.'), findsNothing);
  });

  testWidgets('lista remove perfil mesmo quando resposta do desbloqueio falha',
      (tester) async {
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    var blocked = true;
    api.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/usuarios/me/bloqueios') {
          handler.resolve(Response(
            requestOptions: options,
            data: blocked
                ? <Object?>[
                    {'id': 'alvo', 'nome': 'Perfil Alvo', 'username': 'alvo'}
                  ]
                : <Object?>[],
          ));
          return;
        }
        if (options.path == '/usuarios/alvo/bloqueio' &&
            options.method == 'DELETE') {
          blocked = false;
          handler.reject(DioException(requestOptions: options));
          return;
        }
        handler.reject(DioException(requestOptions: options));
      },
    ));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: BlockedUsersScreen(repository: UsersRepository(api)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Perfil Alvo'), findsOneWidget);
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum perfil bloqueado.'), findsOneWidget);
    expect(find.text('Algo deu errado. Tente novamente.'), findsNothing);
  });
}
