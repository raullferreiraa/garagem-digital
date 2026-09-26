final class MessageReply {
  const MessageReply({
    required this.id,
    required this.authorId,
    required this.content,
    this.authorName,
    this.deleted = false,
  });

  factory MessageReply.fromJson(Map<String, Object?> json) {
    final author = json['autor'] as Map<String, Object?>?;
    return MessageReply(
      id: json['id']! as String,
      authorId: (author?['id'] ?? json['remetente_id'])! as String,
      authorName: author?['nome'] as String?,
      content: json['conteudo']! as String,
      deleted: json['excluida_em'] != null,
    );
  }

  final String id, authorId, content;
  final String? authorName;
  final bool deleted;
  String get displayContent => deleted ? 'Mensagem apagada' : content;

  @override
  bool operator ==(Object other) =>
      other is MessageReply &&
      other.id == id &&
      other.authorId == authorId &&
      other.authorName == authorName &&
      other.content == content &&
      other.deleted == deleted;

  @override
  int get hashCode => Object.hash(id, authorId, authorName, content, deleted);
}
