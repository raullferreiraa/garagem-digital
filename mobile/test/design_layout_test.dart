import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/core/theme/app_theme.dart';
import 'package:garagem_mobile/core/widgets/gd_navigation.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/auth/auth_repository.dart';
import 'package:garagem_mobile/features/auth/session_controller.dart';
import 'package:garagem_mobile/features/auth/user.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/home/home_shell.dart';
import 'package:garagem_mobile/features/notifications/notifications_repository.dart';
import 'package:garagem_mobile/features/profile/users_repository.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

class _Tokens implements TokenStorage {
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<String?> readRefreshToken() async => null;
  @override
  Future<void> write(
      {required String accessToken, required String refreshToken}) async {}
  @override
  Future<void> clear() async {}
}

const _owner = <String, Object?>{
  'id': 'driver',
  'nome': 'Rafael Oliveira',
  'username': 'rafa.garage',
};
const _car = <String, Object?>{
  'id': 'fusca',
  'modelo': 'FUSCA 1300',
  'ano': 1970,
  'status_projeto': 'Em evolução',
  'cor': 'AZUL',
  'motor': 'BOXER 1.3',
  'combustivel': 'Gasolina',
  'cambio': 'Manual',
  'placa': 'ABC1D23',
  'placa_visivel': false,
  'historia': 'Uma história de família. Cada detalhe, uma nova lembrança.',
  'proprietario': _owner,
  'total_curtidas': 28,
  'total_comentarios': 6,
};

// Public endpoints redact private plates; /carros/meus returns the owner's data.
final _publicCar = <String, Object?>{
  ..._car,
  'placa': null,
}..remove('placa_visivel');

Widget _app(double scale) {
  final tokens = _Tokens();
  final api =
      ApiClient(baseUrl: 'http://localhost/api/v1', tokenStorage: tokens);
  api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    final Object data = switch (options.path) {
      '/carros' => {
          'itens': [_publicCar],
          'proximo_cursor': null
        },
      '/carros/meus' => [_car],
      '/carros/fusca' => _publicCar,
      '/usuarios/driver' => {
          ..._owner,
          'bio': 'Clássicos, estrada e boas histórias.',
          'cidade': 'São Paulo',
          'estado': 'SP',
          'total_projetos': 1,
          'total_seguidores': 124,
          'total_seguindo': 86,
          'seguido_por_mim': false
        },
      '/equipes' => [
          {
            'id': 'club',
            'nome': 'Clube dos Clássicos',
            'slug': 'classicos',
            'visibilidade': 'publica',
            'total_membros': 32,
            'meu_papel': 'membro',
            'cidade': 'São Paulo',
            'estado': 'SP',
            'descricao': 'Preservando histórias sobre quatro rodas.'
          },
          {
            'id': 'club2',
            'nome': 'Encontro de entusiastas de projetos automotivos',
            'slug': 'entusiastas',
            'visibilidade': 'publica',
            'total_membros': 8
          },
        ],
      '/notificacoes/nao-lidas' => {'total': 1},
      '/notificacoes' => [
          {
            'id': 'notification',
            'tipo': 'novo_seguidor',
            'mensagem': '@marina começou a seguir você.',
            'ator': {'id': 'marina', 'username': 'marina'},
            'criada_em': DateTime.now()
                .subtract(const Duration(hours: 1))
                .toIso8601String()
          },
          {
            'id': 'notification2',
            'tipo': 'convite_equipe',
            'mensagem': 'Você recebeu um convite para Clube dos Clássicos.',
            'criada_em': DateTime.now()
                .subtract(const Duration(days: 1))
                .toIso8601String(),
            'lida_em': DateTime.now().toIso8601String()
          },
        ],
      _ => <Object?>[],
    };
    handler.resolve(Response(requestOptions: options, data: data));
  }));
  final session = SessionController(repository: AuthRepository(api, tokens))
    ..status = SessionStatus.authenticated
    ..user = const User(
        id: 'driver',
        name: 'Rafael Oliveira',
        username: 'rafa.garage',
        email: 'demo@example.com',
        bio: 'Clássicos, estrada e boas histórias.',
        city: 'São Paulo',
        state: 'SP');
  return MaterialApp(
    theme: AppTheme.dark,
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale), disableAnimations: true),
        child: child!),
    home: RepaintBoundary(
        key: const ValueKey('design-preview'),
        child: HomeShell(
            session: session,
            carsRepository: CarsRepository(api),
            evolutionsRepository: EvolutionsRepository(api),
            notificationsRepository: NotificationsRepository(api),
            teamsRepository: TeamsRepository(api),
            usersRepository: UsersRepository(api))),
  );
}

