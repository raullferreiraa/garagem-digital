import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/cars/car.dart';

final class CarsRepository {
  CarsRepository(this._api);

  final ApiClient _api;

  Future<List<Car>> feed() async {
    final response = await _api.dio.get<Map<String, Object?>>('/carros');
    final items = response.data!['itens']! as List<Object?>;
    return items
        .cast<Map<String, Object?>>()
        .map(Car.fromJson)
        .toList(growable: false);
  }

  Future<List<Car>> mine() async {
    final response = await _api.dio.get<List<Object?>>('/carros/meus');
    return response.data!
        .cast<Map<String, Object?>>()
        .map(Car.fromJson)
        .toList(growable: false);
  }

  Future<Car> create({
    required String model,
    int? year,
    String? color,
    String? plate,
    bool plateVisible = false,
    String? history,
    String? projectStatus,
  }) async {
    final response = await _api.dio.post<Map<String, Object?>>(
      '/carros',
      data: {
        'modelo': model.trim(),
        'ano': year,
        'cor': color,
        'placa': plate,
        'placa_visivel': plateVisible,
        'historia': history,
        'status_projeto': projectStatus,
      },
    );
    return Car.fromJson(response.data!);
  }
}
