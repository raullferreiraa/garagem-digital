import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:garagem_mobile/core/config/app_config.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/events/event.dart';
import 'package:garagem_mobile/features/events/event_form_screen.dart';
import 'package:garagem_mobile/features/events/events_repository.dart';
import 'package:garagem_mobile/features/teams/team.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen(
      {required this.repository,
      required this.teamsRepository,
      required this.refreshRevision,
      super.key});
  final EventsRepository repository;
  final TeamsRepository teamsRepository;
  final int refreshRevision;
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<GarageEvent>? _events;
  Object? _error;
  bool _loading = false;
  int _revision = 0;
  String _filter = 'Todos';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant EventsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshRevision != widget.refreshRevision) _reload();
  }

  Future<void> _reload() async {
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await widget.repository.list();
      if (mounted && revision == _revision) setState(() => _events = events);
    } catch (error) {
      if (mounted && revision == _revision) setState(() => _error = error);
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    Team? team;
    try {
      for (final candidate in await widget.teamsRepository.list()) {
        if (const {'dono', 'administrador', 'moderador'}
            .contains(candidate.myRole)) {
          team = candidate;
          break;
        }
      }
    } catch (_) {/* O perfil pode organizar sem equipe. */}
    if (!mounted) return;
    final created = await Navigator.of(context).push<GarageEvent>(
        MaterialPageRoute(
            builder: (_) =>
                EventFormScreen(repository: widget.repository, team: team)));
    if (!mounted || created == null) return;
    setState(() => _events = [created, ...?_events]);
    await _reload();
  }

  Future<void> _open(GarageEvent event) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) =>
            EventCommunityScreen(event: event, repository: widget.repository)));
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final events = (_events ?? []).where((event) {
      final matchesFilter = _filter == 'Todos' ||
          (_filter == 'Seguindo' && event.following) ||
          (_filter == 'Organizo' && event.canManage);
      return matchesFilter &&
          '${event.name} ${event.city ?? ''} ${event.state ?? ''}'
              .toLowerCase()
              .contains(_search.toLowerCase().trim());
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Encontros'), actions: [
        IconButton(
            onPressed: _create,
            tooltip: 'Criar encontro',
            icon: const Icon(Icons.add_circle_outline)),
      ]),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                  child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Eyebrow('CULTURA QUE CONECTA'),
                      const SizedBox(height: 10),
                      Text('O seu próximo\nponto de encontro.',
                          style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 10),
                      Text('Conheça a comunidade. Faça parte da história.',
                          style: TextStyle(color: colors.onSurfaceVariant)),
                      const SizedBox(height: 24),
                      TextField(
                          onChanged: (value) => setState(() => _search = value),
                          decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Buscar encontro ou cidade')),
                      const SizedBox(height: 14),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final filter in ['Todos', 'Seguindo', 'Organizo'])
                          ChoiceChip(
                              label: Text(filter),
                              selected: _filter == filter,
                              onSelected: (_) =>
                                  setState(() => _filter = filter)),
                      ]),
                      if (_loading && _events != null) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator()
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(apiErrorMessage(_error!),
                            style: TextStyle(color: colors.error)),
                        TextButton(
                            onPressed: _reload,
                            child: const Text('Tentar novamente')),
                      ],
                    ]),
              )),
              if (_events == null && _loading)
                const SliverFillRemaining(child: GdSkeleton())
              else if (events.isEmpty)
                SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.flag_outlined,
                                size: 48, color: colors.primary),
                            const SizedBox(height: 16),
                            Text(
                                _filter == 'Seguindo'
                                    ? 'Sua próxima conexão começa aqui.'
                                    : 'Encontre pessoas que compartilham sua paixão.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 12),
                            Text(
                                _filter == 'Seguindo'
                                    ? 'Siga um encontro para acompanhar sua comunidade.'
                                    : 'Explore outra busca ou crie o seu encontro.',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 18),
                            OutlinedButton.icon(
                                onPressed: _create,
                                icon: const Icon(Icons.add),
                                label: const Text('Criar encontro')),
                          ]),
                    ))
              else
                SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList.separated(
                        itemCount: events.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 22),
                        itemBuilder: (_, index) => _CommunityCard(
                            event: events[index],
                            onTap: () => _open(events[index])))),
            ]),
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({required this.event, required this.onTap});
  final GarageEvent event;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GdReveal(
          child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CommunityCover(event: event, compact: true),
                  Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                event.description ??
                                    'Pessoas, projetos e histórias que se encontram.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 16),
                            Wrap(spacing: 16, runSpacing: 8, children: [
                              _Metric(Icons.people_outline,
                                  '${event.followersCount} seguidores'),
                              _Metric(Icons.flag_outlined,
                                  '${event.editions.length} edições'),
                              if (event.following)
                                const _Metric(Icons.check, 'Seguindo'),
                            ]),
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 14),
                            Row(children: [
                              Expanded(
                                  child: Text(
                                      event.startsAt == null
                                          ? 'A comunidade continua. Nova data em breve.'
                                          : 'Próxima edição · ${_date(event.startsAt!)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge)),
                              const Icon(Icons.north_east),
                            ]),
                          ])),
                ])),
      ));
}

