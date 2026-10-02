import 'package:garona_mobile/features/cars/project_garage.dart';
import 'package:dio/dio.dart';
import 'package:garona_mobile/core/network/api_client.dart';
import 'package:garona_mobile/features/cars/car.dart';

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

  Future<ProjectGarage> garage(String id) async {
    final response =
        await _api.dio.get<Map<String, Object?>>('/carros/$id/garagem');
    return ProjectGarage.fromJson(response.data!);
  }

  Future<void> addGalleryPhoto(String id, List<int> bytes, String name,
      {String caption = ''}) async {
    await _api.dio.post<Object?>('/carros/$id/galeria',
        data: FormData.fromMap({
          'arquivo': MultipartFile.fromBytes(bytes, filename: name),
          'legenda': caption
        }));
  }

  Future<void> captionPhoto(String id, String photoId, String caption) async {
    await _api.dio.patch<Object?>('/carros/$id/galeria/$photoId',
        data: {'legenda': caption});
  }

  Future<void> orderPhotos(String id, List<String> ids) async {
    await _api.dio.put<void>('/carros/$id/galeria/ordem', data: {'ids': ids});
  }

  Future<void> deleteGalleryPhoto(String id, String photoId) async {
    await _api.dio.delete<void>('/carros/$id/galeria/$photoId');
  }

  Future<Car> galleryCover(String id, String photoId) async {
    final response = await _api.dio
        .put<Map<String, Object?>>('/carros/$id/galeria/$photoId/capa');
    return Car.fromJson(response.data!);
  }

  Future<void> saveStage(String carId,
      {String? id,
      required String title,
      required String description,
      required String status,
      String? evolutionId}) async {
    final data = {
      'titulo': title,
      'descricao': description.isEmpty ? null : description,
      'status': status,
      'evolucao_id': evolutionId
    };
    if (id == null) {
      await _api.dio.post<Object?>('/carros/$carId/etapas', data: data);
    } else {
      await _api.dio.put<Object?>('/carros/$carId/etapas/$id', data: data);
    }
  }

  Future<void> deleteStage(String carId, String id) async {
    await _api.dio.delete<void>('/carros/$carId/etapas/$id');
  }

  Future<List<Car>> feed({
    CarFeedOrder order = CarFeedOrder.recent,
  }) async =>
      (await feedPage(order: order)).items;

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

  Future<List<Car>> search(String query) async =>
      (await searchPage(query)).items;

  Future<CarPage> searchPage(
    String query, {
    String? cursor,
    int? yearMin,
    int? yearMax,
  }) async {
    final response = await _api.dio.get<Map<String, Object?>>(
      '/carros',
      queryParameters: {
        'busca': query,
        if (cursor != null) 'cursor': cursor,
        if (yearMin != null) 'ano_min': yearMin,
        if (yearMax != null) 'ano_max': yearMax,
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

  Future<List<Car>> mine() async {
    final response = await _api.dio.get<List<Object?>>('/carros/meus');
    return response.data!
        .cast<Map<String, Object?>>()
        .map(Car.fromJson)
        .toList(growable: false);
  }

  Future<CarPage> saved({String? cursor, String? query}) async {
    final response = await _api.dio.get<Map<String, Object?>>(
      '/carros/salvos',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        if (query != null && query.trim().isNotEmpty) 'busca': query.trim(),
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

  Future<bool> isSaved(String carId) async {
    final response = await _api.dio.get<Map<String, Object?>>(
      '/carros/$carId/salvo',
    );
    return response.data!['salvo']! as bool;
  }

  Future<void> setSaved(String carId, {required bool saved}) async {
    if (saved) {
      await _api.dio.put<void>('/carros/$carId/salvo');
    } else {
      await _api.dio.delete<void>('/carros/$carId/salvo');
    }
  }

  Future<Car> detail(String carId) async {
    final response = await _api.dio.get<Map<String, Object?>>(
      '/carros/$carId',
    );
    return Car.fromJson(response.data!);
  }

  Future<Car> myDetail(String carId) async {
    final response = await _api.dio.get<Map<String, Object?>>(
      '/carros/$carId/meu',
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
