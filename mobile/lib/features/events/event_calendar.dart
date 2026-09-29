import 'package:flutter/services.dart';

abstract final class EventCalendar {
  static const channel =
      MethodChannel('br.com.garagem.garagem_mobile/calendar');

  static Future<void> open({
    required String title,
    required DateTime startsAt,
    DateTime? endsAt,
    required String location,
  }) =>
      channel.invokeMethod<void>('addEvent', {
        'title': title,
        'startMillis': startsAt.millisecondsSinceEpoch,
        'endMillis': (endsAt ?? startsAt.add(const Duration(hours: 2)))
            .millisecondsSinceEpoch,
        'location': location,
      });
}