class _CommunityCover extends StatelessWidget {
  const _CommunityCover({required this.event, this.compact = false});
  final GarageEvent event;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(children: [
      Positioned.fill(
          child: event.coverUrl == null
              ? ColoredBox(
                  color: colors.surfaceContainerHighest,
                  child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Icon(Icons.sports_motorsports_outlined,
                              size: 110,
                              color: colors.primary.withValues(alpha: .15)))))
              : GdImage(
                  url: AppConfig.resolveApiUrl(event.coverUrl),
                  semanticLabel: 'Capa de ${event.name}')),
      Positioned.fill(
          child: DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
            Colors.black.withValues(alpha: .12),
            Colors.black.withValues(alpha: .85)
          ])))),
      Padding(
          padding: EdgeInsets.fromLTRB(22, compact ? 38 : 70, 22, 22),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                event.visibility == 'somente_equipe'
                    ? 'EXCLUSIVO DA EQUIPE'
                    : 'ENCONTRO • COMUNIDADE',
                style: const TextStyle(
                    color: Colors.white,
                    letterSpacing: 2,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
            SizedBox(height: compact ? 30 : 46),
            Container(width: 30, height: 3, color: colors.primary),
            const SizedBox(height: 10),
            Text(event.name,
                style: (compact
                        ? Theme.of(context).textTheme.headlineLarge
                        : Theme.of(context).textTheme.displaySmall)
                    ?.copyWith(color: Colors.white)),
            const SizedBox(height: 10),
            Text(
                [event.city, event.state]
                    .whereType<String>()
                    .where((s) => s.isNotEmpty)
                    .join(' · '),
                style: const TextStyle(color: Colors.white70)),
          ])),
    ]);
  }
}

class EventCommunityScreen extends StatefulWidget {
  const EventCommunityScreen(
      {required this.event, required this.repository, super.key});
  final GarageEvent event;
  final EventsRepository repository;
  @override
  State<EventCommunityScreen> createState() => _EventCommunityScreenState();
}

