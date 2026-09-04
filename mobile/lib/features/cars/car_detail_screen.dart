import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_form_screen.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';

enum _CarAction { edit, delete }

final class CarDetailScreen extends StatefulWidget {
  const CarDetailScreen({
    required this.car,
    required this.repository,
    required this.canManage,
    super.key,
  });

  final Car car;
  final CarsRepository repository;
  final bool canManage;

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  late Car _car = widget.car;
  bool _deleting = false;

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<Car>(
      MaterialPageRoute(
        builder: (_) => CarFormScreen(
          repository: widget.repository,
          car: _car,
        ),
      ),
    );
    if (updated != null && mounted) setState(() => _car = updated);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir carro?'),
        content: Text(
          'O projeto ${_car.model} será removido da sua garagem. Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await widget.repository.delete(_car.id);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
    }
  }

  void _selectAction(_CarAction action) {
    switch (action) {
      case _CarAction.edit:
        _edit();
        break;
      case _CarAction.delete:
        _delete();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final specs = <(String, String?)>[
      ('Ano', _car.year?.toString()),
      ('Cor', _car.color),
      ('Motor', _car.engine),
      ('Câmbio', _car.transmission),
      ('Combustível', _car.fuel),
      ('Potência', _car.estimatedPower),
      ('Preparação', _car.preparation),
      ('Suspensão', _car.suspensionType),
      ('Rodas', _car.wheelSize == null ? null : 'Aro ${_car.wheelSize}'),
      ('Placa', _car.plate),
    ].where((item) => item.$2 != null).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(_car.model),
        actions: [
          if (widget.canManage)
            PopupMenuButton<_CarAction>(
              enabled: !_deleting,
              onSelected: _selectAction,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _CarAction.edit,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Editar'),
                  ),
                ),
                PopupMenuItem(
                  value: _CarAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Excluir'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _deleting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: _car.photoUrl == null
                      ? const ColoredBox(
                          color: Color(0xFF24262A),
                          child: Icon(Icons.directions_car_rounded, size: 96),
                        )
                      : Image.network(
                          _car.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Color(0xFF24262A),
                            child: Icon(Icons.broken_image_outlined, size: 64),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [_car.model, _car.year]
                            .where((value) => value != null)
                            .join(' '),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text('${_car.ownerName}  @${_car.ownerUsername}'),
                      if (_car.projectStatus != null) ...[
                        const SizedBox(height: 12),
                        Chip(label: Text(_car.projectStatus!)),
                      ],
                      const SizedBox(height: 28),
                      Text(
                        'História do projeto',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _car.history ??
                            'O proprietário ainda não contou a história deste projeto.',
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Ficha do carro',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      if (specs.isEmpty)
                        const Text('A ficha técnica ainda não foi preenchida.')
                      else
                        Card(
                          child: Column(
                            children: [
                              for (var index = 0; index < specs.length; index++) ...[
                                _SpecRow(label: specs[index].$1, value: specs[index].$2!),
                                if (index < specs.length - 1)
                                  const Divider(height: 1),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

final class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
