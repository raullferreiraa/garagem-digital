import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';

final class EvolutionsRepository {
  EvolutionsRepository(this._api);

  final ApiClient _api;

  Future<List<Evolution>> byCar(String carId) async {
    final response = await _api.dio.get<List<Object?>>(
      '/carros/$carId/evolucoes',
    );
    return response.data!
        .cast<Map<String, Object?>>()
        .map(Evolution.fromJson)
        .toList(growable: false);
  }

  Future<Evolution> create(String carId, EvolutionInput input) async {
    final response = await _api.dio.post<Map<String, Object?>>(
      '/carros/$carId/evolucoes',
      data: input.toJson(),
    );
    return Evolution.fromJson(response.data!);
  }

  Future<Evolution> update(
    String carId,
    String evolutionId,
    EvolutionInput input,
  ) async {
    final response = await _api.dio.patch<Map<String, Object?>>(
      '/carros/$carId/evolucoes/$evolutionId',
      data: input.toJson(),
    );
    return Evolution.fromJson(response.data!);
  }

  Future<void> delete(String carId, String evolutionId) async {
    await _api.dio.delete<void>('/carros/$carId/evolucoes/$evolutionId');
  }
}
