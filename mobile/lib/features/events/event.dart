final class GarageEvent {
  const GarageEvent(
      {required this.id,
      required this.editionId,
      required this.name,
      required this.startsAt,
      required this.visibility,
      required this.organizerType,
      required this.organizerName,
      required this.organizerId,
      required this.confirmedCount,
      required this.teamCount,
      required this.canManage,
      required this.followersCount,
      required this.following,
      this.coverUrl,
      this.editions = const [],
      this.description,
      this.endsAt,
      this.address,
      this.city,
      this.state,
      this.editionCity,
      this.editionState,
      this.myPresence,
      this.myTeamId,
      this.myTeamName,
      this.myTeamMemberCount = 0,
      this.myTeamRole,
      this.myTeamParticipation});

  factory GarageEvent.fromJson(Map<String, Object?> json) => GarageEvent(
        id: json['id']! as String,
        editionId: json['edicao_id'] as String?,
        name: json['nome']! as String,
        description: json['descricao'] as String?,
        startsAt: json['inicio'] == null
            ? null
            : DateTime.parse(json['inicio']! as String),
        endsAt: json['termino'] == null
            ? null
            : DateTime.parse(json['termino']! as String),
        address: json['endereco_publico'] as String?,
        city: json['cidade'] as String?,
        state: json['estado'] as String?,
        editionCity: json['edicao_cidade'] as String?,
        editionState: json['edicao_estado'] as String?,
        visibility: json['visibilidade']! as String,
        organizerType: json['organizador_tipo']! as String,
        organizerName: json['organizador_nome']! as String,
        organizerId: json['organizador_id']! as String,
        confirmedCount: json['total_confirmados']! as int,
        teamCount: json['total_equipes']! as int,
        myPresence: json['minha_presenca'] as String?,
        myTeamId: json['minha_equipe_id'] as String?,
        myTeamName: json['minha_equipe_nome'] as String?,
        myTeamMemberCount: json['minha_equipe_total_integrantes'] as int? ?? 0,
        myTeamRole: json['minha_equipe_papel'] as String?,
        myTeamParticipation: json['minha_equipe_participacao'] as String?,
        canManage: json['posso_gerenciar']! as bool,
        followersCount: json['total_seguidores']! as int,
        following: json['seguindo']! as bool,
        coverUrl: json['capa_url'] as String?,
        editions: (json['edicoes'] as List<Object?>? ?? [])
            .map((item) => EventEdition.fromJson(item! as Map<String, Object?>))
            .toList(),
      );

  final String id, name, visibility, organizerType, organizerName, organizerId;
  final String? editionId;
  final String? description,
      address,
      city,
      state,
      editionCity,
      editionState,
      myPresence,
      myTeamId,
      myTeamName,
      myTeamRole,
      myTeamParticipation;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int confirmedCount, teamCount, followersCount;
  final int myTeamMemberCount;
  final bool canManage, following;
  final String? coverUrl;
  final List<EventEdition> editions;

  String get location {
    final parts = [address, editionCity ?? city, editionState ?? state]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty);
    return parts.isEmpty ? 'Local a confirmar' : parts.join(' · ');
  }

  bool get canRepresentTeam =>
      const {'dono', 'administrador', 'moderador'}.contains(myTeamRole);
}

final class EventInput {
  const EventInput(
      {required this.name,
      required this.startsAt,
      required this.organizer,
      required this.visibility,
      this.description,
      this.address,
      this.city,
      this.state});
  final String name, organizer, visibility;
  final String? description, address, city, state;
  final DateTime? startsAt;
  Map<String, Object?> toJson() => {
        'nome': name.trim(),
        'descricao': description?.trim(),
        'cidade': city?.trim(),
        'estado': state?.trim(),
        'organizador': organizer,
        'visibilidade': visibility,
        if (startsAt != null)
          'proxima_edicao': {
            'inicio': startsAt!.toUtc().toIso8601String(),
            'endereco_publico': address?.trim(),
          },
      };
}

final class EventEdition {
  const EventEdition(
      {required this.id,
      required this.startsAt,
      this.address,
      this.city,
      this.state,
      required this.status,
      required this.confirmedCount});
  factory EventEdition.fromJson(Map<String, Object?> json) => EventEdition(
        id: json['id']! as String,
        startsAt: DateTime.parse(json['inicio']! as String),
        address: json['endereco_publico'] as String?,
        city: json['cidade'] as String?,
        state: json['estado'] as String?,
        status: json['status']! as String,
        confirmedCount: json['total_confirmados']! as int,
      );
  final String id;
  final DateTime startsAt;
  final String? address, city, state;
  final String status;
  final int confirmedCount;

  String location({String? fallbackCity, String? fallbackState}) {
    final parts = [address, city ?? fallbackCity, state ?? fallbackState]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty);
    return parts.isEmpty ? 'Local a confirmar' : parts.join(' · ');
  }
}
