import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/sharing/gd_share.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';
import 'package:garagem_mobile/features/profile/public_profile.dart';
import 'package:garagem_mobile/features/sharing/share_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('br.com.garagem.garagem_mobile/share');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('compartilha texto pelo canal nativo do Android', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return null;
    });

    await GdShare.open(
      const GdSharePayload(title: 'Projeto', text: 'Texto público'),
    );

    expect(received?.method, 'shareText');
    expect(received?.arguments, <String, Object?>{
      'title': 'Projeto',
      'text': 'Texto público',
    });
  });

  test('projeto compartilhado não expõe placa privada', () {
    const car = Car(
      id: 'carro',
      model: 'OMEGA CD',
      year: 1996,
      ownerId: 'dono',
      ownerName: 'Raul',
      ownerUsername: 'raul',
      plate: 'ABC1D23',
      plateVisible: false,
    );

    final payload = ShareContent.project(car);

    expect(payload.text, contains('OMEGA CD 1996'));
    expect(payload.text, contains('@raul'));
    expect(payload.text, isNot(contains('ABC1D23')));
  });

  test('evolução e perfil recebem textos próprios', () {
    final evolution = Evolution(
      id: 'evolucao',
      carId: 'carro',
      title: 'Motor montado',
      description: 'Primeira partida.',
      authorName: 'Raul',
      authorUsername: 'raul',
      createdAt: DateTime.utc(2026, 9, 22),
    );
    const profile = PublicProfile(
      id: 'dono',
      name: 'Raul Ferreira',
      username: 'raul',
      projectCount: 2,
      followerCount: 10,
      followingCount: 5,
      followedByMe: false,
    );

    expect(ShareContent.evolution(evolution).text, contains('Motor montado'));
    expect(ShareContent.profile(profile).text, contains('seus 2 projetos'));
  });
}
