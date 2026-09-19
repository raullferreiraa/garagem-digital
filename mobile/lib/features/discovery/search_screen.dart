import 'dart:async';

import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
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
      if (!mounted || request != _searchRequest ||
          _controller.text.trim() != query || _filter != filter) return;
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
      if (!mounted || request != _searchRequest ||
          _controller.text.trim() != query || _filter != filter) return;
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
      appBar: AppBar(title: const Text('Buscar')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                    'Modelo, proprietário ou detalhe do projeto',
                  SearchCategory.people => 'Nome ou @usuário',
                  SearchCategory.teams => 'Nome ou localização da equipe',
                },
                prefixIcon: const Icon(Icons.search_rounded),
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
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
    if (_loading && _lastQuery == query &&
        (_resultsQuery != query || _resultsFilter != _filter ||
            !_hasResults)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _lastQuery == query &&
        (_resultsQuery != query || _resultsFilter != _filter ||
            !_hasResults)) {
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
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
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(icon, size: 18),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Text(
                '$count',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
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
  const _CarResult({required this.car, required this.onTap});

  final Car car;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 58,
          height: 58,
          child: car.photoUrl == null
              ? ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.directions_car_rounded),
                )
              : Image.network(
                  car.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined),
                ),
        ),
      ),
      title: Text(
        [car.model, car.year].where((item) => item != null).join(' '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text('@${car.ownerUsername}'),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

final class _UserResult extends StatelessWidget {
  const _UserResult({required this.user, required this.onTap});

  final SocialUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = user.name.isEmpty ? '?' : user.name[0].toUpperCase();
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      leading: CircleAvatar(
        radius: 27,
        backgroundImage:
            user.avatarUrl == null ? null : NetworkImage(user.avatarUrl!),
        child: user.avatarUrl == null ? Text(initial) : null,
      ),
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
    final initial = team.name.isEmpty ? '?' : team.name[0].toUpperCase();
    final details = [
      '${team.memberCount} ${team.memberCount == 1 ? 'integrante' : 'integrantes'}',
      if (team.location != null) team.location!,
    ];
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      leading: CircleAvatar(
        radius: 27,
        child: Text(
          initial,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 58,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
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
