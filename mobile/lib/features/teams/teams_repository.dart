import 'package:dio/dio.dart';
import 'package:garagem_mobile/core/config/app_config.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/teams/team.dart';

final class TeamChatMessage {
  const TeamChatMessage({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.authorId,
    required this.authorName,
    required this.authorUsername,
    this.authorAvatarUrl,
  });

  factory TeamChatMessage.fromJson(Map<String, Object?> json) {
    final author = json['autor']! as Map<String, Object?>;
    return TeamChatMessage(
      id: json['id']! as String,
      content: json['conteudo']! as String,
      createdAt: DateTime.parse(json['criada_em']! as String),
      authorId: author['id']! as String,
      authorName: author['nome']! as String,
      authorUsername: author['username']! as String,
      authorAvatarUrl: AppConfig.resolveApiUrl(author['avatar_url'] as String?),
    );
  }

  final String id, content, authorId, authorName, authorUsername;
  final DateTime createdAt;
  final String? authorAvatarUrl;
}

final class TeamChatPage {
  const TeamChatPage({required this.items, this.nextCursor});

  factory TeamChatPage.fromJson(Map<String, Object?> json) => TeamChatPage(
        items: (json['itens']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .map(TeamChatMessage.fromJson)
            .toList(),
        nextCursor: json['proximo_cursor'] as String?,
      );

  final List<TeamChatMessage> items;
  final String? nextCursor;
}

final class TeamChatSummary {
  const TeamChatSummary({
    required this.teamId,
    required this.teamName,
    required this.unreadCount,
    this.teamAvatarUrl,
    this.lastMessage,
  });

  factory TeamChatSummary.fromJson(Map<String, Object?> json) =>
      TeamChatSummary(
        teamId: json['equipe_id']! as String,
        teamName: json['equipe_nome']! as String,
        teamAvatarUrl:
            AppConfig.resolveApiUrl(json['equipe_avatar_url'] as String?),
        unreadCount: json['total_nao_lidas']! as int,
        lastMessage: json['ultima_mensagem'] == null
            ? null
            : TeamChatMessage.fromJson(
                json['ultima_mensagem']! as Map<String, Object?>,
              ),
      );

  final String teamId;
  final String teamName;
  final String? teamAvatarUrl;
  final int unreadCount;
  final TeamChatMessage? lastMessage;
}

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

  Future<List<Team>> search(String query) async {
    final response = await _api.dio.get<List<Object?>>(
      '/equipes',
      queryParameters: {'busca': query},
    );
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

  Future<TeamDetail> update(String teamId, TeamInput input) async {
    final response = await _api.dio.patch<Map<String, Object?>>(
      '/equipes/$teamId',
      data: input.toJson(),
    );
    return TeamDetail.fromJson(response.data!);
  }

  Future<void> transferLeadership(String teamId, String userId) async {
    await _api.dio.patch<Object?>(
      '/equipes/$teamId/lideranca',
      data: {'usuario_id': userId},
    );
  }

  Future<void> endTeam(String teamId) async {
    await _api.dio.delete<Object?>('/equipes/$teamId');
  }

  Future<TeamDetail> uploadImage(
    String teamId,
    String type, {
    required List<int> bytes,
  }) async {
    final response = await _api.dio.post<Map<String, Object?>>(
      '/equipes/$teamId/imagens/$type',
      data: FormData.fromMap({
        'arquivo': MultipartFile.fromBytes(bytes, filename: '$type.jpg'),
      }),
    );
    return TeamDetail.fromJson(response.data!);
  }

  Future<TeamDetail> removeImage(String teamId, String type) async {
    final response = await _api.dio.delete<Map<String, Object?>>(
      '/equipes/$teamId/imagens/$type',
    );
    return TeamDetail.fromJson(response.data!);
  }

  Future<void> invite(String teamId, String userId) async {
    await _api.dio.post<Object?>(
      '/equipes/$teamId/convites',
      data: {'usuario_id': userId},
    );
  }

  Future<void> decideInvite(
    String teamId, {
    required bool accept,
  }) async {
    await _api.dio.patch<Object?>(
      '/equipes/$teamId/meu-convite',
      data: {'decisao': accept ? 'aceitar' : 'recusar'},
    );
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

  Future<void> updateMemberRole(
    String teamId,
    String userId,
    String role,
  ) async {
    await _api.dio.patch<Object?>(
      '/equipes/$teamId/membros/$userId/papel',
      data: {'papel': role},
    );
  }

  Future<void> removeMember(String teamId, String userId) async {
    await _api.dio.delete<Object?>('/equipes/$teamId/membros/$userId');
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

  Future<TeamChatSummary?> chatSummary() async {
    final response = await _api.dio.get<Map<String, Object?>?>(
      '/equipes/meu-chat/resumo',
    );
    final data = response.data;
    return data == null ? null : TeamChatSummary.fromJson(data);
  }

  Future<TeamChatPage> chat(String teamId, {String? cursor}) async {
    final response = await _api.dio.get<Map<String, Object?>>(
      '/equipes/$teamId/chat',
      queryParameters: {if (cursor != null) 'cursor': cursor},
    );
    return TeamChatPage.fromJson(response.data!);
  }

  Future<TeamChatMessage> sendChat(String teamId, String content) async {
    final response = await _api.dio.post<Map<String, Object?>>(
      '/equipes/$teamId/chat',
      data: {'conteudo': content},
    );
    return TeamChatMessage.fromJson(response.data!);
  }
}
