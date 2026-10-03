import 'package:garona_mobile/core/sharing/garona_share.dart';
import 'package:garona_mobile/features/cars/car.dart';
import 'package:garona_mobile/features/evolutions/evolution.dart';
import 'package:garona_mobile/features/events/event.dart';
import 'package:garona_mobile/features/profile/public_profile.dart';

abstract final class ShareContent {
  static GaronaSharePayload event(GarageEvent event) {
    final date = event.startsAt?.toLocal();
    final edition = date == null
        ? 'Acompanhe as próximas edições dessa comunidade.'
        : 'Próxima edição: ${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/${date.year} às '
            '${date.hour.toString().padLeft(2, '0')}:'
            '${date.minute.toString().padLeft(2, '0')} · ${event.location}.';
    return GaronaSharePayload(
      title: event.name,
      text: 'Conheça ${event.name} no Garona.\n'
          '$edition',
    );
  }

  static GaronaSharePayload project(Car car) {
    final identity = [
      if (car.projectName != null) car.projectName!,
      car.model,
      if (car.year != null) car.year.toString(),
    ].join(' ');
    return GaronaSharePayload(
      title: 'Projeto $identity',
      text: 'Conheça o $identity, projeto de @${car.ownerUsername}.\n\n'
          'Acompanhe essa garagem no Garona.',
    );
  }

  static GaronaSharePayload evolution(Evolution evolution) =>
      GaronaSharePayload(
        title: evolution.title,
        text: '@${evolution.authorUsername} registrou “${evolution.title}” '
            'no diário de bordo.\n\n'
            'Veja esta evolução no Garona.',
      );

  static GaronaSharePayload profile(PublicProfile profile) => profileValues(
        name: profile.name,
        username: profile.username,
        projectCount: profile.projectCount,
      );

  static GaronaSharePayload profileValues({
    required String name,
    required String username,
    int? projectCount,
  }) {
    final projects = projectCount == null
        ? ''
        : ' e acompanhe ${projectCount == 1 ? 'seu projeto' : 'seus $projectCount projetos'}';
    return GaronaSharePayload(
      title: 'Perfil de @$username',
      text: 'Conheça $name (@$username) no Garona$projects.',
    );
  }
}
