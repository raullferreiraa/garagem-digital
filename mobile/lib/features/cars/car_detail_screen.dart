import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/widgets/gd_premium.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/sharing/gd_share.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_form_screen.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/cars/photo_crop_screen.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';
import 'package:garagem_mobile/features/evolutions/evolution_carousel.dart';
import 'package:garagem_mobile/features/evolutions/evolution_journal_card.dart';
import 'package:garagem_mobile/features/evolutions/evolution_detail_screen.dart';
import 'package:garagem_mobile/features/evolutions/evolution_form_screen.dart';
import 'package:garagem_mobile/features/evolutions/evolution_photos_screen.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/sharing/share_content.dart';
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
          return const SizedBox(height: 180, child: GdSkeleton(compact: true));
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
          GdShareAction(
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final singleColumn = constraints.maxWidth < 300 ||
                            MediaQuery.textScalerOf(context).scale(14) > 20;
                        final width = singleColumn
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 10) / 2;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final spec in specs)
                              SizedBox(
                                width: width,
                                child: _SpecTile(
                                  label: spec.$1,
                                  value: spec.$2!,
                                  icon: spec.$3,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      const Expanded(
                        child: GdSectionTitle(
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
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Material(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        color: colors.surfaceContainerHighest,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GdImage(url: car.photoUrl, semanticLabel: car.model),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x22000000),
                    Color(0x00000000),
                    Color(0xEB090C10),
                  ],
                  stops: [0, 0.52, 1],
                ),
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
            if (car.photoUrl != null)
              Positioned(
                top: 12,
                right: 12,
                child: IconButton.filledTonal(
                  onPressed: onViewPhoto,
                  tooltip: 'Ver foto inteira',
                  icon: const Icon(Icons.zoom_out_map_rounded),
                ),
              ),
            Positioned(
              top: 18,
              left: 18,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PROJETO AUTOMOTIVO',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
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
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onOwnerTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                GdAvatar(
                    url: car.ownerAvatarUrl, name: car.ownerName, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NA GARAGEM DE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: colors.outlineVariant),
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
    return GdSectionTitle(
      title: title,
      eyebrow: eyebrow,
      trailing: count == null
          ? Icon(icon, color: colors.primary, size: 21)
          : Text(
              count.toString().padLeft(2, '0'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
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
  Widget build(BuildContext context) => GdPanel(
      child: Text(text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6)));
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
    final theme = Theme.of(context);
    return GdPanel(
      padding: const EdgeInsets.all(14),
      radius: 12,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: .8))),
          const SizedBox(width: 8),
          Icon(icon, size: 18, color: theme.colorScheme.primary),
        ]),
        const SizedBox(height: 12),
        Text(value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 22)),
      ]),
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
