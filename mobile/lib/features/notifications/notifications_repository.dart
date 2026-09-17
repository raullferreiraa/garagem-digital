import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/notifications/app_notification.dart';

final class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<List<AppNotification>> all() async {
    final response = await _api.dio.get<List<Object?>>('/notificacoes');
    return response.data!
        .cast<Map<String, Object?>>()
        .map(AppNotification.fromJson)
        .toList(growable: false);
  }

  Future<int> unreadCount() async {
    final response = await _api.dio.get<Map<String, Object?>>(
      '/notificacoes/nao-lidas',
    );
    return response.data!['total']! as int;
  }

  Future<AppNotification> markRead(String notificationId) async {
    final response = await _api.dio.patch<Map<String, Object?>>(
      '/notificacoes/$notificationId/lida',
    );
    return AppNotification.fromJson(response.data!);
  }

  Future<void> markAllRead() async {
    await _api.dio.post<void>('/notificacoes/lidas');
  }
}
