import 'package:garagem_mobile/core/config/app_config.dart';

final class EventParticipants {
  const EventParticipants(
      {required this.people,
      required this.teams,
      required this.totalPeople,
      required this.totalTeams});

  factory EventParticipants.fromJson(Map<String, Object?> json) =>
      EventParticipants(
        people: (json['pessoas']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .map(EventParticipant.fromJson)
            .toList(growable: false),
        teams: (json['equipes']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .map(EventTeamParticipant.fromJson)
            .toList(growable: false),
        totalPeople: json['total_pessoas']! as int,
        totalTeams: json['total_equipes']! as int,
      );

  final List<EventParticipant> people;
  final List<EventTeamParticipant> teams;
  final int totalPeople, totalTeams;
}

final class EventParticipant {
  const EventParticipant({
    required this.userId,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.carModel,
    this.carYear,
    this.carPhotoUrl,
  });

  factory EventParticipant.fromJson(Map<String, Object?> json) {
    final user = json['usuario']! as Map<String, Object?>;
    final car = json['carro'] as Map<String, Object?>?;
    return EventParticipant(
      userId: user['id']! as String,
      name: user['nome']! as String,
      username: user['username']! as String,
      avatarUrl: AppConfig.resolveApiUrl(user['avatar_url'] as String?),
      carModel: car?['modelo'] as String?,
      carYear: car?['ano'] as int?,
      carPhotoUrl:
          AppConfig.resolveApiUrl(car?['foto_principal_url'] as String?),
    );
  }

  final String userId;
  final String name;
  final String username;
  final String? avatarUrl;
  final String? carModel;
  final int? carYear;
  final String? carPhotoUrl;
}

final class EventTeamParticipant {
  const EventTeamParticipant({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory EventTeamParticipant.fromJson(Map<String, Object?> json) =>
      EventTeamParticipant(
        id: json['id']! as String,
        name: json['nome']! as String,
        avatarUrl: AppConfig.resolveApiUrl(json['avatar_url'] as String?),
      );

  final String id;
  final String name;
  final String? avatarUrl;
}
