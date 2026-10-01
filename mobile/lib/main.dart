import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:garona_mobile/app/app.dart';
import 'package:garona_mobile/core/config/app_config.dart';
import 'package:garona_mobile/core/network/api_client.dart';
import 'package:garona_mobile/core/storage/token_storage.dart';
import 'package:garona_mobile/features/auth/auth_repository.dart';
import 'package:garona_mobile/features/auth/session_controller.dart';
import 'package:garona_mobile/features/cars/cars_repository.dart';
import 'package:garona_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garona_mobile/features/events/events_repository.dart';
import 'package:garona_mobile/features/messages/messages_repository.dart';
import 'package:garona_mobile/features/notifications/notifications_repository.dart';
import 'package:garona_mobile/features/profile/users_repository.dart';
import 'package:garona_mobile/features/teams/teams_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final font in ['BarlowCondensed', 'Manrope']) {
      final text = await rootBundle.loadString('assets/fonts/$font-OFL.txt');
      yield LicenseEntryWithLineBreaks([font], text);
    }
  });

  const tokenStorage = SecureTokenStorage();
  final apiClient = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    tokenStorage: tokenStorage,
  );
  final session = SessionController(
    repository: AuthRepository(apiClient, tokenStorage),
  );

  runApp(
    GaronaApp(
      session: session,
      carsRepository: CarsRepository(apiClient),
      evolutionsRepository: EvolutionsRepository(apiClient),
      eventsRepository: EventsRepository(apiClient),
      messagesRepository: MessagesRepository(apiClient),
      notificationsRepository: NotificationsRepository(apiClient),
      teamsRepository: TeamsRepository(apiClient),
      usersRepository: UsersRepository(apiClient),
    ),
  );
  unawaited(session.restore());
}