class _EventCommunityScreenState extends State<EventCommunityScreen> {
  late GarageEvent _event = widget.event;
  bool _working = false;
  Object? _error;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final revision = ++_revision;
    try {
      final result = await widget.repository.detail(_event.id);
      if (mounted && revision == _revision)
        setState(() {
          _event = result;
          _error = null;
        });
    } catch (error) {
      if (mounted && revision == _revision) setState(() => _error = error);
    }
  }

  Future<void> _change(Future<GarageEvent> Function() action) async {
    if (_working) return;
    ++_revision;
    setState(() => _working = true);
    try {
      final updated = await action();
      if (mounted)
        setState(() {
          _event = updated;
          _error = null;
        });
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _edit() async {
    final result = await Navigator.of(context).push<GarageEvent>(
        MaterialPageRoute(
            builder: (_) =>
                EventFormScreen(repository: widget.repository, event: _event)));
    if (mounted && result != null) {
      ++_revision;
      setState(() => _event = result);
    }
  }

  Future<void> _cover() async {
    try {
      final photo = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 2048, imageQuality: 90);
      if (photo == null || !mounted) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      await _change(
          () => widget.repository.uploadCover(_event.id, bytes, photo.name));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    }
  }

  Future<void> _schedule([EventEdition? edition]) async {
    final result = await Navigator.of(context).push<GarageEvent>(
        MaterialPageRoute(
            builder: (_) => _EditionForm(
                event: _event,
                repository: widget.repository,
                edition: edition)));
    if (mounted && result != null) {
      ++_revision;
      setState(() => _event = result);
    }
  }

  Future<void> _cancelEdition(EventEdition edition) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar esta edição?'),
        content: const Text(
            'Ela continuará no histórico como cancelada. As confirmações não serão transferidas para outra data.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Voltar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancelar edição')),
        ],
      ),
    );
    if (confirmed == true) {
      await _change(
          () => widget.repository.cancelEdition(_event.id, edition.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final past = _event.editions
        .where((e) =>
            e.startsAt.isBefore(DateTime.now()) || e.status == 'cancelada')
        .toList();
    final upcoming = _event.editions
        .where((e) =>
            e.status == 'agendada' &&
            !e.startsAt.isBefore(DateTime.now()) &&
            e.id != _event.editionId)
        .toList()
        .reversed;
    final currentEdition = _event.editions
        .where((edition) => edition.id == _event.editionId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Encontro'), actions: [
        if (_event.canManage)
          PopupMenuButton<String>(
              enabled: !_working,
              tooltip: 'Gerenciar encontro',
              onSelected: (value) {
                if (value == 'edit') _edit();
                if (value == 'cover') _cover();
                if (value == 'edition') _schedule();
              },
              itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'edit', child: Text('Editar comunidade')),
                    PopupMenuItem(value: 'cover', child: Text('Alterar capa')),
                    PopupMenuItem(
                        value: 'edition', child: Text('Agendar edição')),
                  ]),
      ]),
      body: RefreshIndicator(
          onRefresh: _working ? () async {} : _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _CommunityCover(event: _event),
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_working) const LinearProgressIndicator(),
                        if (_error != null) ...[
                          Text(apiErrorMessage(_error!),
                              style: TextStyle(color: colors.error)),
                          TextButton(
                              onPressed: _refresh,
                              child: const Text('Atualizar comunidade')),
                        ],
                        Wrap(spacing: 20, runSpacing: 12, children: [
                          _Metric(Icons.people_outline,
                              '${_event.followersCount} seguidores'),
                          _Metric(Icons.flag_outlined,
                              '${_event.editions.length} edições'),
                        ]),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                            onPressed: _working
                                ? null
                                : () => _change(() => widget.repository
                                    .setFollowing(_event.id,
                                        following: !_event.following)),
                            icon: Icon(
                                _event.following ? Icons.check : Icons.add),
                            label: Text(_event.following
                                ? 'Seguindo encontro'
                                : 'Fazer parte • Seguir encontro')),
                        const SizedBox(height: 28),
                        const _Eyebrow('NOSSA HISTÓRIA'),
                        const SizedBox(height: 8),
                        Text(
                            _event.description ??
                                'Cada edição é uma oportunidade para conhecer projetos e construir novas histórias.',
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 16),
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.verified_outlined),
                            title: Text(_event.organizerName),
                            subtitle: Text(_event.organizerType == 'equipe'
                                ? 'Equipe organizadora'
                                : 'Organização')),
                        const SizedBox(height: 24),
                        Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const _Eyebrow('PRÓXIMA EDIÇÃO'),
                                      const SizedBox(height: 12),
                                      Text(
                                          _event.startsAt == null
                                              ? 'Novas histórias em breve'
                                              : _date(_event.startsAt!),
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium),
                                      const SizedBox(height: 8),
                                      Text(_event.startsAt == null
                                          ? 'Siga a comunidade e volte para conferir a próxima data.'
                                          : '${_time(_event.startsAt!)} · ${_event.location}'),
                                      if (_event.startsAt != null) ...[
                                        const SizedBox(height: 18),
                                        Wrap(
                                            spacing: 16,
                                            runSpacing: 8,
                                            children: [
                                              _Metric(Icons.people_outline,
                                                  '${_event.confirmedCount} confirmados'),
                                              _Metric(Icons.groups_outlined,
                                                  '${_event.teamCount} equipes'),
                                            ]),
                                        const SizedBox(height: 18),
                                        FilledButton.icon(
                                            onPressed: _working
                                                ? null
                                                : () => _change(() => widget
                                                    .repository
                                                    .setPresence(_event.id,
                                                        editionId:
                                                            _event.editionId!,
                                                        confirmed:
                                                            _event.myPresence !=
                                                                'confirmada')),
                                            icon: Icon(_event.myPresence ==
                                                    'confirmada'
                                                ? Icons.check_circle
                                                : Icons.how_to_reg_outlined),
                                            label: Text(_event.myPresence ==
                                                    'confirmada'
                                                ? 'Presença confirmada • Cancelar'
                                                : 'Confirmar minha presença')),
                                        if (_event.canRepresentTeam &&
                                            !(_event.organizerType == 'equipe' &&
                                                _event.organizerId ==
                                                    _event.myTeamId))
                                          OutlinedButton.icon(
                                              onPressed: _working
                                                  ? null
                                                  : () => _change(() => widget
                                                      .repository
                                                      .setTeamParticipation(
                                                          _event.id,
                                                          editionId:
                                                              _event.editionId!,
                                                          confirmed: _event
                                                                  .myTeamParticipation !=
                                                              'confirmada')),
                                              icon:
                                                  const Icon(Icons.groups_outlined),
                                              label: Text(_event.myTeamParticipation == 'confirmada' ? 'Retirar participação da equipe' : 'Levar ${_event.myTeamName}')),
                                        if (_event.canManage &&
                                            currentEdition != null) ...[
                                          const SizedBox(height: 8),
                                          Row(children: [
                                            Expanded(
                                                child: OutlinedButton.icon(
                                                    onPressed: _working
                                                        ? null
                                                        : () => _schedule(
                                                            currentEdition),
                                                    icon: const Icon(Icons
                                                        .edit_calendar_outlined),
                                                    label: const Text(
                                                        'Editar edição'))),
                                            const SizedBox(width: 8),
                                            IconButton.outlined(
                                                tooltip: 'Cancelar edição',
                                                onPressed: _working
                                                    ? null
                                                    : () => _cancelEdition(
                                                        currentEdition),
                                                icon: const Icon(
                                                    Icons.event_busy_outlined)),
                                          ]),
                                        ],
                                      ],
                                      if (_event.canManage) ...[
                                        const SizedBox(height: 12),
                                        OutlinedButton.icon(
                                            onPressed:
                                                _working ? null : _schedule,
                                            icon: const Icon(Icons.add),
                                            label: const Text(
                                                'Agendar nova edição')),
                                      ],
                                    ]))),
                        if (upcoming.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          const _Eyebrow('JÁ NO HORIZONTE'),
                          ...upcoming.map((e) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.event_outlined),
                              title: Text(_date(e.startsAt)),
                              subtitle: Text(e.location(
                                  fallbackCity: _event.city,
                                  fallbackState: _event.state)),
                              trailing: _event.canManage
                                  ? PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') _schedule(e);
                                        if (value == 'cancel') {
                                          _cancelEdition(e);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                            PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Editar edição')),
                                            PopupMenuItem(
                                                value: 'cancel',
                                                child: Text('Cancelar edição')),
                                          ])
                                  : null)),
                        ],
                        const SizedBox(height: 28),
                        const _Eyebrow('HISTÓRIAS QUE JÁ VIVEMOS'),
                        const SizedBox(height: 8),
                        Text('Edições anteriores',
                            style: Theme.of(context).textTheme.headlineSmall),
                        if (past.isEmpty)
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                  'A primeira história ainda está por vir. As edições realizadas ficarão aqui.'))
                        else
                          ...past.map((e) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(e.status == 'cancelada'
                                  ? Icons.event_busy_outlined
                                  : Icons.flag_outlined),
                              title: Text(_date(e.startsAt)),
                              subtitle: Text(
                                  '${e.status == 'cancelada' ? 'Edição cancelada' : e.location(fallbackCity: _event.city, fallbackState: _event.state)} · ${e.confirmedCount} confirmações'))),
                      ])),
            ],
          )),
    );
  }
}

