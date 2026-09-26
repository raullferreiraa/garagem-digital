import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/messages/conversation.dart';

final class MessagesRepository {
  MessagesRepository(this._api);

  final ApiClient _api;

  Future<List<DirectConversation>> conversations() async {
    final response = await _api.dio.get<List<Object?>>('/conversas');
    return response.data!
        .cast<Map<String, Object?>>()
        .map(DirectConversation.fromJson)
        .toList(growable: false);
  }

  Future<int> unreadCount() async {
    final response = await _api.dio.get<Map<String, Object?>>(
      '/conversas/nao-lidas',
    );
    return response.data!['total']! as int;
  }

  Future<DirectConversation> openDirect(String userId) async {
    final response = await _api.dio.post<Map<String, Object?>>(
      '/conversas/diretas',
      data: {'usuario_id': userId},
    );
    return DirectConversation.fromJson(response.data!);
  }

  Future<MessagePage> messages(
    String conversationId, {
    String? cursor,
    int limit = 30,
    String? query,
  }) async {
    final response = await _api.dio.get<Map<String, Object?>>(
      '/conversas/$conversationId/mensagens',
      queryParameters: {
        'limite': limit,
        if (cursor != null) 'cursor': cursor,
        if (query != null) 'busca': query,
      },
    );
    return MessagePage.fromJson(response.data!);
  }

  Future<DirectMessage> send(String conversationId, String content,
      {String? replyToId}) async {
    final response = await _api.dio.post<Map<String, Object?>>(
      '/conversas/$conversationId/mensagens',
      data: {
        'conteudo': content,
        if (replyToId != null) 'resposta_a_id': replyToId
      },
    );
    return DirectMessage.fromJson(response.data!);
  }

  Future<DirectMessage> message(String conversationId, String messageId) async {
    final response = await _api.dio.get<Map<String, Object?>>(
      '/conversas/$conversationId/mensagens/$messageId',
    );
    return DirectMessage.fromJson(response.data!);
  }

  Future<DirectMessage> edit(
      String conversationId, String messageId, String content) async {
    final response = await _api.dio.patch<Map<String, Object?>>(
      '/conversas/$conversationId/mensagens/$messageId',
      data: {'conteudo': content},
    );
    return DirectMessage.fromJson(response.data!);
  }

  Future<void> delete(String conversationId, String messageId) async {
    await _api.dio.delete<void>(
      '/conversas/$conversationId/mensagens/$messageId',
    );
  }

  Future<void> markRead(String conversationId) async {
    await _api.dio.post<void>('/conversas/$conversationId/lida');
  }
}
