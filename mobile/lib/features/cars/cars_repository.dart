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

  Future<Car> create(CarInput input) async {
    final response = await _api.dio.post<Map<String, Object?>>(
      '/carros',
      data: input.toJson(),
    );
    return Car.fromJson(response.data!);
  }

  Future<Car> update(String carId, CarInput input) async {
    final response = await _api.dio.patch<Map<String, Object?>>(
      '/carros/$carId',
      data: input.toJson(),
    );
    return Car.fromJson(response.data!);
  }

  Future<void> delete(String carId) async {
    await _api.dio.delete<void>('/carros/$carId');
  }
}
