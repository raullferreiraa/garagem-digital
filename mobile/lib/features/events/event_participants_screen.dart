import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/events/event.dart';
import 'package:garagem_mobile/features/events/event_participants.dart';
import 'package:garagem_mobile/features/events/events_repository.dart';

final class EventParticipantsScreen extends StatefulWidget {
  const EventParticipantsScreen({
    required this.eventId,
    required this.eventName,
    required this.edition,
    required this.repository,
    this.onPersonTap,
    this.onTeamTap,
    super.key,
  });

  final String eventId;
  final String eventName;
  final EventEdition edition;
  final EventsRepository repository;
  final Future<void> Function(String id)? onPersonTap, onTeamTap;

  @override
  State<EventParticipantsScreen> createState() =>
      _EventParticipantsScreenState();
}

class _EventParticipantsScreenState extends State<EventParticipantsScreen> {
  String _type = 'pessoas';
  final List<EventParticipant> _people = [];
  final List<EventTeamParticipant> _teams = [];
  int _totalPeople = 0, _totalTeams = 0, _revision = 0;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final revision = ++_revision;
    final type = _type;
    if (reset) {
      _people.clear();
      _teams.clear();
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.participants(
        widget.eventId,
        widget.edition.id,
        type: type,
        offset: type == 'pessoas' ? _people.length : _teams.length,
      );
      if (!mounted || revision != _revision) return;
      setState(() {
        _totalPeople = result.totalPeople;
        _totalTeams = result.totalTeams;
        _people.addAll(result.people);
        _teams.addAll(result.teams);
      });
    } catch (error) {
      if (mounted && revision == _revision) setState(() => _error = error);
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  void _select(String type) {
    if (_type == type) return;
    setState(() => _type = type);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.edition.startsAt.toLocal();
    final dateLabel = '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    final count = _type == 'pessoas' ? _people.length : _teams.length;
    final total = _type == 'pessoas' ? _totalPeople : _totalTeams;
    return Scaffold(
      appBar: AppBar(title: const Text('Participantes')),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          itemCount: count + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.eventName,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('Edição de $dateLabel',
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: _tab('pessoas', 'Pessoas', _totalPeople)),
                    const SizedBox(width: 8),
                    Expanded(child: _tab('equipes', 'Equipes', _totalTeams)),
                  ]),
                  const SizedBox(height: 18),
                ],
              );
            }
            if (index == count + 1) {
              if (_error != null) {
                return Center(
                    child: Column(children: [
                  Text(apiErrorMessage(_error!)),
                  TextButton(
                      onPressed: () => _load(reset: count == 0),
                      child: const Text('Tentar novamente')),
                ]));
              }
              if (_loading) {
                return const SizedBox(
                    height: 220, child: GdSkeleton(compact: false));
              }
              if (count == 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                      child: Text(_type == 'pessoas'
                          ? 'Ninguém confirmou presença nesta edição ainda.'
                          : 'Nenhuma equipe confirmou participação nesta edição ainda.')),
                );
              }
              if (count < total) {
                return Center(
                    child: TextButton(
                  onPressed: () => _load(),
                  child: const Text('Carregar mais'),
                ));
              }
              return const SizedBox.shrink();
            }
            final itemIndex = index - 1;
            if (_type == 'pessoas') {
              final person = _people[itemIndex];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: GdAvatar(
                      url: person.avatarUrl, name: person.name, size: 46),
                  title: Text(person.name),
                  subtitle: Text(person.carModel == null
                      ? '@${person.username}'
                      : '@${person.username} · ${person.carModel}${person.carYear == null ? '' : ' ${person.carYear}'}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (person.carPhotoUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GdImage(
                            url: person.carPhotoUrl, width: 44, height: 40),
                      ),
                      const SizedBox(width: 6),
                    ],
                    const Icon(Icons.chevron_right),
                  ]),
                  onTap: widget.onPersonTap == null
                      ? null
                      : () => widget.onPersonTap!(person.userId),
                ),
              );
            }
            final team = _teams[itemIndex];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading:
                    GdAvatar(url: team.avatarUrl, name: team.name, size: 46),
                title: Text(team.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: widget.onTeamTap == null
                    ? null
                    : () => widget.onTeamTap!(team.id),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _tab(String type, String label, int count) => ChoiceChip(
        label: Text('$label  $count'),
        selected: _type == type,
        onSelected: (_) => _select(type),
      );
}
