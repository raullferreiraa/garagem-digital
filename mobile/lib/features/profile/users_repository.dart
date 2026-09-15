import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/profile/public_profile.dart';

final class UsersRepository {
  UsersRepository(this._api);

  final ApiClient _api;

  Future<List<SocialUser>> search(String query) async {
    final response = await _api.dio.get<List<Object?>>(
      '/usuarios',
      queryParameters: {'busca': query},
    );
    return response.data!
        .cast<Map<String, Object?>>()
        .map(SocialUser.fromJson)
        .toList(growable: false);
  }

  Future<PublicProfile> profile(String userId) async {
    final response = await _api.dio.get<Map<String, Object?>>(
      '/usuarios/$userId',
    );
    return PublicProfile.fromJson(response.data!);
  }

  Future<List<Car>> cars(String userId) async {
    final response = await _api.dio.get<List<Object?>>(
      '/usuarios/$userId/carros',
    );
    return response.data!
        .cast<Map<String, Object?>>()
        .map(Car.fromJson)
        .toList(growable: false);
  }

  Future<List<SocialUser>> followers(String userId) {
    return _connections('/usuarios/$userId/seguidores');
  }

  Future<List<SocialUser>> following(String userId) {
    return _connections('/usuarios/$userId/seguindo');
  }

  Future<List<SocialUser>> _connections(String path) async {
    final response = await _api.dio.get<List<Object?>>(path);
    return response.data!
        .cast<Map<String, Object?>>()
        .map(SocialUser.fromJson)
        .toList(growable: false);
  }

  Future<void> follow(String userId) async {
    await _api.dio.put<void>('/usuarios/$userId/seguir');
  }

  Future<void> unfollow(String userId) async {
    await _api.dio.delete<void>('/usuarios/$userId/seguir');
  }
}
