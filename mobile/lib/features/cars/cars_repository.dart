import 'package:dio/dio.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/cars/car.dart';

enum CarFeedOrder {
  recent('recentes'),
  trending('em_alta');

  const CarFeedOrder(this.apiValue);

  final String apiValue;
}

final class CarPage {
  const CarPage({required this.items, this.nextCursor});

  final List<Car> items;
  final String? nextCursor;
}

final class CarsRepository {
  CarsRepository(this._api);

  final ApiClient _api;

  Future<List<Car>> feed({
    CarFeedOrder order = CarFeedOrder.recent,
  }) async => (await feedPage(order: order)).items;

  Future<CarPage> feedPage({
    CarFeedOrder order = CarFeedOrder.recent,
    String? cursor,
  }) async {
    final response = await _api.dio.get<Map<String, Object?>>(
      '/carros',
      queryParameters: {
        'ordem': order.apiValue,
        if (cursor != null) 'cursor': cursor,
      },
    );
    final items = response.data!['itens']! as List<Object?>;
    return CarPage(
      items: items
          .cast<Map<String, Object?>>()
          .map(Car.fromJson)
          .toList(growable: false),
      nextCursor: response.data!['proximo_cursor'] as String?,
    );
  }

  Future<List<Car>> search(String query) async {
    final response = await _api.dio.get<Map<String, Object?>>(
      '/carros',
      queryParameters: {'busca': query},
    );
    final items = response.data!['itens']! as List<Object?>;
    return items
        .cast<Map<String, Object?>>()
        .map(Car.fromJson)
        .toList(growable: false);
  }

  Future<List<Car>> mine() async {
    final response = await _api.dio.get<List<Object?>>('/carros/meus');
    return response.data!
        .cast<Map<String, Object?>>()
        .map(Car.fromJson)
        .toList(growable: false);
  }

  Future<Car> detail(String carId) async {
    final response = await _api.dio.get<Map<String, Object?>>(
      '/carros/$carId',
    );
    return Car.fromJson(response.data!);
  }

  Future<Car> create(CarInput input) async {
    final response = await _api.dio.post<Map<String, Object?>>(
      '/carros',
      data: input.toJson(),
    );
    return Car.fromJson(response.data!);
  }

  Future<Car> update(String carId, CarInput input) async {
    final response = await _api.dio.patch<Map<String, Object?>>(
      '/carros/$carId',
      data: input.toJson(),
    );
    return Car.fromJson(response.data!);
  }

  Future<void> delete(String carId) async {
    await _api.dio.delete<void>('/carros/$carId');
  }

  Future<Car> uploadMainPhoto(
    String carId, {
    required List<int> bytes,
    required String fileName,
  }) async {
    final response = await _api.dio.post<Map<String, Object?>>(
      '/carros/$carId/foto-principal',
      data: FormData.fromMap({
        'arquivo': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
        ),
      }),
    );
    return Car.fromJson(response.data!);
  }

  Future<Car> removeMainPhoto(String carId) async {
    final response = await _api.dio.delete<Map<String, Object?>>(
      '/carros/$carId/foto-principal',
    );
    return Car.fromJson(response.data!);
  }
}
