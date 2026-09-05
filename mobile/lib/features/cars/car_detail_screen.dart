import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_form_screen.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';
import 'package:garagem_mobile/features/evolutions/evolution_form_screen.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:image_picker/image_picker.dart';

enum _CarAction { edit, delete }

enum _EvolutionAction { edit, delete }

enum _PhotoAction { camera, gallery, remove }

final class CarDetailScreen extends StatefulWidget {
  const CarDetailScreen({
    required this.car,
    required this.repository,
    required this.evolutionsRepository,
    required this.canManage,
    super.key,
  });

  final Car car;
  final CarsRepository repository;
  final EvolutionsRepository evolutionsRepository;
  final bool canManage;

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  late Car _car = widget.car;
  late Future<List<Evolution>> _evolutions;
  bool _deleting = false;
  bool _updatingPhoto = false;

  @override
  void initState() {
    super.initState();
    _evolutions = widget.evolutionsRepository.byCar(_car.id);
  }

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

  Future<void> _reloadEvolutions() async {
    final next = widget.evolutionsRepository.byCar(_car.id);
    setState(() => _evolutions = next);
    await next;
  }

  Future<void> _openEvolutionForm() async {
    final created = await Navigator.of(context).push<Evolution>(
      MaterialPageRoute(
        builder: (_) => EvolutionFormScreen(
          carId: _car.id,
          carModel: _car.model,
          repository: widget.evolutionsRepository,
        ),
      ),
    );
    if (created == null || !mounted) return;
    setState(() {
      _evolutions = _evolutions.then(
        (items) => [
          created,
          ...items.where((item) => item.id != created.id),
        ],
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Evolução registrada no diário.')),
    );
  }

  Future<void> _openPhotoActions() async {
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Foto principal'),
              subtitle: Text('Ela aparecerá na garagem e em Explorar.'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.of(context).pop(_PhotoAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.of(context).pop(_PhotoAction.gallery),
            ),
            if (_car.photoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remover foto'),
                onTap: () => Navigator.of(context).pop(_PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case _PhotoAction.camera:
        await _pickAndUploadPhoto(ImageSource.camera);
        break;
      case _PhotoAction.gallery:
        await _pickAndUploadPhoto(ImageSource.gallery);
        break;
      case _PhotoAction.remove:
        await _removePhoto();
        break;
    }
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (photo == null || !mounted) return;

      setState(() => _updatingPhoto = true);
      final updated = await widget.repository.uploadMainPhoto(
        _car.id,
        filePath: photo.path,
        fileName: photo.name,
      );
      if (!mounted) return;
      setState(() {
        _car = updated;
        _updatingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto principal atualizada.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
    }
  }

  Future<void> _removePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover foto?'),
        content: const Text(
          'O carro voltará a usar a imagem padrão até você escolher outra foto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _updatingPhoto = true);
    try {
      final updated = await widget.repository.removeMainPhoto(_car.id);
      if (!mounted) return;
      setState(() {
        _car = updated;
        _updatingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto principal removida.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
    }
  }

  Future<void> _editEvolution(Evolution evolution) async {
    final updated = await Navigator.of(context).push<Evolution>(
      MaterialPageRoute(
        builder: (_) => EvolutionFormScreen(
          carId: _car.id,
          carModel: _car.model,
          repository: widget.evolutionsRepository,
          evolution: evolution,
        ),
      ),
    );
    if (updated == null || !mounted) return;

    setState(() {
      _evolutions = _evolutions.then((items) {
        final next = [
          for (final item in items)
            if (item.id == updated.id) updated else item,
        ];
        next.sort((a, b) => b.timelineDate.compareTo(a.timelineDate));
        return next;
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Evolução atualizada.')),
    );
  }

  Future<void> _deleteEvolution(Evolution evolution) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir evolução?'),
        content: Text(
          'O registro “${evolution.title}” será removido do diário. Essa ação não pode ser desfeita.',
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

    try {
      await widget.evolutionsRepository.delete(_car.id, evolution.id);
      if (!mounted) return;
      setState(() {
        _evolutions = _evolutions.then(
          (items) => items
              .where((item) => item.id != evolution.id)
              .toList(growable: false),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evolução excluída.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
    }
  }

  void _selectEvolutionAction(
    _EvolutionAction action,
    Evolution evolution,
  ) {
    switch (action) {
      case _EvolutionAction.edit:
        _editEvolution(evolution);
        break;
      case _EvolutionAction.delete:
        _deleteEvolution(evolution);
        break;
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  Widget _evolutionTimeline() {
    return FutureBuilder<List<Evolution>>(
      future: _evolutions,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(apiErrorMessage(snapshot.error!)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _reloadEvolutions,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        }

        final evolutions = snapshot.data ?? const <Evolution>[];
        if (evolutions.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'O diário ainda está vazio. Cada mudança importante poderá ser registrada aqui.',
              ),
            ),
          );
        }

        return Column(
          children: [
            for (final evolution in evolutions)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatDate(evolution.timelineDate),
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            if (evolution.category != null)
                              Chip(
                                label: Text(
                                  evolutionCategoryLabels[evolution.category] ??
                                      evolution.category!,
                                ),
                              ),
                            if (widget.canManage)
                              PopupMenuButton<_EvolutionAction>(
                                tooltip: 'Opções da evolução',
                                onSelected: (action) =>
                                    _selectEvolutionAction(action, evolution),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: _EvolutionAction.edit,
                                    child: ListTile(
                                      leading: Icon(Icons.edit_outlined),
                                      title: Text('Editar'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _EvolutionAction.delete,
                                    child: ListTile(
                                      leading: Icon(Icons.delete_outline),
                                      title: Text('Excluir'),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        Text(
                          evolution.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(evolution.description),
                        if (evolution.mileageKm != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.speed_outlined, size: 18),
                              const SizedBox(width: 6),
                              Text('${evolution.mileageKm} km'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_car.photoUrl == null)
                        const ColoredBox(
                          color: Color(0xFF24262A),
                          child: Icon(Icons.directions_car_rounded, size: 96),
                        )
                      else
                        Image.network(
                          _car.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Color(0xFF24262A),
                            child: Icon(Icons.broken_image_outlined, size: 64),
                          ),
                        ),
                      if (widget.canManage && !_updatingPhoto)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: IconButton.filled(
                            onPressed: _openPhotoActions,
                            tooltip: 'Alterar foto principal',
                            icon: const Icon(Icons.add_a_photo_outlined),
                          ),
                        ),
                      if (_updatingPhoto)
                        const ColoredBox(
                          color: Color(0x66000000),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
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
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Diário de evoluções',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (widget.canManage)
                            IconButton.filled(
                              onPressed: _openEvolutionForm,
                              tooltip: 'Registrar evolução',
                              icon: const Icon(Icons.add),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _evolutionTimeline(),
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
