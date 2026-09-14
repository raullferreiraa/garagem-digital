import 'package:garagem_mobile/core/config/app_config.dart';

final class EvolutionComment {
  const EvolutionComment({
    required this.id,
    required this.evolutionId,
    required this.authorId,
    required this.authorName,
    required this.authorUsername,
    required this.content,
    required this.createdAt,
    this.authorAvatarUrl,
  });

  factory EvolutionComment.fromJson(Map<String, Object?> json) {
    final author = json['autor']! as Map<String, Object?>;
    return EvolutionComment(
      id: json['id']! as String,
      evolutionId: json['evolucao_id']! as String,
      authorId: author['id']! as String,
      authorName: author['nome']! as String,
      authorUsername: author['username']! as String,
      authorAvatarUrl: AppConfig.resolveApiUrl(author['avatar_url'] as String?),
      content: json['conteudo']! as String,
      createdAt: DateTime.parse(json['criado_em']! as String),
    );
  }

  final String id;
  final String evolutionId;
  final String authorId;
  final String authorName;
  final String authorUsername;
  final String? authorAvatarUrl;
  final String content;
  final DateTime createdAt;
}

final class EvolutionInteractions {
  const EvolutionInteractions({
    required this.totalLikes,
    required this.likedByMe,
    required this.comments,
  });

  factory EvolutionInteractions.fromJson(Map<String, Object?> json) {
    return EvolutionInteractions(
      totalLikes: json['total_curtidas']! as int,
      likedByMe: json['curtido_por_mim']! as bool,
      comments: (json['comentarios'] as List<Object?>? ?? const [])
          .cast<Map<String, Object?>>()
          .map(EvolutionComment.fromJson)
          .toList(growable: false),
    );
  }

  final int totalLikes;
  final bool likedByMe;
  final List<EvolutionComment> comments;

  EvolutionInteractions copyWith({
    int? totalLikes,
    bool? likedByMe,
    List<EvolutionComment>? comments,
  }) {
    return EvolutionInteractions(
      totalLikes: totalLikes ?? this.totalLikes,
      likedByMe: likedByMe ?? this.likedByMe,
      comments: comments ?? this.comments,
    );
  }
}
