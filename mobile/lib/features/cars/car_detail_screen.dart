import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_form_screen.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/cars/photo_crop_screen.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';
import 'package:garagem_mobile/features/evolutions/evolution_detail_screen.dart';
import 'package:garagem_mobile/features/evolutions/evolution_form_screen.dart';
import 'package:garagem_mobile/features/evolutions/evolution_photos_screen.dart';
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
    this.currentUserId = '',
    this.onProfileTap,
    this.onOwnerTap,
    super.key,
  });

  final Car car;
  final CarsRepository repository;
  final EvolutionsRepository evolutionsRepository;
  final bool canManage;
  final String currentUserId;
  final ValueChanged<String>? onProfileTap;
  final VoidCallback? onOwnerTap;

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
    unawaited(_refreshCarSilently());
  }

  Future<void> _refreshCarSilently() async {
    try {
      final refreshed = await widget.repository.detail(_car.id);
      if (!mounted) return;
      setState(() {
        _car = widget.canManage
            ? refreshed.withPrivateDataFrom(_car)
            : refreshed;
      });
    } catch (_) {
      // O card recebido mantém a tela utilizável quando a atualização falha.
    }
  }

  Future<void> _reloadProject() async {
    final carRequest = widget.repository.detail(_car.id);
    final evolutionsRequest = widget.evolutionsRepository.byCar(_car.id);
    setState(() {
      _evolutions = evolutionsRequest;
    });

    Object? failure;
    try {
      final refreshed = await carRequest;
      if (mounted) {
        setState(() {
          _car = widget.canManage
              ? refreshed.withPrivateDataFrom(_car)
              : refreshed;
        });
      }
    } catch (error) {
      failure = error;
    }

    try {
      await evolutionsRequest;
    } catch (error) {
      failure ??= error;
    }

    if (failure != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(failure))),
      );
    }
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
    setState(() {
      _evolutions = next;
    });
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

  Future<void> _openEvolutionPhotos(Evolution evolution) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EvolutionPhotosScreen(
          evolution: evolution,
          repository: widget.evolutionsRepository,
          onChanged: _replaceEvolution,
        ),
      ),
    );
  }

  void _replaceEvolution(Evolution updated) {
    if (!mounted) return;
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

      final selectedBytes = await photo.readAsBytes();
      if (!mounted) return;
      final croppedBytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => PhotoCropScreen(image: selectedBytes),
        ),
      );
      if (croppedBytes == null || !mounted) return;

      setState(() => _updatingPhoto = true);
      final updated = await widget.repository.uploadMainPhoto(
        _car.id,
        bytes: croppedBytes,
        fileName: 'foto-principal.jpg',
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

  Future<void> _openEvolutionDetail(Evolution evolution) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EvolutionDetailScreen(
          evolution: evolution,
          repository: widget.evolutionsRepository,
          currentUserId: widget.currentUserId,
          onProfileTap: widget.onProfileTap,
        ),
      ),
    );
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

    _replaceEvolution(updated);
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

  String _formatNumber(int value) {
    final digits = value.toString();
    final formatted = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        formatted.write('.');
      }
      formatted.write(digits[index]);
    }
    return formatted.toString();
  }

  String _formatMileage(int value) => '${_formatNumber(value)} km';

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

        final latestDate = evolutions
            .map((evolution) => evolution.timelineDate)
            .reduce((current, candidate) =>
                candidate.isAfter(current) ? candidate : current);
        final evolutionsWithMileage = evolutions
            .where((evolution) => evolution.mileageKm != null)
            .toList(growable: false);
        final latestMileageEvolution = evolutionsWithMileage.isEmpty
            ? null
            : evolutionsWithMileage.reduce((current, candidate) =>
                candidate.timelineDate.isAfter(current.timelineDate)
                    ? candidate
                    : current);

        return Column(
          children: [
            _DiarySummary(
              count: evolutions.length,
              latestDate: _formatDate(latestDate),
              mileage: latestMileageEvolution?.mileageKm == null
                  ? null
                  : _formatMileage(latestMileageEvolution!.mileageKm!),
            ),
            const SizedBox(height: 12),
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
                              Text(_formatMileage(evolution.mileageKm!)),
                            ],
                          ),
                        ],
                        if (evolution.photos.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 112,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: evolution.photos.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final photo = evolution.photos[index];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => Navigator.of(context).push<void>(
                                    MaterialPageRoute(
                                      builder: (_) => EvolutionPhotoViewer(
                                        photos: evolution.photos,
                                        initialIndex: index,
                                      ),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: AspectRatio(
                                      aspectRatio: 4 / 3,
                                      child: Image.network(
                                        photo.url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const ColoredBox(
                                          color: Color(0xFF24262A),
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _openEvolutionDetail(evolution),
                            icon: const Icon(Icons.forum_outlined),
                            label: const Text('Ver conversa'),
                          ),
                        ),
                        if (widget.canManage) ...[
                          TextButton.icon(
                            onPressed: () => _openEvolutionPhotos(evolution),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(
                              evolution.photos.isEmpty
                                  ? 'Adicionar fotos'
                                  : 'Gerenciar ${evolution.photos.length} fotos',
                            ),
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
    final specs = <(String, String?, IconData)>[
      ('Ano', _car.year?.toString(), Icons.calendar_today_outlined),
      ('Cor', _car.color, Icons.palette_outlined),
      ('Motor', _car.engine, Icons.settings_outlined),
      ('Câmbio', _car.transmission, Icons.sync_alt_rounded),
      ('Combustível', _car.fuel, Icons.local_gas_station_outlined),
      ('Potência', _car.estimatedPower, Icons.speed_outlined),
      ('Preparação', _car.preparation, Icons.build_outlined),
      ('Suspensão', _car.suspensionType, Icons.airline_seat_recline_extra),
      (
        'Rodas',
        _car.wheelSize == null ? null : 'Aro ${_car.wheelSize}',
        Icons.tire_repair_outlined,
      ),
      ('Placa', _car.plate, Icons.badge_outlined),
    ].where((item) => item.$2 != null).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projeto'),
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
                    title: Text('Editar projeto'),
                  ),
                ),
                PopupMenuItem(
                  value: _CarAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Excluir projeto'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _deleting
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reloadProject,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                children: [
                _ProjectCover(
                  car: _car,
                  canManage: widget.canManage,
                  updatingPhoto: _updatingPhoto,
                  onPhotoTap: _openPhotoActions,
                ),
                const SizedBox(height: 16),
                _ProjectIdentity(
                  car: _car,
                  onOwnerTap: widget.onOwnerTap,
                ),
                const SizedBox(height: 28),
                const _SectionHeading(
                  eyebrow: 'A HISTÓRIA',
                  title: 'Sobre o projeto',
                  icon: Icons.auto_stories_outlined,
                ),
                const SizedBox(height: 12),
                _StoryCard(
                  text: _car.history ??
                      'O proprietário ainda não contou a história deste projeto.',
                ),
                const SizedBox(height: 28),
                _SectionHeading(
                  eyebrow: 'A MÁQUINA',
                  title: 'Ficha do carro',
                  icon: Icons.tune_rounded,
                  count: specs.length,
                ),
                const SizedBox(height: 12),
                if (specs.isEmpty)
                  const _EmptyProjectSection(
                    icon: Icons.tune_rounded,
                    message: 'A ficha técnica ainda não foi preenchida.',
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: specs.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.72,
                    ),
                    itemBuilder: (context, index) => _SpecTile(
                      label: specs[index].$1,
                      value: specs[index].$2!,
                      icon: specs[index].$3,
                    ),
                  ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    const Expanded(
                      child: _SectionHeading(
                        eyebrow: 'DIÁRIO DO PROJETO',
                        title: 'Evoluções',
                        icon: Icons.timeline_rounded,
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
                const SizedBox(height: 12),
                _evolutionTimeline(),
                ],
              ),
            ),
    );
  }
}

final class _ProjectCover extends StatelessWidget {
  const _ProjectCover({
    required this.car,
    required this.canManage,
    required this.updatingPhoto,
    required this.onPhotoTap,
  });

  final Car car;
  final bool canManage;
  final bool updatingPhoto;
  final VoidCallback onPhotoTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Material(
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        color: colors.surfaceContainerHighest,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (car.photoUrl == null)
              Icon(
                Icons.directions_car_rounded,
                size: 104,
                color: colors.onSurfaceVariant,
              )
            else
              Image.network(
                car.photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.broken_image_outlined,
                  size: 68,
                  color: colors.onSurfaceVariant,
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x22000000),
                    Color(0x00000000),
                    Color(0xB8000000),
                  ],
                  stops: [0, 0.52, 1],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      [car.model, car.year]
                          .where((value) => value != null)
                          .join(' '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                    ),
                  ),
                  if (canManage && !updatingPhoto) ...[
                    const SizedBox(width: 12),
                    IconButton.filled(
                      onPressed: onPhotoTap,
                      tooltip: 'Alterar foto principal',
                      icon: const Icon(Icons.add_a_photo_outlined),
                    ),
                  ],
                ],
              ),
            ),
            if (updatingPhoto)
              const ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

