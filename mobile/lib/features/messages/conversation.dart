import 'package:garagem_mobile/core/config/app_config.dart';

final class ConversationUser {
  const ConversationUser({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
  });

  factory ConversationUser.fromJson(Map<String, Object?> json) {
    return ConversationUser(
      id: json['id']! as String,
      name: json['nome']! as String,
      username: json['username']! as String,
      avatarUrl: AppConfig.resolveApiUrl(json['avatar_url'] as String?),
    );
  }

  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
}

final class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  factory DirectMessage.fromJson(Map<String, Object?> json) {
    return DirectMessage(
      id: json['id']! as String,
      conversationId: json['conversa_id']! as String,
      senderId: json['remetente_id']! as String,
      content: json['conteudo']! as String,
      createdAt: DateTime.parse(json['criada_em']! as String),
    );
  }

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
}

final class DirectConversation {
  const DirectConversation({
    required this.id,
    required this.otherUser,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
  });

  factory DirectConversation.fromJson(Map<String, Object?> json) {
    final message = json['ultima_mensagem'] as Map<String, Object?>?;
    return DirectConversation(
      id: json['id']! as String,
      otherUser: ConversationUser.fromJson(
        json['outro_usuario']! as Map<String, Object?>,
      ),
      lastMessage: message == null ? null : DirectMessage.fromJson(message),
      unreadCount: json['total_nao_lidas']! as int,
      createdAt: DateTime.parse(json['criada_em']! as String),
      updatedAt: DateTime.parse(json['atualizada_em']! as String),
    );
  }

  final String id;
  final ConversationUser otherUser;
  final DirectMessage? lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class MessagePage {
  const MessagePage({required this.items, this.nextCursor});

  factory MessagePage.fromJson(Map<String, Object?> json) {
    return MessagePage(
      items: (json['itens']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(DirectMessage.fromJson)
          .toList(growable: false),
      nextCursor: json['proximo_cursor'] as String?,
    );
  }

  final List<DirectMessage> items;
  final String? nextCursor;
}
