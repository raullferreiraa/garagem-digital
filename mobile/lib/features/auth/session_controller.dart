import 'package:flutter/foundation.dart';
import 'package:garagem_mobile/features/auth/auth_repository.dart';
import 'package:garagem_mobile/features/auth/user.dart';

enum SessionStatus { initializing, signedOut, authenticated }

final class SessionController extends ChangeNotifier {
  SessionController({required AuthRepository repository}) : _repository = repository;

  final AuthRepository _repository;
  SessionStatus status = SessionStatus.initializing;
  User? user;

  Future<void> restore() async {
    if (!await _repository.hasSession()) {
      status = SessionStatus.signedOut;
      notifyListeners();
      return;
    }
    try {
      user = await _repository.currentUser();
      status = SessionStatus.authenticated;
    } catch (_) {
      await _repository.clearSession();
      status = SessionStatus.signedOut;
    }
    notifyListeners();
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

  Future<void> logout() async {
    await _repository.logout();
    user = null;
    status = SessionStatus.signedOut;
    notifyListeners();
  }
}
