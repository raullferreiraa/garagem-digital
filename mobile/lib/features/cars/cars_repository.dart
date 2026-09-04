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
}
