import 'package:dio/dio.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';
import 'package:garagem_mobile/features/evolutions/evolution_interactions.dart';

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

  Future<Evolution> addPhoto(
    String carId,
    String evolutionId, {
    required List<int> bytes,
    required String fileName,
  }) async {
    final response = await _api.dio.post<Map<String, Object?>>(
      '/carros/$carId/evolucoes/$evolutionId/fotos',
      data: FormData.fromMap({
        'arquivo': MultipartFile.fromBytes(bytes, filename: fileName),
      }),
    );
    return Evolution.fromJson(response.data!);
  }

  Future<Evolution> removePhoto(
    String carId,
    String evolutionId,
    String photoId,
  ) async {
    final response = await _api.dio.delete<Map<String, Object?>>(
      '/carros/$carId/evolucoes/$evolutionId/fotos/$photoId',
    );
    return Evolution.fromJson(response.data!);
  }

  Future<EvolutionInteractions> interactions(
    String carId,
    String evolutionId,
  ) async {
    final response = await _api.dio.get<Map<String, Object?>>(
      '/carros/$carId/evolucoes/$evolutionId/interacoes',
    );
    return EvolutionInteractions.fromJson(response.data!);
  }

  Future<void> like(String carId, String evolutionId) async {
    await _api.dio.put<void>(
      '/carros/$carId/evolucoes/$evolutionId/curtida',
    );
  }

  Future<void> unlike(String carId, String evolutionId) async {
    await _api.dio.delete<void>(
      '/carros/$carId/evolucoes/$evolutionId/curtida',
    );
  }

  Future<EvolutionComment> comment(
    String carId,
    String evolutionId,
    String content,
  ) async {
    final response = await _api.dio.post<Map<String, Object?>>(
      '/carros/$carId/evolucoes/$evolutionId/comentarios',
      data: {'conteudo': content.trim()},
    );
    return EvolutionComment.fromJson(response.data!);
  }

  Future<void> deleteComment(
    String carId,
    String evolutionId,
    String commentId,
  ) async {
    await _api.dio.delete<void>(
      '/carros/$carId/evolucoes/$evolutionId/comentarios/$commentId',
    );
  }
}
