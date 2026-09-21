import 'dart:async';

import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/profile/public_profile.dart';
import 'package:garagem_mobile/features/profile/users_repository.dart';
import 'package:garagem_mobile/features/teams/team.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

enum SearchCategory { projects, people, teams }

final class SearchScreen extends StatefulWidget {
  const SearchScreen({
    required this.carsRepository,
    required this.usersRepository,
    required this.teamsRepository,
    required this.onCarTap,
    required this.onUserTap,
    required this.onTeamTap,
    this.initialCategory = SearchCategory.projects,
    super.key,
  });

  final CarsRepository carsRepository;
  final UsersRepository usersRepository;
  final TeamsRepository teamsRepository;
  final Future<void> Function(Car) onCarTap;
  final Future<void> Function(String) onUserTap;
  final Future<void> Function(Team) onTeamTap;
  final SearchCategory initialCategory;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

final class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  late SearchCategory _filter;
  List<Car> _cars = const [];
  List<SocialUser> _users = const [];
  List<Team> _teams = const [];
  String _lastQuery = '';
  String? _resultsQuery;
  SearchCategory? _resultsFilter;
  int _searchRequest = 0;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialCategory;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool _canSearch(String query) {
    final term = _filter == SearchCategory.people && query.startsWith('@')
        ? query.substring(1)
        : query;
    return term.length >= 2;
  }

  void _queryChanged(String value) {
    _debounce?.cancel();
    _searchRequest++;
    final query = value.trim();
    if (!_canSearch(query)) {
      setState(() {
        _lastQuery = query;
        _cars = const [];
        _users = const [];
        _teams = const [];
        _resultsQuery = null;
        _resultsFilter = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _lastQuery = query;
      _loading = true;
      _error = null;
    });
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _search(query),
    );
  }

