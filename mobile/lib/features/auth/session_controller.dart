import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:garona_mobile/features/auth/auth_repository.dart';
import 'package:garona_mobile/features/auth/user.dart';

enum SessionStatus { initializing, unavailable, signedOut, authenticated }

final class SessionController extends ChangeNotifier {
  SessionController({required AuthRepository repository})
      : _repository = repository;

  final AuthRepository _repository;
  SessionStatus status = SessionStatus.initializing;
  User? user;

  Future<void> restore() async {
    status = SessionStatus.initializing;
    notifyListeners();
    try {
      if (!await _repository.hasSession()) {
        user = null;
        status = SessionStatus.signedOut;
        return;
      }
      user = await _repository.currentUser();
      status = SessionStatus.authenticated;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        try {
          await _repository.clearSession();
          user = null;
          status = SessionStatus.signedOut;
        } catch (_) {
          status = SessionStatus.unavailable;
        }
      } else {
        status = SessionStatus.unavailable;
      }
    } catch (_) {
      status = SessionStatus.unavailable;
    } finally {
      notifyListeners();
    }
  }

  Future<void> login(String identifier, String password) async {
    user = await _repository.login(identifier: identifier, password: password);
    status = SessionStatus.authenticated;
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    user = await _repository.register(
      name: name,
      username: username,
      email: email,
      password: password,
    );
    status = SessionStatus.authenticated;
    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    String? bio,
    String? city,
    String? state,
  }) async {
    user = await _repository.updateProfile(
      name: name,
      bio: bio,
      city: city,
      state: state,
    );
    notifyListeners();
  }

  Future<void> uploadAvatar({
    required List<int> bytes,
    required String fileName,
  }) async {
    user = await _repository.uploadAvatar(bytes: bytes, fileName: fileName);
    notifyListeners();
  }

  Future<void> removeAvatar() async {
    user = await _repository.removeAvatar();
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    user = await _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    await _repository.logout();
    user = null;
    status = SessionStatus.signedOut;
    notifyListeners();
  }
}
