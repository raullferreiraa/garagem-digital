import 'package:garagem_mobile/core/config/app_config.dart';
import 'package:garagem_mobile/features/cars/car.dart';

final class Team {
  const Team({
    required this.id,
    required this.name,
    required this.slug,
    required this.visibility,
    required this.memberCount,
    this.description,
    this.avatarUrl,
    this.coverUrl,
    this.city,
    this.state,
    this.myRole,
    this.myRequest,
    this.myInvite,
  });

  factory Team.fromJson(Map<String, Object?> json) => Team(
        id: json['id']! as String,
        name: json['nome']! as String,
        slug: json['slug']! as String,
        visibility: json['visibilidade']! as String,
        memberCount: json['total_membros']! as int,
        description: json['descricao'] as String?,
        avatarUrl: AppConfig.resolveApiUrl(json['avatar_url'] as String?),
        coverUrl: AppConfig.resolveApiUrl(json['capa_url'] as String?),
        city: json['cidade'] as String?,
        state: json['estado'] as String?,
        myRole: json['meu_papel'] as String?,
        myRequest: json['minha_solicitacao'] as String?,
        myInvite: json['meu_convite'] as String?,
      );

  final String id;
  final String name;
  final String slug;
  final String visibility;
  final int memberCount;
  final String? description;
  final String? avatarUrl;
  final String? coverUrl;
  final String? city;
  final String? state;
  final String? myRole;
  final String? myRequest;
  final String? myInvite;

  String? get location {
    final values = [city, state].whereType<String>().where((value) => value.isNotEmpty);
    return values.isEmpty ? null : values.join(' - ');
  }
}

final class TeamMember {
  const TeamMember({
    required this.userId,
    required this.name,
    required this.username,
    required this.role,
    this.avatarUrl,
  });

  factory TeamMember.fromJson(Map<String, Object?> json) {
    final user = json['usuario']! as Map<String, Object?>;
    return TeamMember(
      userId: user['id']! as String,
      name: user['nome']! as String,
      username: user['username']! as String,
      role: json['papel']! as String,
      avatarUrl: AppConfig.resolveApiUrl(user['avatar_url'] as String?),
    );
  }

  final String userId;
  final String name;
  final String username;
  final String role;
  final String? avatarUrl;
}

final class TeamRequest {
  const TeamRequest({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
  });

  factory TeamRequest.fromJson(Map<String, Object?> json) {
    final user = json['usuario']! as Map<String, Object?>;
    return TeamRequest(
      id: json['id']! as String,
      name: user['nome']! as String,
      username: user['username']! as String,
      avatarUrl: AppConfig.resolveApiUrl(user['avatar_url'] as String?),
    );
  }

  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
}

final class TeamDetail extends Team {
  const TeamDetail({
    required super.id,
    required super.name,
    required super.slug,
    required super.visibility,
    required super.memberCount,
    required this.ownerId,
    required this.members,
    required this.cars,
    required this.pendingRequests,
    super.description,
    super.avatarUrl,
    super.coverUrl,
    super.city,
    super.state,
    super.myRole,
    super.myRequest,
    super.myInvite,
  });

  factory TeamDetail.fromJson(Map<String, Object?> json) {
    final summary = Team.fromJson(json);
    return TeamDetail(
      id: summary.id,
      name: summary.name,
      slug: summary.slug,
      visibility: summary.visibility,
      memberCount: summary.memberCount,
      ownerId: json['dono_id']! as String,
      description: summary.description,
      avatarUrl: summary.avatarUrl,
      coverUrl: summary.coverUrl,
      city: summary.city,
      state: summary.state,
      myRole: summary.myRole,
      myRequest: summary.myRequest,
      myInvite: summary.myInvite,
      members: (json['membros']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(TeamMember.fromJson)
          .toList(growable: false),
      cars: (json['carros']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(Car.fromJson)
          .toList(growable: false),
      pendingRequests: (json['solicitacoes_pendentes']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(TeamRequest.fromJson)
          .toList(growable: false),
    );
  }

  final String ownerId;
  final List<TeamMember> members;
  final List<Car> cars;
  final List<TeamRequest> pendingRequests;
}

final class TeamInput {
  const TeamInput({
    required this.name,
    required this.visibility,
    this.description,
    this.city,
    this.state,
  });

  final String name;
  final String visibility;
  final String? description;
  final String? city;
  final String? state;

  Map<String, Object?> toJson() => {
        'nome': name.trim(),
        'descricao': description?.trim(),
        'cidade': city?.trim(),
        'estado': state?.trim(),
        'visibilidade': visibility,
      };
}
