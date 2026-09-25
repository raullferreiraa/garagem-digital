import 'package:garagem_mobile/core/sharing/gd_share.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';
import 'package:garagem_mobile/features/events/event.dart';
import 'package:garagem_mobile/features/profile/public_profile.dart';

abstract final class ShareContent {
  static GdSharePayload event(GarageEvent event) {
    final date = event.startsAt?.toLocal();
    final edition = date == null
        ? 'Acompanhe as próximas edições dessa comunidade.'
        : 'Próxima edição: ${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/${date.year} às '
            '${date.hour.toString().padLeft(2, '0')}:'
            '${date.minute.toString().padLeft(2, '0')} · ${event.location}.';
    return GdSharePayload(
      title: event.name,
      text: 'Conheça ${event.name} no Garagem Digital.\n'
          '$edition',
    );
  }

  static GdSharePayload project(Car car) {
    final identity = [
      car.model,
      if (car.year != null) car.year.toString(),
    ].join(' ');
    return GdSharePayload(
      title: 'Projeto $identity',
      text: 'Conheça o $identity, projeto de @${car.ownerUsername}.\n\n'
          'Acompanhe essa garagem no Garagem Digital.',
    );
  }

  static GdSharePayload evolution(Evolution evolution) => GdSharePayload(
        title: evolution.title,
        text: '@${evolution.authorUsername} registrou “${evolution.title}” '
            'no diário de bordo.\n\n'
            'Veja esta evolução no Garagem Digital.',
      );

  static GdSharePayload profile(PublicProfile profile) => profileValues(
        name: profile.name,
        username: profile.username,
        projectCount: profile.projectCount,
      );

  static GdSharePayload profileValues({
    required String name,
    required String username,
    int? projectCount,
  }) {
    final projects = projectCount == null
        ? ''
        : ' e acompanhe ${projectCount == 1 ? 'seu projeto' : 'seus $projectCount projetos'}';
    return GdSharePayload(
      title: 'Perfil de @$username',
      text: 'Conheça $name (@$username) no Garagem Digital$projects.',
    );
  }
}
