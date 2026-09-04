final class Car {
  const Car({
    required this.id,
    required this.model,
    required this.ownerName,
    required this.ownerUsername,
    this.year,
    this.color,
    this.photoUrl,
    this.projectStatus,
  });

  factory Car.fromJson(Map<String, Object?> json) {
    final owner = json['proprietario']! as Map<String, Object?>;
    return Car(
      id: json['id']! as String,
      model: json['modelo']! as String,
      ownerName: owner['nome']! as String,
      ownerUsername: owner['username']! as String,
      year: json['ano'] as int?,
      color: json['cor'] as String?,
      photoUrl: json['foto_principal_url'] as String?,
      projectStatus: json['status_projeto'] as String?,
    );
  }

  final String id;
  final String model;
  final String ownerName;
  final String ownerUsername;
  final int? year;
  final String? color;
  final String? photoUrl;
  final String? projectStatus;
}
