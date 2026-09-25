import 'package:dio/dio.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/events/event.dart';
import 'package:garagem_mobile/features/events/event_participants.dart';

final class EventsRepository {
  EventsRepository(this._api);
  final ApiClient _api;

  Future<List<GarageEvent>> list() async {
    final response = await _api.dio.get<List<Object?>>('/eventos');
    return response.data!
        .cast<Map<String, Object?>>()
        .map(GarageEvent.fromJson)
        .toList(growable: false);
  }

  Future<GarageEvent> detail(String id) async {
    final response = await _api.dio.get<Map<String, Object?>>('/eventos/$id');
    return GarageEvent.fromJson(response.data!);
  }

  Future<EventParticipants> participants(String id, String editionId,
      {required String type, int offset = 0, String query = ''}) async {
    final response = await _api.dio.get<Map<String, Object?>>(
      '/eventos/$id/edicoes/$editionId/participantes',
      queryParameters: {
        'tipo': type,
        'offset': offset,
        'limite': 30,
        if (query.trim().isNotEmpty) 'busca': query.trim(),
      },
    );
    return EventParticipants.fromJson(response.data!);
  }

  Future<GarageEvent> update(String id, EventInput input) async {
    final data = input.toJson()
      ..remove('organizador')
      ..remove('visibilidade')
      ..remove('proxima_edicao');
    final response =
        await _api.dio.patch<Map<String, Object?>>('/eventos/$id', data: data);
    return GarageEvent.fromJson(response.data!);
  }

  Map<String, Object?> _editionData(DateTime startsAt, String address,
          {required bool useCommunityRegion, String? city, String? state}) =>
      {
        'inicio': startsAt.toUtc().toIso8601String(),
        'endereco_publico': address.trim(),
        'usar_regiao_comunidade': useCommunityRegion,
        if (!useCommunityRegion) 'cidade': city?.trim(),
        if (!useCommunityRegion) 'estado': state?.trim(),
      };

  Future<GarageEvent> schedule(String id, DateTime startsAt, String address,
      {required bool useCommunityRegion, String? city, String? state}) async {
    final response = await _api.dio.post<Map<String, Object?>>(
        '/eventos/$id/edicoes',
        data: _editionData(startsAt, address,
            useCommunityRegion: useCommunityRegion, city: city, state: state));
    return GarageEvent.fromJson(response.data!);
  }

  Future<GarageEvent> updateEdition(
      String id, String editionId, DateTime startsAt, String address,
      {required bool useCommunityRegion, String? city, String? state}) async {
    final response = await _api.dio.patch<Map<String, Object?>>(
        '/eventos/$id/edicoes/$editionId',
        data: _editionData(startsAt, address,
            useCommunityRegion: useCommunityRegion, city: city, state: state));
    return GarageEvent.fromJson(response.data!);
  }

  Future<GarageEvent> cancelEdition(String id, String editionId) async {
    final response = await _api.dio.post<Map<String, Object?>>(
        '/eventos/$id/edicoes/$editionId/cancelamento');
    return GarageEvent.fromJson(response.data!);
  }

  Future<GarageEvent> uploadCover(
      String id, List<int> bytes, String filename) async {
    final response = await _api.dio.post<Map<String, Object?>>(
        '/eventos/$id/capa',
        data: FormData.fromMap(
            {'arquivo': MultipartFile.fromBytes(bytes, filename: filename)}));
    return GarageEvent.fromJson(response.data!);
  }

  Future<GarageEvent> create(EventInput input) async {
    final response = await _api.dio
        .post<Map<String, Object?>>('/eventos', data: input.toJson());
    return GarageEvent.fromJson(response.data!);
  }

  Future<GarageEvent> setPresence(String id,
      {required bool confirmed, required String editionId}) async {
    final response = confirmed
        ? await _api.dio.put<Map<String, Object?>>(
            '/eventos/$id/minha-presenca',
            queryParameters: {'edicao_id': editionId},
            data: {'status': 'confirmada'})
        : await _api.dio.delete<Map<String, Object?>>(
            '/eventos/$id/minha-presenca',
            queryParameters: {'edicao_id': editionId});
    return GarageEvent.fromJson(response.data!);
  }

  Future<GarageEvent> setFollowing(String id, {required bool following}) async {
    final response = following
        ? await _api.dio.put<Map<String, Object?>>('/eventos/$id/seguindo')
        : await _api.dio.delete<Map<String, Object?>>('/eventos/$id/seguindo');
    return GarageEvent.fromJson(response.data!);
  }

  Future<GarageEvent> setTeamParticipation(String id,
      {required bool confirmed,
      required String editionId,
      bool includeMembers = false}) async {
    final response = confirmed
        ? await _api.dio.put<Map<String, Object?>>('/eventos/$id/minha-equipe',
            queryParameters: {
                'edicao_id': editionId
              },
            data: {
                'status': 'confirmada',
                'confirmar_integrantes': includeMembers
              })
        : await _api.dio.delete<Map<String, Object?>>(
            '/eventos/$id/minha-equipe',
            queryParameters: {'edicao_id': editionId});
    return GarageEvent.fromJson(response.data!);
  }

  Future<void> delete(String id) async {
    await _api.dio.delete<void>('/eventos/$id');
  }
}
