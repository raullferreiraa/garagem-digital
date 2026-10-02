import 'package:garona_mobile/features/cars/project_garage_screen.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:garona_mobile/core/widgets/garona_premium.dart';
import 'package:garona_mobile/core/network/api_client.dart';
import 'package:garona_mobile/core/sharing/garona_share.dart';
import 'package:garona_mobile/core/widgets/garona_ui.dart';
import 'package:garona_mobile/features/cars/car.dart';
import 'package:garona_mobile/features/cars/car_form_screen.dart';
import 'package:garona_mobile/features/cars/cars_repository.dart';
import 'package:garona_mobile/features/cars/photo_crop_screen.dart';
import 'package:garona_mobile/features/evolutions/evolution.dart';
import 'package:garona_mobile/features/evolutions/evolution_carousel.dart';
import 'package:garona_mobile/features/evolutions/evolution_journal_card.dart';
import 'package:garona_mobile/features/evolutions/evolution_detail_screen.dart';
import 'package:garona_mobile/features/evolutions/evolution_form_screen.dart';
import 'package:garona_mobile/features/evolutions/evolution_photos_screen.dart';
import 'package:garona_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garona_mobile/features/sharing/share_content.dart';
import 'package:image_picker/image_picker.dart';

enum _CarAction { edit, delete }

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
  bool get _canManage => widget.currentUserId.isNotEmpty
      ? _car.ownerId == widget.currentUserId
      : widget.canManage;

  Future<Car> _loadCarDetail() => _canManage && widget.currentUserId.isNotEmpty
      ? widget.repository.myDetail(_car.id)
      : widget.repository.detail(_car.id);
  late Future<List<Evolution>> _evolutions;
  int _carRequest = 0;
  bool _deleting = false;
  bool _updatingPhoto = false;
  bool? _saved;
  bool _changingSaved = false;

  @override
  void initState() {
    super.initState();
    _evolutions = widget.evolutionsRepository.byCar(_car.id);
    unawaited(_refreshCarSilently());
    if (!_canManage && widget.currentUserId.isNotEmpty) {
      unawaited(_loadSaved());
    }
  }

  Future<void> _loadSaved() async {
    try {
      final saved = await widget.repository.isSaved(_car.id);
      if (mounted) setState(() => _saved = saved);
    } catch (_) {
      // O projeto continua acessível mesmo se o estado de salvos falhar.
    }
  }

  Future<void> _toggleSaved() async {
    if (_changingSaved || _saved == null) return;
    final next = !_saved!;
    setState(() => _changingSaved = true);
    try {
      await widget.repository.setSaved(_car.id, saved: next);
      if (!mounted) return;
      setState(() => _saved = next);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(next ? 'Projeto salvo.' : 'Projeto removido dos salvos.'),
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _changingSaved = false);
    }
  }

  Future<void> _refreshCarSilently() async {
    final request = ++_carRequest;
    try {
      final refreshed = await _loadCarDetail();
      if (!mounted || request != _carRequest) return;
      setState(() {
        _car = _canManage && widget.currentUserId.isEmpty
            ? refreshed.withPrivateDataFrom(_car)
            : refreshed;
      });
    } catch (_) {
      // O card recebido mantém a tela utilizável quando a atualização falha.
    }
  }

  void _viewPhoto() {
    final url = _car.photoUrl;
    if (url == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ProjectPhotoViewer(url: url, title: _car.model),
      ),
    );
  }

  Future<void> _reloadProject() async {
    final request = ++_carRequest;
    final carRequest = _loadCarDetail();
    final evolutionsRequest = widget.evolutionsRepository.byCar(_car.id);
    setState(() {
      _evolutions = evolutionsRequest;
    });

    Object? failure;
    try {
      final refreshed = await carRequest;
      if (mounted && request == _carRequest) {
        setState(() {
          _car = _canManage && widget.currentUserId.isEmpty
              ? refreshed.withPrivateDataFrom(_car)
              : refreshed;
        });
      }
    } catch (error) {
      if (request == _carRequest) failure = error;
    }

    try {
      await evolutionsRequest;
    } catch (error) {
      failure ??= error;
    }

    if (failure != null && mounted && request == _carRequest) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(failure))),
      );
    }
  }

  Future<void> _edit() async {
    Car editableCar;
    try {
      editableCar = _canManage && widget.currentUserId.isNotEmpty
          ? await widget.repository.myDetail(_car.id)
          : _car;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
      return;
    }
    if (!mounted) return;
    final updated = await Navigator.of(context).push<Car>(
      MaterialPageRoute(
        builder: (_) => CarFormScreen(
          repository: widget.repository,
          car: editableCar,
        ),
      ),
    );
    if (updated != null && mounted) {
      _carRequest++;
      setState(() => _car = updated);
    }
  }

  Future<void> _openGarage() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ProjectGarageScreen(
            car: _car,
            repository: widget.repository,
            evolutions: widget.evolutionsRepository,
            canManage: _canManage,
            currentUserId: widget.currentUserId)));
    if (mounted) await _reloadProject();
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

      _carRequest++;
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

    _carRequest++;
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
    EvolutionJournalAction action,
    Evolution evolution,
  ) {
    switch (action) {
      case EvolutionJournalAction.edit:
        _editEvolution(evolution);
        break;
      case EvolutionJournalAction.photos:
        _openEvolutionPhotos(evolution);
        break;
      case EvolutionJournalAction.delete:
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
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(
              height: 180, child: GaronaSkeleton(compact: true));
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

        final evolutions = [...?snapshot.data]
          ..sort((a, b) => b.timelineDate.compareTo(a.timelineDate));
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
            EvolutionCarousel(
              evolutions: evolutions,
              onOpen: _openEvolutionDetail,
              onManage: _canManage ? _selectEvolutionAction : null,
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
          if (!_canManage && widget.currentUserId.isNotEmpty)
            IconButton(
              onPressed: _saved == null || _changingSaved ? null : _toggleSaved,
              tooltip: _saved == true ? 'Remover dos salvos' : 'Salvar projeto',
              icon: Icon(_saved == true
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded),
            ),
          GaronaShareAction(
            payload: ShareContent.project(_car),
            tooltip: 'Compartilhar projeto',
          ),
          if (_canManage)
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                children: [
                  _ProjectCover(
                    car: _car,
                    canManage: _canManage,
                    updatingPhoto: _updatingPhoto,
                    onPhotoTap: _openPhotoActions,
                    onViewPhoto: _viewPhoto,
                  ),
                  const SizedBox(height: 16),
                  _ProjectIdentity(
                    car: _car,
                    onOwnerTap: widget.onOwnerTap,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                      onPressed: _openGarage,
                      icon: const Icon(Icons.collections_outlined),
                      label: const Text('Galeria e etapas')),
                  const SizedBox(height: 16),
                  if ([_car.history, _car.acquiredOn, _car.initialCondition]
                      .any((value) => value?.trim().isNotEmpty ?? false))
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Sobre o projeto'),
                      subtitle: const Text('História e origem'),
                      children: [
                        if (_car.acquiredOn != null)
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Comigo desde'),
                              subtitle: Text(_car.acquiredOn!
                                  .split('-')
                                  .reversed
                                  .join('/'))),
                        if (_car.history?.trim().isNotEmpty ?? false)
                          _StoryCard(text: _car.history!),
                        if (_car.initialCondition != null)
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Como chegou'),
                              subtitle: Text(_car.initialCondition!)),
                      ],
                    ),
                  if (specs.isNotEmpty ||
                      _car.originalSpec != null ||
                      _car.modifications != null)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Ficha do carro'),
                      subtitle: const Text(
                          'Configuração atual, original e modificações'),
                      children: [
                        for (final spec in specs)
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(spec.$3),
                              title: Text(spec.$1),
                              subtitle: Text(spec.$2!)),
                        if (_car.originalSpec != null)
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Configuração original'),
                              subtitle: Text(_car.originalSpec!)),
                        if (_car.modifications != null)
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Modificações realizadas'),
                              subtitle: Text(_car.modifications!)),
                      ],
                    ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      const Expanded(
                        child: GaronaSectionTitle(
                          eyebrow: 'DIÁRIO DO PROJETO',
                          title: 'Evoluções',
                        ),
                      ),
                      if (_canManage)
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
    required this.onViewPhoto,
  });

  final Car car;
  final bool canManage;
  final bool updatingPhoto;
  final VoidCallback onPhotoTap;
  final VoidCallback onViewPhoto;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 4),
            child: Row(
              children: [
                const GaronaLightSignature(width: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('GARONA / PROJETO',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.6,
                        color: colors.onSurfaceVariant,
                      )),
                ),
                if (car.photoUrl != null)
                  IconButton(
                    onPressed: onViewPhoto,
                    tooltip: 'Ver foto inteira',
                    icon: const Icon(Icons.zoom_out_map_rounded, size: 20),
                  ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: colors.surfaceContainerLowest,
                  child: GaronaImage(
                    url: car.photoUrl,
                    semanticLabel: car.model,
                    fit: BoxFit.contain,
                  ),
                ),
                if (car.photoUrl != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onViewPhoto,
                      child: const SizedBox.expand(),
                    ),
                  ),
                if (updatingPhoto)
                  ColoredBox(
                    color: colors.scrim.withValues(alpha: .4),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(car.displayName,
                            style: theme.textTheme.headlineLarge?.copyWith(
                                fontFamily: 'BarlowCondensed',
                                fontWeight: FontWeight.w700,
                                fontSize: 34,
                                height: 1.05)),
                        if (car.projectName != null || car.year != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                  [
                                    if (car.projectName != null) car.model,
                                    if (car.year != null) '${car.year}'
                                  ].join(' · '),
                                  style: theme.textTheme.labelLarge
                                      ?.copyWith(color: colors.secondary))),
                      ])),
                  if (canManage && !updatingPhoto) ...[
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                        onPressed: onPhotoTap,
                        tooltip: 'Alterar foto principal',
                        icon: const Icon(Icons.add_a_photo_outlined)),
                  ],
                ]),
                if (car.proposal != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(car.proposal!)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _ProjectPhotoViewer extends StatelessWidget {
  const _ProjectPhotoViewer({required this.url, required this.title});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white,
              size: 64,
            ),
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOwnerTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  GaronaAvatar(
                      url: car.ownerAvatarUrl, name: car.ownerName, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NA GARAGEM DE',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    letterSpacing: 1.1,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@${car.ownerUsername}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                  if (onOwnerTap != null)
                    Icon(Icons.arrow_outward_rounded,
                        size: 19, color: colors.primary),
                ],
              ),
            ),
          ),
          if (car.projectStatus != null) ...[
            const SizedBox(height: 10),
            _ProjectStatus(label: car.projectStatus!),
          ],
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
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: .22)),
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

final class _DiarySummary extends StatelessWidget {
  const _DiarySummary(
      {required this.count, required this.latestDate, required this.mileage});
  final int count;
  final String latestDate;
  final String? mileage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(count == 1 ? '1 registro' : '$count registros',
              style: theme.textTheme.labelLarge),
          Text('Última atualização: $latestDate',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (mileage != null)
            Text(mileage!, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

final class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            height: 1.6,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ));
}
