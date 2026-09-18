import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/storage/token_storage.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';

final class _EmptyTokenStorage implements TokenStorage {
  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> write({required String accessToken, required String refreshToken})
      async {}

  @override
  Future<void> clear() async {}
}

void main() {
  test('envia o cursor da página seguinte e lê o próximo cursor', () async {
    final cursors = <Object?>[];
    final api = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStorage: _EmptyTokenStorage(),
    );
    api.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        cursors.add(options.queryParameters['cursor']);
        handler.resolve(Response(
          requestOptions: options,
          data: <String, Object?>{
            'itens': <Object?>[],
            'proximo_cursor': cursors.length == 1 ? 'pagina-2' : null,
          },
        ));
      },
    ));

    final repository = CarsRepository(api);
    final first = await repository.feedPage();
    final second = await repository.feedPage(cursor: first.nextCursor);

    expect(first.nextCursor, 'pagina-2');
    expect(second.nextCursor, isNull);
    expect(cursors, [null, 'pagina-2']);
  });
}
