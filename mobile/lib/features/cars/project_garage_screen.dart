import 'package:flutter/services.dart';
import 'package:garona_mobile/features/cars/photo_crop_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:garona_mobile/core/network/api_client.dart';
import 'package:garona_mobile/core/widgets/garona_premium.dart';
import 'package:garona_mobile/features/cars/car.dart';
import 'package:garona_mobile/features/cars/cars_repository.dart';
import 'package:garona_mobile/features/cars/project_garage.dart';
import 'package:garona_mobile/features/evolutions/evolution.dart';
import 'package:garona_mobile/features/evolutions/evolution_detail_screen.dart';
import 'package:garona_mobile/features/evolutions/evolution_form_screen.dart';
import 'gallery_photo_flow.dart';
import 'package:garona_mobile/features/evolutions/evolutions_repository.dart';

class ProjectGarageScreen extends StatefulWidget {
  const ProjectGarageScreen(
      {required this.car,
      required this.repository,
      required this.evolutions,
      required this.canManage,
      required this.currentUserId,
      super.key});
  final Car car;
  final CarsRepository repository;
  final EvolutionsRepository evolutions;
  final bool canManage;
  final String currentUserId;
  @override
  State<ProjectGarageScreen> createState() => _ProjectGarageScreenState();
}

class _ProjectGarageScreenState extends State<ProjectGarageScreen> {
  ProjectGarage? _data;
  Object? _error;
  bool _busy = false;
  bool _organizing = false;
  bool _loading = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.garage(widget.car.id);
      if (mounted && request == _request) setState(() => _data = data);
    } catch (error) {
      if (mounted && request == _request) setState(() => _error = error);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _act(Future<void> Function() action, {String? message}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      await _load();
      if (mounted && message != null)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
          context: context,
          builder: (context) =>
              AlertDialog(title: Text(title), content: Text(body), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirmar')),
              ])) ??
      false;

  Future<void> _addPhoto() async {
    await _act(() async {
      final photo = await ImagePicker().pickImage(
          source: ImageSource.gallery, imageQuality: 90, maxWidth: 2048);
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<bool>(
          builder: (_) => GalleryPhotoPublishScreen(
              carId: widget.car.id,
              repository: widget.repository,
              bytes: bytes,
              fileName: photo.name)));
    });
  }

  void _view(ProjectPhoto photo) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => GalleryPhotoViewer(
              photos: _data!.photos,
              initialIndex: _data!.photos.indexOf(photo))));

  Future<void> _caption(ProjectPhoto photo) async {
    final controller = TextEditingController(text: photo.caption);
    final route = DialogRoute<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Legenda da foto'),
                content: TextField(
                    controller: controller, maxLength: 160, maxLines: 3),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('Salvar'))
                ]));
    final caption = await Navigator.of(context).push(route);
    await route.completed;
    controller.dispose();
    if (caption != null && mounted)
      await _act(() =>
          widget.repository.captionPhoto(widget.car.id, photo.id, caption));
  }

  Future<void> _move(int index, int direction) async {
    final ids = _data!.photos.map((e) => e.id).toList();
    final id = ids.removeAt(index);
    ids.insert(index + direction, id);
    await _act(() => widget.repository.orderPhotos(widget.car.id, ids));
  }

  Future<void> _editStage([ProjectStage? stage]) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ProjectStageForm(
            car: widget.car,
            repository: widget.repository,
            evolutions: widget.evolutions,
            stage: stage)));
    if (mounted) await _load();
  }

  Future<void> _openEvolution(ProjectStage stage) async {
    await _act(() async {
      final evolution =
          await widget.evolutions.detail(widget.car.id, stage.evolutionId!);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => EvolutionDetailScreen(
              evolution: evolution,
              repository: widget.evolutions,
              currentUserId: widget.currentUserId)));
    });
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 2,
      child: PopScope(
        canPop: !_busy,
        child: Scaffold(
            appBar: AppBar(
                title: Text(widget.car.displayName),
                bottom: const TabBar(
                    tabs: [Tab(text: 'Galeria'), Tab(text: 'Etapas')])),
            body: Column(children: [
              if (_busy || _loading) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Text(apiErrorMessage(_error!)),
                      TextButton(
                          onPressed: _busy ? null : _load,
                          child: const Text('Tentar novamente'))
                    ])),
              if (_data != null)
                Expanded(
                    child: AbsorbPointer(
                        absorbing: _busy || _loading,
                        child: TabBarView(children: [_gallery(), _stages()]))),
            ])),
      ));

  Widget _gallery() => RefreshIndicator(
      onRefresh: _load,
      child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text('O carro, do seu jeito',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
                '${_data!.photos.length} fotos${widget.canManage ? ' · limite de 12' : ''} · Toque para ampliar'),
            if (widget.canManage)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: OutlinedButton.icon(
                      onPressed: _data!.photos.length >= 12 ? null : _addPhoto,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Adicionar foto'))),
            if (_data!.photos.isEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(widget.canManage
                      ? 'Um detalhe, o interior, o carro na rua. Escolha as fotos que contam esse projeto.'
                      : 'O dono ainda não adicionou fotos à galeria.')),
            if (widget.canManage && _data!.photos.length > 1)
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _organizing = !_organizing),
                      icon: Icon(_organizing ? Icons.check : Icons.swap_vert),
                      label: Text(
                          _organizing ? 'Concluir organização' : 'Organizar'))),
            if (!widget.canManage) const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(14) > 22
                  ? 1
                  : 2;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                for (var i = 0; i < _data!.photos.length; i++)
                  SizedBox(
                      width:
                          (constraints.maxWidth - (columns - 1) * 12) / columns,
                      child: _photoCard(_data!.photos[i], i)),
              ]);
            }),
          ]));

  Widget _photoCard(ProjectPhoto photo, int index) => Padding(
      padding: EdgeInsets.zero,
      child: GaronaPanel(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                    aspectRatio: 1,
                    child: InkWell(
                        onTap: () => _view(photo),
                        child: Semantics(
                            label: 'Foto ${index + 1}. Toque para ampliar',
                            child: Image.network(photo.url,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Center(
                                    child:
                                        Icon(Icons.broken_image_outlined))))))),
            if (photo.caption.isNotEmpty || widget.canManage)
              Row(children: [
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(photo.caption,
                            maxLines: 2, overflow: TextOverflow.ellipsis))),
                if (widget.canManage)
                  PopupMenuButton<String>(
                      tooltip: 'Opções da foto',
                      onSelected: (action) async {
                        if (action == 'caption') await _caption(photo);
                        if (action == 'cover' &&
                            await _confirm('Usar como capa?',
                                'Esta foto será a apresentação do projeto.')) {
                          if (mounted)
                            await _act(() async {
                              final data =
                                  await NetworkAssetBundle(Uri.parse(photo.url))
                                      .load(photo.url);
                              if (!mounted) return;
                              final cropped = await Navigator.of(context)
                                  .push<Uint8List>(MaterialPageRoute(
                                      builder: (_) => PhotoCropScreen(
                                          image: data.buffer.asUint8List(),
                                          title: 'Capa do projeto',
                                          instructions:
                                              'Este recorte aparece no Descobrir e no projeto. A foto completa continua na galeria.')));
                              if (cropped == null || !mounted) return;
                              await widget.repository.uploadMainPhoto(
                                  widget.car.id,
                                  bytes: cropped,
                                  fileName: 'capa.jpg');
                            });
                        }
                        if (action == 'delete' &&
                            await _confirm('Remover foto?',
                                'A foto será removida da galeria. A capa atual será preservada.')) {
                          if (mounted)
                            await _act(() => widget.repository
                                .deleteGalleryPhoto(widget.car.id, photo.id));
                        }
                      },
                      itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'caption',
                                child: Text('Editar legenda')),
                            PopupMenuItem(
                                value: 'cover', child: Text('Usar como capa')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Remover foto'))
                          ]),
              ]),
            if (widget.canManage && _organizing)
              Wrap(children: [
                IconButton(
                    tooltip: 'Mover antes',
                    onPressed: index > 0 ? () => _move(index, -1) : null,
                    icon: const Icon(Icons.arrow_upward)),
                IconButton(
                    tooltip: 'Mover depois',
                    onPressed: index + 1 < _data!.photos.length
                        ? () => _move(index, 1)
                        : null,
                    icon: const Icon(Icons.arrow_downward)),
              ]),
          ])));

  Widget _stages() {
    final stages = _data!.stages;
    final completed = stages.where((e) => e.status == 'concluida').length;
    return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text('Uma coisa de cada vez',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(stages.isEmpty
                  ? 'O que vem pela frente e o que já saiu do papel.'
                  : '$completed de ${stages.length} etapas concluídas'),
              if (widget.canManage)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: OutlinedButton.icon(
                        onPressed:
                            stages.length >= 60 ? null : () => _editStage(),
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar etapa'))),
              if (stages.isEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(widget.canManage
                        ? 'Pode ser a revisão, as rodas ou a primeira viagem. Comece pelo próximo passo.'
                        : 'O dono ainda não adicionou etapas.')),
              for (final status in projectStageLabels.keys)
                if (stages.any((e) => e.status == status)) ...[
                  Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Text(
                          const {
                            'planejada': 'Planejadas',
                            'em_andamento': 'Em andamento',
                            'concluida': 'Concluídas'
                          }[status]!,
                          style: Theme.of(context).textTheme.titleMedium)),
                  for (final stage in stages.where((e) => e.status == status))
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GaronaPanel(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(
                                        child: Text(stage.title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium)),
                                    if (widget.canManage)
                                      PopupMenuButton<String>(
                                          tooltip: 'Opções da etapa',
                                          onSelected: (action) async {
                                            if (action == 'edit')
                                              await _editStage(stage);
                                            if (action == 'delete' &&
                                                await _confirm('Excluir etapa?',
                                                    'O registro de evolução vinculado será mantido.')) {
                                              if (mounted)
                                                await _act(() => widget
                                                    .repository
                                                    .deleteStage(widget.car.id,
                                                        stage.id));
                                            }
                                          },
                                          itemBuilder: (_) => const [
                                                PopupMenuItem(
                                                    value: 'edit',
                                                    child:
                                                        Text('Editar etapa')),
                                                PopupMenuItem(
                                                    value: 'delete',
                                                    child:
                                                        Text('Excluir etapa'))
                                              ]),
                                  ]),
                                  if (stage.description?.isNotEmpty == true)
                                    Text(stage.description!),
                                  if (stage.evolutionId != null)
                                    TextButton.icon(
                                        onPressed: () => _openEvolution(stage),
                                        icon: const Icon(Icons.north_east),
                                        label: const Text('Ver evolução')),
                                ]))),
                ],
            ]));
  }
}

