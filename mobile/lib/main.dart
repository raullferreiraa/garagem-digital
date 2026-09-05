import 'dart:async';

import 'package:flutter/material.dart';
import 'package:garagem_mobile/app/app.dart';
import 'package:garagem_mobile/core/config/app_config.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/features/auth/auth_repository.dart';
import 'package:garagem_mobile/features/auth/session_controller.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const tokenStorage = SecureTokenStorage();
  final apiClient = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    tokenStorage: tokenStorage,
  );
  final session = SessionController(
    repository: AuthRepository(apiClient, tokenStorage),
  );

  runApp(
    GaragemApp(
      session: session,
      carsRepository: CarsRepository(apiClient),
      evolutionsRepository: EvolutionsRepository(apiClient),
    ),
  );
  unawaited(session.restore());
}