final class _ProjectIdentity extends StatelessWidget {
  const _ProjectIdentity({
    required this.car,
    this.onOwnerTap,
  });

  final Car car;
  final VoidCallback? onOwnerTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ownerInitial =
        car.ownerName.isEmpty ? '?' : car.ownerName[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(alpha: 0.82),
            colors.surfaceContainerHigh,
          ],
        ),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROJETO AUTOMOTIVO',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 7),
          Text(
            [car.model, car.year]
                .where((value) => value != null)
                .join(' '),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundImage: car.ownerAvatarUrl == null
                    ? null
                    : NetworkImage(car.ownerAvatarUrl!),
                child: car.ownerAvatarUrl == null
                    ? Text(
                        ownerInitial,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      )
                    : null,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: onOwnerTap,
                    borderRadius: BorderRadius.circular(9),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '@${car.ownerUsername}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    onOwnerTap == null ? null : colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (onOwnerTap != null) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.open_in_new, size: 15),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (car.projectStatus != null) ...[
                const SizedBox(width: 8),
                _ProjectStatus(label: car.projectStatus!),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

final class _ProjectStatus extends StatelessWidget {
  const _ProjectStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: colors.primary.withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

final class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.icon,
    this.count,
  });

  final String eyebrow;
  final String title;
  final IconData icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: colors.primary, size: 21),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.05,
                    ),
              ),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
        if (count != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}

final class _DiarySummary extends StatelessWidget {
  const _DiarySummary({
    required this.count,
    required this.latestDate,
    required this.mileage,
  });

  final int count;
  final String latestDate;
  final String? mileage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 16,
            children: [
              SizedBox(
                width: itemWidth,
                child: _DiaryStat(
                  icon: Icons.library_books_outlined,
                  label: 'Registros',
                  value: count == 1 ? '1 registro' : '$count registros',
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _DiaryStat(
                  icon: Icons.event_outlined,
                  label: 'Última evolução',
                  value: latestDate,
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _DiaryStat(
                  icon: Icons.speed_outlined,
                  label: 'Quilometragem',
                  value: mileage ?? 'Não informada',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _DiaryStat extends StatelessWidget {
  const _DiaryStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
      ),
    );
  }
}

final class _SpecTile extends StatelessWidget {
  const _SpecTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const Spacer(),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

final class _EmptyProjectSection extends StatelessWidget {
  const _EmptyProjectSection({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(icon, size: 30),
          const SizedBox(width: 14),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
