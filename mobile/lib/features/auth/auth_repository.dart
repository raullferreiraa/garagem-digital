import 'package:dio/dio.dart';
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
    final response =
        await _api.dio.post<Map<String, Object?>>(path, data: body);
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

  Future<User> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _api.dio.post<Map<String, Object?>>(
      '/auth/alterar-senha',
      data: {
        'senha_atual': currentPassword,
        'nova_senha': newPassword,
      },
    );
    final data = response.data!;
    await _tokens.write(
      accessToken: data['access_token']! as String,
      refreshToken: data['refresh_token']! as String,
    );
    return User.fromJson(data['usuario']! as Map<String, Object?>);
  }

  Future<User> updateProfile({
    required String name,
    String? bio,
    String? city,
    String? state,
  }) async {
    final response = await _api.dio.patch<Map<String, Object?>>(
      '/usuarios/me',
      data: {
        'nome': name.trim(),
        'bio': _optionalText(bio),
        'cidade': _optionalText(city),
        'estado': _optionalText(state),
      },
    );
    return User.fromJson(response.data!);
  }

  Future<User> uploadAvatar({
    required List<int> bytes,
    required String fileName,
  }) async {
    final response = await _api.dio.post<Map<String, Object?>>(
      '/usuarios/me/avatar',
      data: FormData.fromMap({
        'arquivo': MultipartFile.fromBytes(bytes, filename: fileName),
      }),
    );
    return User.fromJson(response.data!);
  }

  Future<User> removeAvatar() async {
    final response = await _api.dio.delete<Map<String, Object?>>(
      '/usuarios/me/avatar',
    );
    return User.fromJson(response.data!);
  }

  String? _optionalText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
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
