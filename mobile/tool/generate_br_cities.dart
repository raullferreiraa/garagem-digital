// Atualiza o catálogo local a partir da API oficial de localidades do IBGE.
// Execute na pasta mobile: dart run tool/generate_br_cities.dart
import 'dart:convert';
import 'dart:io';

const source =
    'https://servicodados.ibge.gov.br/api/v1/localidades/municipios?view=nivelado';

Future<void> main() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client.getUrl(Uri.parse(source));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('IBGE respondeu HTTP ${response.statusCode}.');
    }
    final raw = jsonDecode(await utf8.decoder.bind(response).join()) as List;
    final cities = <List<String>>[];
    for (final item in raw) {
      final row = item as Map<String, dynamic>;
      final name = row['municipio-nome'] as String?;
      final state = row['UF-sigla'] as String?;
      if (name == null || name.isEmpty || state == null || state.length != 2) {
        throw StateError('Município sem nome ou UF na resposta do IBGE.');
      }
      cities.add([name, state]);
    }
    if (cities.length < 5500) {
      throw StateError('Resposta incompleta: ${cities.length} municípios.');
    }
    cities.sort((a, b) {
      final byName = a[0].compareTo(b[0]);
      return byName != 0 ? byName : a[1].compareTo(b[1]);
    });
    final output = File('assets/data/br_municipios.json');
    await output.parent.create(recursive: true);
    await output.writeAsString(jsonEncode(cities));
    stdout.writeln('Catálogo atualizado: ${cities.length} municípios.');
  } finally {
    client.close();
  }
}
