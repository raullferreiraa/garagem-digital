import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/config/app_config.dart';
import 'package:garagem_mobile/core/theme/app_theme.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/auth/login_screen.dart';
import 'package:garagem_mobile/features/auth/session_controller.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/events/events_repository.dart';
import 'package:garagem_mobile/features/home/home_shell.dart';
import 'package:garagem_mobile/features/messages/messages_repository.dart';
import 'package:garagem_mobile/features/notifications/notifications_repository.dart';
import 'package:garagem_mobile/features/profile/users_repository.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

final class GaragemApp extends StatelessWidget {
  const GaragemApp({
    required this.session,
    required this.carsRepository,
    required this.evolutionsRepository,
    required this.eventsRepository,
    required this.messagesRepository,
    required this.notificationsRepository,
    required this.teamsRepository,
    required this.usersRepository,
    super.key,
  });

  final SessionController session;
  final CarsRepository carsRepository;
  final EvolutionsRepository evolutionsRepository;
  final EventsRepository eventsRepository;
  final MessagesRepository messagesRepository;
  final NotificationsRepository notificationsRepository;
  final TeamsRepository teamsRepository;
  final UsersRepository usersRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) => switch (session.status) {
          SessionStatus.initializing => const _StartupScreen(),
          SessionStatus.unavailable => Scaffold(
              body: Center(
                  child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_outlined, size: 40),
                  const SizedBox(height: 16),
                  const Text(
                      'Não foi possível conectar. Sua sessão foi preservada.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: session.restore,
                      child: const Text('Tentar novamente')),
                ]),
              )),
            ),
          SessionStatus.signedOut => LoginScreen(session: session),
          SessionStatus.authenticated => HomeShell(
              session: session,
              carsRepository: carsRepository,
              evolutionsRepository: evolutionsRepository,
              eventsRepository: eventsRepository,
              messagesRepository: messagesRepository,
              notificationsRepository: notificationsRepository,
              teamsRepository: teamsRepository,
              usersRepository: usersRepository,
            ),
        },
      ),
    );
  }
}

final class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
        body: Center(
            child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GdWordmark(),
        SizedBox(height: 32),
        SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 2))
      ],
    )));
  }
}
