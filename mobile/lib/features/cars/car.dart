import 'package:garagem_mobile/core/config/app_config.dart';

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
    this.history,
    this.engine,
    this.transmission,
    this.fuel,
    this.estimatedPower,
    this.preparation,
    this.suspensionType,
    this.wheelSize,
    this.plate,
    this.plateVisible,
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
      photoUrl: AppConfig.resolveApiUrl(
        json['foto_principal_url'] as String?,
      ),
      projectStatus: json['status_projeto'] as String?,
      history: json['historia'] as String?,
      engine: json['motor'] as String?,
      transmission: json['cambio'] as String?,
      fuel: json['combustivel'] as String?,
      estimatedPower: json['potencia_estimada'] as String?,
      preparation: json['preparacao'] as String?,
      suspensionType: json['tipo_suspensao'] as String?,
      wheelSize: json['aro_roda'] as int?,
      plate: json['placa'] as String?,
      plateVisible: json['placa_visivel'] as bool?,
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
  final String? history;
  final String? engine;
  final String? transmission;
  final String? fuel;
  final String? estimatedPower;
  final String? preparation;
  final String? suspensionType;
  final int? wheelSize;
  final String? plate;
  final bool? plateVisible;
}

final class CarInput {
  const CarInput({
    required this.model,
    required this.plateVisible,
    this.year,
    this.color,
    this.projectStatus,
    this.history,
    this.engine,
    this.transmission,
    this.fuel,
    this.estimatedPower,
    this.preparation,
    this.suspensionType,
    this.wheelSize,
    this.plate,
  });

  final String model;
  final int? year;
  final String? color;
  final String? projectStatus;
  final String? history;
  final String? engine;
  final String? transmission;
  final String? fuel;
  final String? estimatedPower;
  final String? preparation;
  final String? suspensionType;
  final int? wheelSize;
  final String? plate;
  final bool plateVisible;

  Map<String, Object?> toJson() => {
        'modelo': model.trim(),
        'ano': year,
        'cor': color,
        'status_projeto': projectStatus,
        'historia': history,
        'motor': engine,
        'cambio': transmission,
        'combustivel': fuel,
        'potencia_estimada': estimatedPower,
        'preparacao': preparation,
        'tipo_suspensao': suspensionType,
        'aro_roda': wheelSize,
        'placa': plate,
        'placa_visivel': plateVisible,
      };
}
