import 'package:flutter/material.dart';

const acquisitionMonths = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro'
];

String formatAcquisitionDate(String value) {
  final parts = value.split('-');
  if (parts.length == 1) return parts.first;
  final month = int.tryParse(parts[1]);
  if (month == null || month < 1 || month > 12) return value;
  return '${acquisitionMonths[month - 1]} de ${parts.first}';
}

Future<String?> pickAcquisitionDate(BuildContext context, String? current) {
  final now = DateTime.now();
  final parts = current?.split('-');
  var year = int.tryParse(parts?.first ?? '') ?? now.year;
  int? month =
      parts != null && parts.length > 1 ? int.tryParse(parts[1]) : null;
  return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
                title: const Text('Comigo desde'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Escolha o ano. Informe o mês apenas se lembrar.'),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                      initialValue: year,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Ano'),
                      items: [
                        for (var y = now.year; y >= 1886; y--)
                          DropdownMenuItem(value: y, child: Text('$y'))
                      ],
                      onChanged: (value) => update(() {
                            year = value!;
                            if (year == now.year && (month ?? 0) > now.month)
                              month = null;
                          })),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                      key: ValueKey('$year-$month'),
                      initialValue: month ?? 0,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Mês (opcional)'),
                      items: [
                        const DropdownMenuItem(
                            value: 0, child: Text('Não informar')),
                        for (var m = 1;
                            m <= (year == now.year ? now.month : 12);
                            m++)
                          DropdownMenuItem(
                              value: m, child: Text(acquisitionMonths[m - 1]))
                      ],
                      onChanged: (value) =>
                          update(() => month = value == 0 ? null : value)),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(
                          context,
                          month == null
                              ? '$year'
                              : '$year-${month.toString().padLeft(2, '0')}'),
                      child: const Text('Confirmar'))
                ],
              )));
}