Future<void> _preview(WidgetTester tester, String name) async {
  final output = Platform.environment['GD_PREVIEW_DIR'];
  if (output == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('design-preview')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(output).create(recursive: true);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await (FontLoader('Manrope')
          ..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf')))
        .load();
    await (FontLoader('BarlowCondensed')
          ..addFont(
              rootBundle.load('assets/fonts/BarlowCondensed-SemiBold.ttf')))
        .load();
  });

  for (final layout in [(390.0, 1.0), (320.0, 1.4)]) {
    testWidgets(
        'abas mantêm conteúdo e navegação em ${layout.$1}px com escala ${layout.$2}',
        (tester) async {
      tester.view.physicalSize = Size(layout.$1, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(layout.$2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      const names = ['explorar', 'garagem', 'equipes', 'perfil'];
      for (var index = 0; index < 4; index++) {
        await tester.tap(find.byKey(ValueKey('nav-$index')));
        await tester.pumpAndSettle();
        expect(find.byType(GdNavigation), findsOneWidget);
        if (index == 0) {
          expect(find.byKey(const ValueKey('activity-bell')), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('activity-bell')));
          await tester.pumpAndSettle();
          expect(find.text('Atividade'), findsOneWidget);
          expect(find.byType(GdNavigation), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pageBack();
          await tester.pumpAndSettle();
        } else {
          expect(find.byKey(const ValueKey('activity-bell')), findsNothing);
        }
        expect(tester.takeException(), isNull, reason: 'Aba ${names[index]}');
        if (layout.$1 == 390) await _preview(tester, names[index]);
        final scrollables = find.byType(Scrollable);
        if (scrollables.evaluate().isNotEmpty) {
          // Inspect below-the-fold content as well as the header.
          final vertical = scrollables.evaluate().where((e) =>
              (e.widget as Scrollable).axisDirection == AxisDirection.down);
          if (vertical.isNotEmpty) {
            await tester.drag(
                find.byWidget(vertical.first.widget), const Offset(0, -420));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull,
                reason: 'Rolagem ${names[index]}');
          }
        }
      }
    });
  }

  testWidgets('carregamento respeita movimento reduzido e imagem ausente',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: GdSkeleton(compact: true)))));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: GdImage(width: 240, height: 150))));
    expect(find.byIcon(Icons.directions_car_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtros preservam tipografia e contraste da seleção',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Wrap(children: [
          ChoiceChip(
              label: const Text('Filtro ativo'),
              selected: true,
              onSelected: (_) {}),
          ChoiceChip(
              label: const Text('Filtro inativo'),
              selected: false,
              onSelected: (_) {}),
        ]),
      ),
    ));
    final active =
        DefaultTextStyle.of(tester.element(find.text('Filtro ativo'))).style;
    final inactive =
        DefaultTextStyle.of(tester.element(find.text('Filtro inativo'))).style;
    expect(active.fontFamily, 'Manrope');
    expect(inactive.fontFamily, 'Manrope');
    expect(active.color, AppColors.onPrimary);
    expect(inactive.color, AppColors.textMuted);
  });

  testWidgets('projeto público abre e retorna em tela estreita',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(1.4));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Abrir projeto').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir projeto').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('ABC1D23'), findsNothing);
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('ABC1D23'), findsNothing);
    }
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(GdNavigation), findsOneWidget);
    expect(find.text('Projetos para descobrir'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Entering through the owner's garage must retain their private data.
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Abrir projeto').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir projeto').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ABC1D23'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('ABC1D23'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