  Future<void> _search(String query) async {
    final request = ++_searchRequest;
    final filter = _filter;
    setState(() {
      _lastQuery = query;
      _loading = true;
      _error = null;
    });
    try {
      final results = await switch (filter) {
        SearchCategory.projects => widget.carsRepository.search(query),
        SearchCategory.people => widget.usersRepository.search(query),
        SearchCategory.teams => widget.teamsRepository.search(query),
      };
      if (!mounted ||
          request != _searchRequest ||
          _controller.text.trim() != query ||
          _filter != filter) return;
      setState(() {
        switch (filter) {
          case SearchCategory.projects:
            _cars = results as List<Car>;
            break;
          case SearchCategory.people:
            _users = results as List<SocialUser>;
            break;
          case SearchCategory.teams:
            _teams = results as List<Team>;
            break;
        }
        _resultsQuery = query;
        _resultsFilter = filter;
        _loading = false;
      });
    } catch (error) {
      if (!mounted ||
          request != _searchRequest ||
          _controller.text.trim() != query ||
          _filter != filter) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _selectFilter(SearchCategory filter) {
    if (_filter == filter) return;
    _debounce?.cancel();
    _searchRequest++;
    final query = _controller.text.trim();
    setState(() {
      _filter = filter;
      _loading = _canSearch(query);
      _error = null;
    });
    if (_canSearch(query)) _search(query);
  }

  Future<void> _openCar(Car car) async {
    await widget.onCarTap(car);
    if (mounted) await _refreshResults();
  }

  Future<void> _openUser(String userId) async {
    await widget.onUserTap(userId);
    if (mounted) await _refreshResults();
  }

  Future<void> _openTeam(Team team) async {
    await widget.onTeamTap(team);
    if (mounted) await _refreshResults();
  }

  Future<void> _refreshResults() async {
    final query = _controller.text.trim();
    if (_canSearch(query)) await _search(query);
  }

  bool get _hasResults => switch (_filter) {
        SearchCategory.projects => _cars.isNotEmpty,
        SearchCategory.people => _users.isNotEmpty,
        SearchCategory.teams => _teams.isNotEmpty,
      };

  int? _countFor(SearchCategory filter, String query) {
    if (_resultsQuery != query || _resultsFilter != filter) return null;
    return switch (filter) {
      SearchCategory.projects => _cars.length,
      SearchCategory.people => _users.length,
      SearchCategory.teams => _teams.length,
    };
  }

  String get _categoryLabel => switch (_filter) {
        SearchCategory.projects => 'Projetos',
        SearchCategory.people => 'Pessoas',
        SearchCategory.teams => 'Equipes',
      };

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar'), actions: const [
        Padding(
          padding: EdgeInsets.only(right: 20),
          child: GdWordmark(compact: true),
        ),
      ]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _queryChanged,
              onSubmitted: (value) {
                final query = value.trim();
                if (_canSearch(query)) {
                  _debounce?.cancel();
                  _search(query);
                }
              },
              decoration: InputDecoration(
                hintText: switch (_filter) {
                  SearchCategory.projects =>
                    'Modelo, ano ou detalhe do projeto',
                  SearchCategory.people => 'Nome ou @usuário',
                  SearchCategory.teams => 'Nome ou localização da equipe',
                },
                prefixIcon: Icon(Icons.search_rounded,
                    color: Theme.of(context).colorScheme.primary),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar',
                        onPressed: () {
                          _controller.clear();
                          _queryChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Projetos',
                  icon: Icons.directions_car_outlined,
                  count: _countFor(SearchCategory.projects, query),
                  selected: _filter == SearchCategory.projects,
                  onTap: () => _selectFilter(SearchCategory.projects),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Pessoas',
                  icon: Icons.people_outline_rounded,
                  count: _countFor(SearchCategory.people, query),
                  selected: _filter == SearchCategory.people,
                  onTap: () => _selectFilter(SearchCategory.people),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Equipes',
                  icon: Icons.groups_outlined,
                  count: _countFor(SearchCategory.teams, query),
                  selected: _filter == SearchCategory.teams,
                  onTap: () => _selectFilter(SearchCategory.teams),
                ),
              ],
            ),
          ),
          Expanded(child: _body(query)),
        ],
      ),
    );
  }

  Widget _body(String query) {
    if (query.isEmpty) {
      return const _SearchMessage(
        icon: Icons.travel_explore_rounded,
        title: 'Descubra a comunidade',
        message: 'Encontre projetos, pessoas e equipes em um só lugar.',
      );
    }
    if (!_canSearch(query)) {
      return const _SearchMessage(
        icon: Icons.keyboard_alt_outlined,
        title: 'Continue digitando',
        message: 'Use pelo menos 2 caracteres para iniciar a busca.',
      );
    }
    if (_loading &&
        _lastQuery == query &&
        (_resultsQuery != query || _resultsFilter != _filter || !_hasResults)) {
      return const GdSkeleton(compact: true);
    }
    if (_error != null &&
        _lastQuery == query &&
        (_resultsQuery != query || _resultsFilter != _filter || !_hasResults)) {
      return _SearchMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível buscar',
        message: apiErrorMessage(_error!),
        actionLabel: 'Tentar novamente',
        onAction: () => _search(query),
      );
    }
    if (!_hasResults) {
      return _SearchMessage(
        icon: Icons.search_off_rounded,
        title: 'Nada encontrado',
        message: 'Nenhum resultado em $_categoryLabel para “$query”.',
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        if (_loading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_off_outlined),
              title: const Text('Não foi possível atualizar a busca.'),
              trailing: TextButton(
                onPressed: () => _search(query),
                child: const Text('Tentar novamente'),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_filter == SearchCategory.projects && _cars.isNotEmpty)
          _ResultSection(
            title: 'Projetos',
            count: _cars.length,
            children: [
              for (final car in _cars)
                _CarResult(
                  car: car,
                  query: query,
                  onTap: () => _openCar(car),
                ),
            ],
          ),
        if (_filter == SearchCategory.people && _users.isNotEmpty)
          _ResultSection(
            title: 'Pessoas',
            count: _users.length,
            children: [
              for (final user in _users)
                _UserResult(
                  user: user,
                  onTap: () => _openUser(user.id),
                ),
            ],
          ),
        if (_filter == SearchCategory.teams && _teams.isNotEmpty)
          _ResultSection(
            title: 'Equipes',
            count: _teams.length,
            children: [
              for (final team in _teams)
                _TeamResult(
                  team: team,
                  onTap: () => _openTeam(team),
                ),
            ],
          ),
      ],
    );
  }
}

