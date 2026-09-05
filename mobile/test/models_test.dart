import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/features/auth/user.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';

void main() {
  test('converte perfil privado retornado pela API', () {
    final user = User.fromJson({
      'id': 'a58bcf75-f9a3-4b05-a3e3-c4a1eaf76575',
      'nome': 'Raul Ferreira',
      'username': 'raul',
      'email': 'raul@example.com',
      'avatar_url': null,
      'bio': null,
      'cidade': 'Sao Paulo',
      'estado': 'SP',
    });

    expect(user.username, 'raul');
    expect(user.city, 'Sao Paulo');
  });

  test('converte ficha privada do carro retornada pela API', () {
    final car = Car.fromJson({
      'id': '76db2576-7f23-46d6-bd71-cdcd44987724',
      'modelo': 'Omega CD 4.1',
      'ano': 1996,
      'cor': 'Preto',
      'foto_principal_url': null,
      'status_projeto': 'Em evolução',
      'historia': 'Projeto de rua',
      'motor': '4.1 seis cilindros',
      'cambio': 'Manual',
      'combustivel': 'Gasolina',
      'potencia_estimada': '168 cv',
      'preparacao': null,
      'tipo_suspensao': 'Original',
      'aro_roda': 17,
      'placa': 'ABC1D23',
      'placa_visivel': false,
      'proprietario': {
        'id': 'a58bcf75-f9a3-4b05-a3e3-c4a1eaf76575',
        'nome': 'Raul Ferreira',
        'username': 'raul',
        'avatar_url': null,
      },
    });

    expect(car.model, 'Omega CD 4.1');
    expect(car.engine, '4.1 seis cilindros');
    expect(car.wheelSize, 17);
    expect(car.plateVisible, isFalse);
  });

  test('serializa dados editáveis usando os nomes da API', () {
    const input = CarInput(
      model: 'Omega CD 4.1',
      plateVisible: false,
      year: 1996,
      wheelSize: 17,
      estimatedPower: '168 cv',
    );

    final json = input.toJson();
    expect(json['modelo'], 'Omega CD 4.1');
    expect(json['aro_roda'], 17);
    expect(json['potencia_estimada'], '168 cv');
    expect(json['placa_visivel'], isFalse);
  });

  test('converte e serializa uma evolução do diário', () {
    final evolution = Evolution.fromJson({
      'id': 'e2e8ae1f-cebb-4f66-bd6f-75e1886f1e6b',
      'carro_id': '76db2576-7f23-46d6-bd71-cdcd44987724',
      'titulo': 'Primeira revisão',
      'descricao': 'Troca de óleo e filtros.',
      'categoria': 'manutencao',
      'ocorreu_em': '2026-09-05T12:00:00Z',
      'quilometragem_km': 185000,
      'criado_em': '2026-09-05T13:00:00Z',
      'autor': {
        'id': 'a58bcf75-f9a3-4b05-a3e3-c4a1eaf76575',
        'nome': 'Raul Ferreira',
        'username': 'raul',
        'avatar_url': null,
      },
    });

    expect(evolution.title, 'Primeira revisão');
    expect(evolution.mileageKm, 185000);
    expect(evolution.timelineDate.toUtc().hour, 12);

    final json = EvolutionInput(
      title: evolution.title,
      description: evolution.description,
      category: evolution.category,
      occurredAt: evolution.occurredAt,
      mileageKm: evolution.mileageKm,
    ).toJson();
    expect(json['categoria'], 'manutencao');
    expect(json['quilometragem_km'], 185000);
  });
}
