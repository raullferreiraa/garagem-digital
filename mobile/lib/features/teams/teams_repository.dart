import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/teams/team.dart';

final class TeamsRepository {
  TeamsRepository(this._api);

  final ApiClient _api;

  Future<List<Team>> list() async {
    final response = await _api.dio.get<List<Object?>>('/equipes');
    return response.data!
        .cast<Map<String, Object?>>()
        .map(Team.fromJson)
        .toList(growable: false);
  }

  Future<TeamDetail> detail(String teamId) async {
    final response =
        await _api.dio.get<Map<String, Object?>>('/equipes/$teamId');
    return TeamDetail.fromJson(response.data!);
  }

  Future<TeamDetail> create(TeamInput input) async {
    final response = await _api.dio.post<Map<String, Object?>>(
      '/equipes',
      data: input.toJson(),
    );
    return TeamDetail.fromJson(response.data!);
  }

  Future<void> requestEntry(String teamId) async {
    await _api.dio.post<Object?>('/equipes/$teamId/solicitacoes');
  }

  Future<void> decideRequest(
    String teamId,
    String requestId, {
    required bool approve,
  }) async {
    await _api.dio.patch<Object?>(
      '/equipes/$teamId/solicitacoes/$requestId',
      data: {'decisao': approve ? 'aprovar' : 'recusar'},
    );
  }

  Future<void> selectCar(String teamId, String carId) async {
    await _api.dio.put<Object?>(
      '/equipes/$teamId/meu-carro',
      data: {'carro_id': carId},
    );
  }

  Future<void> removeSelectedCar(String teamId) async {
    await _api.dio.delete<Object?>('/equipes/$teamId/meu-carro');
  }
}
