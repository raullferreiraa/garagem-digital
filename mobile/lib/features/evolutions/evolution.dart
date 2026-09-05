final class Evolution {
  const Evolution({
    required this.id,
    required this.carId,
    required this.title,
    required this.description,
    required this.authorName,
    required this.authorUsername,
    required this.createdAt,
    this.category,
    this.occurredAt,
    this.mileageKm,
  });

  factory Evolution.fromJson(Map<String, Object?> json) {
    final author = json['autor']! as Map<String, Object?>;
    return Evolution(
      id: json['id']! as String,
      carId: json['carro_id']! as String,
      title: json['titulo']! as String,
      description: json['descricao']! as String,
      authorName: author['nome']! as String,
      authorUsername: author['username']! as String,
      category: json['categoria'] as String?,
      occurredAt: _optionalDate(json['ocorreu_em']),
      mileageKm: json['quilometragem_km'] as int?,
      createdAt: DateTime.parse(json['criado_em']! as String),
    );
  }

  final String id;
  final String carId;
  final String title;
  final String description;
  final String authorName;
  final String authorUsername;
  final String? category;
  final DateTime? occurredAt;
  final int? mileageKm;
  final DateTime createdAt;

  DateTime get timelineDate => occurredAt ?? createdAt;

  static DateTime? _optionalDate(Object? value) {
    return value is String ? DateTime.parse(value) : null;
  }
}

final class EvolutionInput {
  const EvolutionInput({
    required this.title,
    required this.description,
    this.category,
    this.occurredAt,
    this.mileageKm,
  });

  final String title;
  final String description;
  final String? category;
  final DateTime? occurredAt;
  final int? mileageKm;

  Map<String, Object?> toJson() => {
        'titulo': title.trim(),
        'descricao': description.trim(),
        'categoria': category,
        'ocorreu_em': occurredAt?.toUtc().toIso8601String(),
        'quilometragem_km': mileageKm,
      };
}

const evolutionCategoryLabels = <String, String>{
  'mecanica': 'Mecânica',
  'estetica': 'Estética',
  'manutencao': 'Manutenção',
  'evento': 'Evento',
  'historia': 'História',
  'outra': 'Outra',
};
