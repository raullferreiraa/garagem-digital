import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/core/theme/app_theme.dart';
import 'package:garagem_mobile/features/auth/auth_repository.dart';
import 'package:garagem_mobile/features/auth/login_screen.dart';
import 'package:garagem_mobile/features/auth/register_screen.dart';
import 'package:garagem_mobile/features/auth/session_controller.dart';
import 'package:garagem_mobile/features/notifications/notifications_repository.dart';
import 'package:garagem_mobile/features/notifications/notifications_screen.dart';

final class _MemoryTokens implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> write(
      {required String accessToken, required String refreshToken}) async {}
}

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.6)),
        child: child!,
      ),
      home: child,
    );

void _smallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final registration in [false, true]) {
    testWidgets(
        '${registration ? 'cadastro' : 'login'} permite acessar senha e '
        'ação em tela estreita com fonte ampliada', (tester) async {
      _smallScreen(tester);
      final tokens = _MemoryTokens();
      final api =
          ApiClient(baseUrl: 'http://localhost/api/v1', tokenStorage: tokens);
      final session =
          SessionController(repository: AuthRepository(api, tokens));
      addTearDown(session.dispose);
      await tester.pumpWidget(_app(registration
          ? RegisterScreen(session: session)
          : LoginScreen(session: session)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final password = find.byType(TextFormField).last;
      await tester.ensureVisible(password);
      await tester.enterText(password, 'senha-segura');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Mostrar senha'));
      await tester.tap(find.byTooltip('Mostrar senha'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Ocultar senha'), findsOneWidget);
      expect(tester.widget<TextFormField>(password).controller!.text,
          'senha-segura');
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.byType(FilledButton).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('atividade preserva leitura e abertura com nova composição',
      (tester) async {
    _smallScreen(tester);
    final api = ApiClient(
        baseUrl: 'http://localhost/api/v1', tokenStorage: _MemoryTokens());
    final item = <String, Object?>{
      'id': 'aviso-1',
      'tipo': 'novo_seguidor',
      'mensagem': '@piloto começou a seguir você.',
      'criada_em': DateTime.now().toUtc().toIso8601String(),
      'ator': <String, Object?>{'id': 'piloto', 'username': 'piloto'},
    };
    final requests = <String>[];
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add('${options.method} ${options.path}');
      handler.resolve(Response(
        requestOptions: options,
        data: options.path == '/notificacoes/nao-lidas'
            ? {'total': 0}
            : options.method == 'PATCH'
                ? {...item, 'lida_em': DateTime.now().toUtc().toIso8601String()}
                : [item],
      ));
    }));
    final unread = <int>[];
    final opened = <String>[];
    await tester.pumpWidget(_app(NotificationsScreen(
      repository: NotificationsRepository(api),
      onUnreadChanged: unread.add,
      onOpen: (item) async => opened.add(item.id),
      refreshRevision: 0,
    )));
    await tester.pumpAndSettle();
    expect(find.text('HOJE'), findsOneWidget);
    expect(requests, contains('PATCH /notificacoes/aviso-1/lida'));
    expect(requests, isNot(contains('POST /notificacoes/lidas')));
    expect(unread.last, 0);
    expect(find.text('1 novidade nesta visita'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.text('@piloto começou a seguir você.'))
          .style
          ?.fontWeight,
      FontWeight.w700,
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('@piloto começou a seguir você.'));
    await tester.tap(find.text('@piloto começou a seguir você.'));
    await tester.pumpAndSettle();
    expect(unread.last, 0);
    expect(opened, ['aviso-1']);
    expect(find.text('1 novidade nesta visita'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
