import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/features/messages/messages_repository.dart';
import 'package:garagem_mobile/features/messages/conversation.dart';
import 'package:garagem_mobile/features/messages/conversation_screen.dart';
import 'package:garagem_mobile/features/messages/conversations_screen.dart';
import 'package:garagem_mobile/features/teams/team.dart';
import 'package:garagem_mobile/features/teams/team_chat_screen.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';
import 'package:garagem_mobile/core/theme/app_theme.dart';

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

Map<String, Object?> _message(String id, String content) => {
      'id': id,
      'conversa_id': 'conversation',
      'remetente_id': 'other',
      'conteudo': content,
      'criada_em': '2026-09-22T18:30:00Z',
    };

Map<String, Object?> _conversation() => {
      'id': 'conversation',
      'outro_usuario': {
        'id': 'other',
        'nome': 'Bia Garage',
        'username': 'bia.garage',
        'avatar_url': '/media/avatar.webp',
      },
      'ultima_mensagem': _message('last', 'Até amanhã!'),
      'total_nao_lidas': 2,
      'criada_em': '2026-09-22T17:00:00Z',
      'atualizada_em': '2026-09-22T18:30:00Z',
    };

void main() {
  testWidgets('busca local filtra pessoas e equipe sem perder a lista',
      (tester) async {
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    final joao = _conversation();
    joao['id'] = 'joao-conversation';
    joao['outro_usuario'] = {
      'id': 'joao',
      'nome': 'João Silva',
      'username': 'joao.silva',
      'avatar_url': null,
    };
    final bia = _conversation();
    bia['outro_usuario'] = {
      'id': 'bia',
      'nome': 'Bia Garage',
      'username': 'bia.garage',
      'avatar_url': null,
    };
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response(requestOptions: options, data: [joao, bia]));
    }));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: ConversationsScreen(
        active: false,
        repository: MessagesRepository(api),
        currentUserId: 'me',
        refreshRevision: 0,
        onUnreadChanged: () {},
        onProfileTap: (_) {},
        onDiscover: () {},
        teamChat: const TeamChatSummary(
          teamId: 'team',
          teamName: 'Clássicos do Sul',
          unreadCount: 0,
        ),
        onTeamChatTap: () {},
        onTeamChatChanged: () {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('João Silva'), findsOneWidget);
    expect(find.text('Bia Garage'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'joao');
    await tester.pumpAndSettle();
    expect(find.text('João Silva'), findsOneWidget);
    expect(find.text('Bia Garage'), findsNothing);
    expect(find.text('Clássicos do Sul'), findsNothing);

    await tester.enterText(find.byType(TextField), '@bia.garage');
    await tester.pumpAndSettle();
    expect(find.text('João Silva'), findsNothing);
    expect(find.text('Bia Garage'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'classicos');
    await tester.pumpAndSettle();
    expect(find.text('Clássicos do Sul'), findsOneWidget);
    expect(find.text('Bia Garage'), findsNothing);

    await tester.enterText(find.byType(TextField), 'sem resultado');
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma conversa encontrada.'), findsOneWidget);
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();
    expect(find.text('João Silva'), findsOneWidget);
    expect(find.text('Bia Garage'), findsOneWidget);
    expect(find.text('Clássicos do Sul'), findsOneWidget);
  });

  testWidgets('caixa de entrada atualiza ao voltar para a aba de conversas',
      (tester) async {
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    var fetches = 0;
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      fetches++;
      handler.resolve(Response(
        requestOptions: options,
        data: fetches == 1 ? [_conversation()] : <Object?>[],
      ));
    }));
    Widget app(bool active) => MaterialApp(
          theme: AppTheme.dark,
          home: ConversationsScreen(
            active: active,
            repository: MessagesRepository(api),
            currentUserId: 'me',
            refreshRevision: 0,
            onUnreadChanged: () {},
            onProfileTap: (_) {},
            onDiscover: () {},
            teamChat: null,
            onTeamChatTap: () {},
            onTeamChatChanged: () {},
          ),
        );
    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();
    expect(find.text('Bia Garage'), findsOneWidget);
    expect(fetches, 1);

    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(fetches, 2);
    expect(find.text('Bia Garage'), findsNothing);
    expect(find.text('Sua caixa de entrada está livre.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('chat aberto oculta histórico após bloqueio e recupera acesso',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    var blocked = false;
    var fetches = 0;
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.method == 'GET') {
        fetches++;
        if (blocked) {
          handler.reject(DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 404),
            type: DioExceptionType.badResponse,
          ));
          return;
        }
        handler.resolve(Response(requestOptions: options, data: {
          'itens': [_message('first', 'Mensagem privada')],
          'proximo_cursor': null,
        }));
        return;
      }
      handler.resolve(Response(requestOptions: options, data: null));
    }));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: ConversationScreen(
        conversation: DirectConversation.fromJson(_conversation()),
        repository: MessagesRepository(api),
        currentUserId: 'me',
        onProfileTap: (_) {},
        onChanged: () {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Mensagem privada'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    blocked = true;
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(fetches, 2);
    expect(find.text('Mensagem privada'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Esta conversa não está disponível no momento.'),
        findsOneWidget);

    blocked = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Mensagem privada'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'lista preserva conversas e mostra recuperação quando atualização falha',
      (tester) async {
    final api = ApiClient(
        baseUrl: 'http://localhost/api/v1', tokenStorage: _EmptyTokenStorage());
    var fail = false;
    var discoveries = 0;
    final data = _conversation();
    data['outro_usuario'] = <String, Object?>{
      ...(data['outro_usuario'] as Map<String, Object?>),
      'avatar_url': null,
    };
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (fail) {
        handler.reject(DioException(
            requestOptions: options, type: DioExceptionType.connectionError));
      } else {
        handler.resolve(Response(requestOptions: options, data: [data]));
      }
    }));
    Widget app(int revision) => MaterialApp(
        theme: AppTheme.dark,
        home: ConversationsScreen(
            active: false,
            repository: MessagesRepository(api),
            currentUserId: 'me',
            refreshRevision: revision,
            onUnreadChanged: () {},
            onProfileTap: (_) {},
            onDiscover: () => discoveries++,
            teamChat: null,
            onTeamChatTap: () {},
            onTeamChatChanged: () {}));
    await tester.pumpWidget(app(0));
    await tester.pumpAndSettle();
    expect(find.text('Bia Garage'), findsOneWidget);
    expect(find.text('Conexões reais'), findsNothing);
    fail = true;
    await tester.pumpWidget(app(1));
    await tester.pumpAndSettle();
    expect(find.text('Bia Garage'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.byTooltip('Encontrar pessoas'));
    expect(discoveries, 1);
    fail = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsNothing);
  });
  for (final teamChat in [false, true]) {
    testWidgets('chat ${teamChat ? "da equipe" : "direto"} só atualiza visível',
        (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final api = ApiClient(
          baseUrl: 'http://localhost/api/v1',
          tokenStorage: _EmptyTokenStorage());
      var fetches = 0;
      RequestInterceptorHandler? initialHandler;
      RequestOptions? initialOptions;
      var sends = 0;
      api.dio.interceptors
          .add(InterceptorsWrapper(onRequest: (options, handler) {
        if (options.method == 'GET') {
          fetches++;
          if (fetches == 1) {
            initialHandler = handler;
            initialOptions = options;
            return;
          }
        }
        if (options.method == 'POST' &&
            (options.path.endsWith('/mensagens') ||
                options.path.endsWith('/chat'))) {
          sends++;
          handler.reject(DioException(
              requestOptions: options, type: DioExceptionType.connectionError));
          return;
        }
        handler.resolve(Response(requestOptions: options, data: {
          'itens': <Object?>[],
          'proximo_cursor': null,
        }));
      }));
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        theme: AppTheme.dark,
        home: teamChat
            ? TeamChatScreen(
                team: const Team(
                    id: 'team',
                    name: 'Equipe',
                    slug: 'equipe',
                    visibility: 'publica',
                    memberCount: 2),
                repository: TeamsRepository(api),
                currentUserId: 'me')
            : ConversationScreen(
                conversation: DirectConversation.fromJson(_conversation()),
                repository: MessagesRepository(api),
                currentUserId: 'me',
                onProfileTap: (_) {},
                onChanged: () {}),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(initialHandler, isNotNull);
      initialHandler!.resolve(Response(requestOptions: initialOptions!, data: {
        'itens': <Object?>[],
        'proximo_cursor': null,
      }));
      await tester.pumpAndSettle();
      expect(fetches, 1);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      final sendButton = find.byWidgetPredicate((widget) =>
          widget is IconButton && widget.tooltip == 'Enviar mensagem');
      expect(tester.widget<IconButton>(sendButton).onPressed, isNull);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(tester.widget<IconButton>(sendButton).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Olá, equipe!');
      await tester.pump();
      expect(tester.widget<IconButton>(sendButton).onPressed, isNotNull);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();
      expect(sends, 1);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Olá, equipe!');
      expect(tester.widget<IconButton>(sendButton).onPressed, isNotNull);
      await tester.enterText(find.byType(TextField), 'a' * 1800);
      await tester.pump();
      expect(find.text('1800/2000'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text('1800/2000'), findsNothing);
      expect(tester.widget<IconButton>(sendButton).onPressed, isNull);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(fetches, 2);
      navigator.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Outra tela'))));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 16));
      expect(fetches, 2);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 16));
      expect(fetches, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
      expect(fetches, 3);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(fetches, 4);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }

  test('mapeia caixa de entrada, paginação, envio e leitura', () async {
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    final requests = <RequestOptions>[];
    api.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(options);
        final Object data = switch ((options.method, options.path)) {
          ('GET', '/conversas') => [_conversation()],
          ('GET', '/conversas/nao-lidas') => {'total': 1},
          ('POST', '/conversas/diretas') => _conversation(),
          ('GET', '/conversas/conversation/mensagens') => {
              'itens': [_message('older', 'Mensagem anterior')],
              'proximo_cursor': 'next-page',
            },
          ('POST', '/conversas/conversation/mensagens') =>
            _message('sent', 'Nova mensagem'),
          ('POST', '/conversas/conversation/lida') => <String, Object?>{},
          _ => throw StateError('${options.method} ${options.path}'),
        };
        handler.resolve(Response(requestOptions: options, data: data));
      },
    ));
    final repository = MessagesRepository(api);

    final conversations = await repository.conversations();
    expect(conversations.single.otherUser.username, 'bia.garage');
    expect(conversations.single.unreadCount, 2);
    expect(conversations.single.lastMessage?.content, 'Até amanhã!');
    expect(await repository.unreadCount(), 1);

    final opened = await repository.openDirect('other');
    expect(opened.id, 'conversation');
    expect(requests.last.data, {'usuario_id': 'other'});

    final page = await repository.messages(
      'conversation',
      cursor: 'current-page',
      limit: 20,
    );
    expect(page.items.single.content, 'Mensagem anterior');
    expect(page.nextCursor, 'next-page');
    expect(requests.last.queryParameters, {
      'limite': 20,
      'cursor': 'current-page',
    });

    final sent = await repository.send('conversation', 'Nova mensagem');
    expect(sent.id, 'sent');
    expect(requests.last.data, {'conteudo': 'Nova mensagem'});

    await repository.markRead('conversation');
    expect(requests.last.path, '/conversas/conversation/lida');
  });
}
