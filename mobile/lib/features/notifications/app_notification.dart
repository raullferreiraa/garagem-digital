import 'package:garagem_mobile/core/config/app_config.dart';

final class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
    this.actorId,
    this.actorUsername,
    this.actorAvatarUrl,
    this.carId,
    this.evolutionId,
    this.teamId,
    this.eventId,
    this.commentId,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, Object?> json) {
    final actor = json['ator'] as Map<String, Object?>?;
    return AppNotification(
      id: json['id']! as String,
      type: json['tipo']! as String,
      message: json['mensagem']! as String,
      actorId: actor?['id'] as String?,
      actorUsername: actor?['username'] as String?,
      actorAvatarUrl: AppConfig.resolveApiUrl(actor?['avatar_url'] as String?),
      carId: json['carro_id'] as String?,
      evolutionId: json['evolucao_id'] as String?,
      teamId: json['equipe_id'] as String?,
      eventId: json['encontro_id'] as String?,
      commentId: json['comentario_id'] as String?,
      readAt: json['lida_em'] == null
          ? null
          : DateTime.parse(json['lida_em']! as String),
      createdAt: DateTime.parse(json['criada_em']! as String),
    );
  }

  final String id;
  final String type;
  final String message;
  final String? actorId;
  final String? actorUsername;
  final String? actorAvatarUrl;
  final String? carId;
  final String? evolutionId;
  final String? teamId;
  final String? eventId;
  final String? commentId;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  AppNotification copyWith({DateTime? readAt}) {
    return AppNotification(
      id: id,
      type: type,
      message: message,
      actorId: actorId,
      actorUsername: actorUsername,
      actorAvatarUrl: actorAvatarUrl,
      carId: carId,
      evolutionId: evolutionId,
      teamId: teamId,
      eventId: eventId,
      commentId: commentId,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
}
