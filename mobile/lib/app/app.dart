import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/config/app_config.dart';
import 'package:garagem_mobile/features/auth/login_screen.dart';
import 'package:garagem_mobile/features/auth/session_controller.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/home/home_shell.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

final class GaragemApp extends StatelessWidget {
  const GaragemApp({
    required this.session,
    required this.carsRepository,
    required this.evolutionsRepository,
    required this.teamsRepository,
    super.key,
  });

  final SessionController session;
  final CarsRepository carsRepository;
  final EvolutionsRepository evolutionsRepository;
  final TeamsRepository teamsRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5A1F),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF111214),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) => switch (session.status) {
          SessionStatus.initializing => const _StartupScreen(),
          SessionStatus.signedOut => LoginScreen(session: session),
          SessionStatus.authenticated => HomeShell(
              session: session,
              carsRepository: carsRepository,
              evolutionsRepository: evolutionsRepository,
              teamsRepository: teamsRepository,
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
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
