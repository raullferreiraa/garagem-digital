import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/features/auth/user.dart';
import 'package:garagem_mobile/features/cars/car.dart';

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

  test('converte carro publico retornado pelo feed', () {
    final car = Car.fromJson({
      'id': '76db2576-7f23-46d6-bd71-cdcd44987724',
      'modelo': 'Gol GTI',
      'ano': 1994,
      'cor': 'Azul',
      'foto_principal_url': null,
      'status_projeto': 'Em evolucao',
      'proprietario': {
        'id': 'a58bcf75-f9a3-4b05-a3e3-c4a1eaf76575',
        'nome': 'Raul Ferreira',
        'username': 'raul',
        'avatar_url': null,
      },
    });

    expect(car.model, 'Gol GTI');
    expect(car.ownerUsername, 'raul');
  });
}
