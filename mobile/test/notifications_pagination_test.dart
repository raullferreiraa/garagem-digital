import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/features/notifications/notifications_repository.dart';
import 'package:garagem_mobile/features/notifications/notifications_screen.dart';

final class _Tokens implements TokenStorage {
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

void main() {
  testWidgets('carrega avisos antigos e os marca como vistos', (tester) async {
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _Tokens(),
    );
    final start = DateTime.utc(2026, 9, 27, 12);
    final recent = [
      for (var index = 0; index < 100; index++)
        <String, Object?>{
          'id': 'recent-$index',
          'tipo': 'novo_seguidor',
          'mensagem': 'Aviso recente $index',
          'criada_em':
              start.subtract(Duration(minutes: index)).toIso8601String(),
          'lida_em': start.toIso8601String(),
        },
    ];
    final old = <String, Object?>{
      'id': 'old',
      'tipo': 'novo_seguidor',
      'mensagem': 'Aviso antigo',
      'criada_em': start.subtract(const Duration(days: 1)).toIso8601String(),
    };
    final requests = <RequestOptions>[];
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      final Object? data;
      if (options.path == '/notificacoes/nao-lidas') {
        data = <String, Object?>{'total': 0};
      } else if (options.method == 'PATCH') {
        data = {...old, 'lida_em': start.toIso8601String()};
      } else if (options.queryParameters.containsKey('antes_de')) {
        data = [old];
      } else {
        data = recent;
      }
      handler.resolve(Response(requestOptions: options, data: data));
    }));

    await tester.pumpWidget(MaterialApp(
      home: NotificationsScreen(
        repository: NotificationsRepository(api),
        onUnreadChanged: (_) {},
        onOpen: (_) async {},
        refreshRevision: 0,
      ),
    ));
    await tester.pumpAndSettle();
    expect(requests.where((request) => request.method == 'PATCH'), isEmpty);

    await tester.scrollUntilVisible(
      find.text('Carregar avisos antigos'),
      2000,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Carregar avisos antigos'));
    await tester.pumpAndSettle();

    final olderRequest = requests.singleWhere(
      (request) => request.queryParameters.containsKey('antes_de'),
    );
    expect(olderRequest.queryParameters['ultimo_id'], 'recent-99');
    expect(olderRequest.queryParameters['antes_de'], recent.last['criada_em']);
    expect(
        requests.where((request) => request.path == '/notificacoes/old/lida'),
        hasLength(1));
    expect(find.text('Aviso antigo'), findsOneWidget);
    expect(find.text('Carregar avisos antigos'), findsNothing);
  });
}
