import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/features/notifications/app_notification.dart';

void main() {
  test('aviso de edição preserva o encontro ao ser marcado como lido', () {
    final notification = AppNotification.fromJson({
      'id': 'notification-1',
      'tipo': 'nova_edicao_encontro',
      'mensagem': 'Nova edição marcada.',
      'encontro_id': 'event-1',
      'criada_em': '2026-09-24T12:00:00Z',
    });

    expect(notification.eventId, 'event-1');
    expect(notification.copyWith(readAt: DateTime.now()).eventId, 'event-1');
  });
}