class ProjectStageForm extends StatefulWidget {
  const ProjectStageForm(
      {required this.car,
      required this.repository,
      required this.evolutions,
      this.stage,
      super.key});
  final Car car;
  final CarsRepository repository;
  final EvolutionsRepository evolutions;
  final ProjectStage? stage;
  @override
  State<ProjectStageForm> createState() => _ProjectStageFormState();
}

class _ProjectStageFormState extends State<ProjectStageForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.stage?.title);
  late final _description =
      TextEditingController(text: widget.stage?.description);
  late String _status = widget.stage?.status ?? 'planejada';
  late String? _evolutionId = widget.stage?.evolutionId;
  List<Evolution>? _evolutions;
  bool _busy = false, _dirty = false, _allowPop = false;
  String? _error, _loadError;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.evolutions.byCar(widget.car.id);
      if (mounted)
        setState(() {
          _evolutions = items;
          if (_evolutionId != null && !items.any((e) => e.id == _evolutionId)) {
            _evolutionId = null;
          }
          _loadError = null;
        });
    } catch (e) {
      if (mounted) setState(() => _loadError = apiErrorMessage(e));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.saveStage(widget.car.id,
          id: widget.stage?.id,
          title: _title.text.trim(),
          description: _description.text.trim(),
          status: _status,
          evolutionId: _evolutionId);
      if (mounted) {
        setState(() {
          _allowPop = true;
          _busy = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = apiErrorMessage(e);
          _busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: _allowPop || (!_dirty && !_busy),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _busy) return;
        final discard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Descartar alterações?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Continuar editando')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Descartar'))
                    ]));
        if (discard == true && mounted) {
          setState(() => _allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
            title: Text(widget.stage == null ? 'Nova etapa' : 'Editar etapa')),
        body: AbsorbPointer(
            absorbing: _busy,
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                    key: _form,
                    onChanged: () {
                      if (!_dirty) setState(() => _dirty = true);
                    },
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                              controller: _title,
                              maxLength: 100,
                              decoration: const InputDecoration(
                                  labelText: 'O próximo passo',
                                  hintText: 'Ex.: Revisar o arrefecimento'),
                              validator: (v) => v?.trim().isEmpty != false
                                  ? 'Informe o título.'
                                  : null),
                          const SizedBox(height: 16),
                          TextFormField(
                              controller: _description,
                              maxLength: 2000,
                              minLines: 2,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                  labelText: 'Detalhes (opcional)',
                                  hintText:
                                      'Ex.: Conferir radiador, mangueiras e bomba d’água.')),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                              initialValue: _status,
                              decoration:
                                  const InputDecoration(labelText: 'Situação'),
                              items: projectStageLabels.entries
                                  .map((e) => DropdownMenuItem(
                                      value: e.key, child: Text(e.value)))
                                  .toList(),
                              onChanged: (v) => setState(() {
                                    _status = v!;
                                    _dirty = true;
                                    if (v != 'concluida') _evolutionId = null;
                                  })),
                          if (_status == 'concluida') ...[
                            const SizedBox(height: 24),
                            const Text('Registro da conclusão (opcional)'),
                            const SizedBox(height: 8),
                            if (_loadError != null) ...[
                              Text(_loadError!),
                              TextButton(
                                  onPressed: _load,
                                  child: const Text('Recarregar evoluções'))
                            ] else if (_evolutions == null)
                              const LinearProgressIndicator()
                            else
                              DropdownButtonFormField<String>(
                                  key: ValueKey(_evolutionId),
                                  isExpanded: true,
                                  initialValue: _evolutions!
                                          .any((e) => e.id == _evolutionId)
                                      ? _evolutionId
                                      : null,
                                  decoration: const InputDecoration(
                                      labelText:
                                          'Vincular evolução (opcional)'),
                                  items: [
                                    const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text('Sem vínculo')),
                                    ..._evolutions!.map((e) => DropdownMenuItem(
                                        value: e.id,
                                        child: Text(e.title,
                                            overflow: TextOverflow.ellipsis)))
                                  ],
                                  onChanged: (v) => setState(() {
                                        _evolutionId = v;
                                        _dirty = true;
                                      })),
                            TextButton.icon(
                                onPressed: () async {
                                  final evolution = await Navigator.of(context)
                                      .push<Evolution>(MaterialPageRoute(
                                          builder: (_) => EvolutionFormScreen(
                                              carId: widget.car.id,
                                              carModel: widget.car.model,
                                              repository: widget.evolutions)));
                                  if (evolution != null && mounted) {
                                    setState(() {
                                      _evolutionId = evolution.id;
                                      _dirty = true;
                                    });
                                    await _load();
                                  }
                                },
                                icon: const Icon(Icons.add),
                                label: const Text(
                                    'Registrar conclusão no diário')),
                            const Text(
                                'Escolha uma evolução deste carro ou publique uma nova. Salve a etapa para criar o vínculo. Reabrir ou excluir a etapa preserva a evolução no diário.'),
                          ],
                          if (_error != null)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Text(_error!)),
                          const SizedBox(height: 24),
                          FilledButton(
                              onPressed: _busy ? null : _save,
                              child:
                                  Text(_busy ? 'Salvando…' : 'Salvar etapa')),
                        ])))),
      ));
}
