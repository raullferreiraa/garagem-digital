import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/features/messages/messages_repository.dart';

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