class _EditionForm extends StatefulWidget {
  const _EditionForm(
      {required this.event, required this.repository, this.edition});
  final GarageEvent event;
  final EventsRepository repository;
  final EventEdition? edition;
  @override
  State<_EditionForm> createState() => _EditionFormState();
}

class _EditionFormState extends State<_EditionForm> {
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  late DateTime _dateValue;
  bool _useCommunityRegion = true;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final edition = widget.edition;
    _dateValue = edition?.startsAt.toLocal() ??
        DateTime.now().add(const Duration(days: 7));
    _address.text = edition?.address ?? '';
    final hasBaseRegion = (widget.event.city?.isNotEmpty ?? false) &&
        (widget.event.state?.isNotEmpty ?? false);
    _useCommunityRegion = hasBaseRegion;
    if (edition != null) {
      final usesBase = hasBaseRegion &&
          edition.city == widget.event.city &&
          edition.state == widget.event.state;
      _useCommunityRegion = usesBase;
      if (!usesBase) {
        _city.text = edition.city ?? '';
        _state.text = edition.state ?? '';
      }
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _city.dispose();
    _state.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final date = await showDatePicker(
        context: context,
        initialDate: _dateValue,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 1095)));
    if (!mounted || date == null) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_dateValue));
    if (!mounted || time == null) return;
    setState(() => _dateValue =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    if (!_useCommunityRegion &&
        (_city.text.trim().isEmpty || _state.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Informe a cidade e o estado desta edição.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final edition = widget.edition;
      final result = edition == null
          ? await widget.repository.schedule(
              widget.event.id, _dateValue, _address.text,
              useCommunityRegion: _useCommunityRegion,
              city: _city.text,
              state: _state.text)
          : await widget.repository.updateEdition(
              widget.event.id, edition.id, _dateValue, _address.text,
              useCommunityRegion: _useCommunityRegion,
              city: _city.text,
              state: _state.text);
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(
                widget.edition == null ? 'Agendar edição' : 'Editar edição')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(widget.event.name,
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 12),
          const Text(
              'Uma nova data, a mesma comunidade. Cada edição tem suas próprias confirmações.'),
          const SizedBox(height: 24),
          OutlinedButton.icon(
              onPressed: _saving ? null : _pick,
              icon: const Icon(Icons.calendar_month),
              label: Text('${_date(_dateValue)} · ${_time(_dateValue)}')),
          const SizedBox(height: 20),
          TextField(
              controller: _address,
              maxLength: 300,
              decoration: const InputDecoration(
                  labelText: 'Local público',
                  hintText: 'Nome do local e endereço')),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Usar região da comunidade'),
              subtitle: Text([widget.event.city, widget.event.state]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(' · ')
                      .isEmpty
                  ? 'A comunidade ainda não tem uma região definida.'
                  : [widget.event.city, widget.event.state]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(' · ')),
              value: _useCommunityRegion,
              onChanged: _saving ||
                      !(widget.event.city?.isNotEmpty ?? false) ||
                      !(widget.event.state?.isNotEmpty ?? false)
                  ? null
                  : (value) => setState(() => _useCommunityRegion = value)),
          if (!_useCommunityRegion) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _city,
                      decoration:
                          const InputDecoration(labelText: 'Cidade *'))),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                      controller: _state,
                      decoration:
                          const InputDecoration(labelText: 'Estado *'))),
            ]),
          ],
          const SizedBox(height: 24),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving
                  ? 'Salvando…'
                  : widget.edition == null
                      ? 'Publicar edição'
                      : 'Salvar edição')),
        ]),
      );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 2,
          fontWeight: FontWeight.w700));
}

class _Metric extends StatelessWidget {
  const _Metric(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Flexible(
            child: Text(text, style: Theme.of(context).textTheme.labelMedium)),
      ]);
}

String _date(DateTime value) {
  final d = value.toLocal();
  const months = [
    'JAN',
    'FEV',
    'MAR',
    'ABR',
    'MAI',
    'JUN',
    'JUL',
    'AGO',
    'SET',
    'OUT',
    'NOV',
    'DEZ'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _time(DateTime value) {
  final d = value.toLocal();
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
