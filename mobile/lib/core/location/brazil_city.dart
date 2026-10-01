import 'dart:convert';

import 'package:flutter/services.dart';

final class BrazilCity {
  const BrazilCity(this.name, this.state);

  final String name;
  final String state;

  String get label => '$name - $state';
}

final class BrazilCities {
  BrazilCities._();

  static Future<List<BrazilCity>>? _catalog;

  static Future<List<BrazilCity>> load() => _catalog ??= _load();

  static Future<List<BrazilCity>> _load() async {
    try {
      final source =
          await rootBundle.loadString('assets/data/br_municipios.json');
      final rows = jsonDecode(source) as List<dynamic>;
      return List<BrazilCity>.unmodifiable(rows.map((row) {
        final values = row as List<dynamic>;
        return BrazilCity(values[0] as String, values[1] as String);
      }));
    } catch (_) {
      _catalog = null;
      rethrow;
    }
  }

  static List<BrazilCity> search(
    List<BrazilCity> cities,
    String query, {
    String? state,
    int limit = 80,
  }) {
    final normalized = _fold(query.trim());
    if (normalized.length < 2) return const [];
    final matches = <BrazilCity>[];
    for (final city in cities) {
      if ((state == null || city.state == state) &&
          _fold(city.name).contains(normalized)) {
        matches.add(city);
        if (matches.length == limit) break;
      }
    }
    return matches;
  }

  static String _fold(String value) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    final lower = value.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      final index = from.indexOf(char);
      buffer.write(index == -1 ? char : to[index]);
    }
    return buffer.toString();
  }
}