final class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: colors.primary,
      backgroundColor: colors.surfaceContainer,
      side:
          BorderSide(color: selected ? colors.primary : colors.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? colors.onPrimary : colors.onSurfaceVariant,
          ),
      avatar: Icon(icon,
          size: 18,
          color: selected ? colors.onPrimary : colors.onSurfaceVariant),
      showCheckmark: false,
      label: Text(count == null ? label : '$label  $count'),
    );
  }
}

final class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.title,
    required this.count,
    required this.children,
  });

  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GdSectionTitle(
            title: title,
            eyebrow: 'RESULTADOS',
            trailing: Text('$count',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    )),
          ),
          const SizedBox(height: 10),
          Material(
            clipBehavior: Clip.antiAlias,
            color: Theme.of(context).colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index != children.length - 1)
                    Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _CarResult extends StatelessWidget {
  const _CarResult({
    required this.car,
    required this.query,
    required this.onTap,
  });

  final Car car;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final match = _projectMatchLabel(car, query);
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GdImage(
                  url: car.photoUrl,
                  width: 92,
                  height: 92,
                  semanticLabel: car.model),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [car.model, car.year]
                        .where((item) => item != null)
                        .join(' '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text('@${car.ownerUsername}',
                      style: Theme.of(context).textTheme.bodySmall),
                  if (match != null) ...[
                    const SizedBox(height: 7),
                    Text(match,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colors.primary,
                            )),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_outward_rounded,
                size: 18, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

String? _projectMatchLabel(Car car, String query) {
  final term = query.trim().toLowerCase();
  if (term.isEmpty) return null;

  bool contains(String? value) => value?.toLowerCase().contains(term) ?? false;
  bool startsWord(String? value) =>
      value
          ?.toLowerCase()
          .split(RegExp(r'[\s,./;:+()\-]+'))
          .any((word) => word.startsWith(term)) ??
      false;

  if (contains(car.model)) return 'Correspondência no modelo';
  if (startsWord(car.year?.toString())) return 'Ano: ${car.year}';
  if (startsWord(car.color)) return 'Cor: ${car.color}';
  if (startsWord(car.history)) return 'Correspondência na história';
  if (startsWord(car.engine)) return 'Motor: ${car.engine}';
  if (startsWord(car.transmission)) return 'Câmbio: ${car.transmission}';
  if (startsWord(car.fuel)) return 'Combustível: ${car.fuel}';
  if (startsWord(car.estimatedPower)) {
    return 'Potência: ${car.estimatedPower}';
  }
  if (startsWord(car.preparation)) return 'Preparação: ${car.preparation}';
  if (startsWord(car.projectStatus)) return 'Fase: ${car.projectStatus}';
  if (startsWord(car.suspensionType)) {
    return 'Suspensão: ${car.suspensionType}';
  }
  if (startsWord(car.wheelSize?.toString())) return 'Aro: ${car.wheelSize}';
  return null;
}

final class _UserResult extends StatelessWidget {
  const _UserResult({required this.user, required this.onTap});

  final SocialUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      leading: GdAvatar(url: user.avatarUrl, name: user.name, size: 48),
      title: Text(
        '@${user.username}',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(user.name),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

final class _TeamResult extends StatelessWidget {
  const _TeamResult({required this.team, required this.onTap});

  final Team team;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = [
      '${team.memberCount} ${team.memberCount == 1 ? 'integrante' : 'integrantes'}',
      if (team.location != null) team.location!,
    ];
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      leading: GdAvatar(url: team.avatarUrl, name: team.name, size: 48),
      title: Text(
        team.name,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(details.join(' • ')),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

final class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
      child: GdReveal(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 28, color: colors.onPrimary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
