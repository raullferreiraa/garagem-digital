import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/features/auth/user.dart';

final class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<User> login({required String identifier, required String password}) {
    return _authenticate('/auth/login', {
      'identificador': identifier,
      'senha': password,
    });
  }

  Future<User> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) {
    return _authenticate('/auth/cadastro', {
      'nome': name,
      'username': username,
      'email': email,
      'senha': password,
    });
  }

  Future<User> _authenticate(String path, Map<String, Object?> body) async {
    final response = await _api.dio.post<Map<String, Object?>>(path, data: body);
    final data = response.data!;
    await _tokens.write(
      accessToken: data['access_token']! as String,
      refreshToken: data['refresh_token']! as String,
    );
    return User.fromJson(data['usuario']! as Map<String, Object?>);
  }

  Future<User> currentUser() async {
    final response = await _api.dio.get<Map<String, Object?>>('/auth/me');
    return User.fromJson(response.data!);
  }

  Future<bool> hasSession() async => await _tokens.readRefreshToken() != null;

  Future<void> logout() async {
    final refreshToken = await _tokens.readRefreshToken();
    try {
      if (refreshToken != null) {
        await _api.dio.post<void>(
          '/auth/logout',
          data: {'refresh_token': refreshToken},
        );
      }
    } finally {
      await _tokens.clear();
    }
  }

  Future<void> clearSession() => _tokens.clear();
}
