import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/teams/team.dart';
import 'package:garagem_mobile/features/teams/team_detail_screen.dart';
import 'package:garagem_mobile/features/teams/team_form_screen.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

enum _TeamView { all, mine, pending }

final class TeamsScreen extends StatefulWidget {
  const TeamsScreen({
    required this.repository,
    required this.carsRepository,
    required this.evolutionsRepository,
    required this.currentUserId,
    super.key,
  });

  final TeamsRepository repository;
  final CarsRepository carsRepository;
  final EvolutionsRepository evolutionsRepository;
  final String currentUserId;

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  List<Team>? _teams;
  Object? _loadError;
  bool _loading = true;
  _TeamView _view = _TeamView.all;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final updated = await widget.repository.list();
      if (!mounted) return;
      setState(() {
        _teams = updated;
        _loadError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<TeamDetail>(
      MaterialPageRoute(
        builder: (_) => TeamFormScreen(repository: widget.repository),
      ),
    );
    if (created == null || !mounted) return;
    setState(() {
      _teams = [
        created,
        ...?_teams?.where((team) => team.id != created.id),
      ];
      _loadError = null;
    });
    await _open(created.id);
  }

  Future<void> _open(String teamId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TeamDetailScreen(
          teamId: teamId,
          repository: widget.repository,
          carsRepository: widget.carsRepository,
          evolutionsRepository: widget.evolutionsRepository,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipes'),
        actions: [
          IconButton(
            tooltip: 'Criar equipe',
            onPressed: _create,
            icon: const Icon(Icons.add_circle_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null && _teams == null) {
      return _TeamMessage(
        message: apiErrorMessage(_loadError!),
        onRetry: _reload,
      );
    }
    final allTeams = _teams ?? const <Team>[];
    final myTeams = allTeams.where((team) => team.myRole != null).length;
    final teams = switch (_view) {
      _TeamView.all => allTeams,
      _TeamView.mine =>
        allTeams.where((team) => team.myRole != null).toList(),
      _TeamView.pending => allTeams
          .where((team) => team.myRequest == 'pendente')
          .toList(),
    };
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _TeamsHero(
            teamCount: allTeams.length,
            myTeamCount: myTeams,
            onCreate: _create,
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Todas',
                  icon: Icons.public,
                  selected: _view == _TeamView.all,
                  onSelected: () => setState(() => _view = _TeamView.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Minhas',
                  icon: Icons.shield_outlined,
                  selected: _view == _TeamView.mine,
                  onSelected: () => setState(() => _view = _TeamView.mine),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Pedidos',
                  icon: Icons.schedule,
                  selected: _view == _TeamView.pending,
                  onSelected: () => setState(() => _view = _TeamView.pending),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  _sectionTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '${teams.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (teams.isEmpty)
            _FilteredEmpty(view: _view, onCreate: _create)
          else
            for (var index = 0; index < teams.length; index++) ...[
              _TeamCard(team: teams[index], onTap: () => _open(teams[index].id)),
              if (index != teams.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  String get _sectionTitle => switch (_view) {
        _TeamView.all => 'Comunidades para explorar',
        _TeamView.mine => 'Suas equipes',
        _TeamView.pending => 'Pedidos enviados',
      };
}

String _roleLabel(String role) => switch (role) {
      'dono' => 'dono',
      'administrador' => 'administrador',
      'moderador' => 'moderador',
      _ => 'membro',
    };

final class _TeamMessage extends StatelessWidget {
  const _TeamMessage({required this.message, this.onRetry});

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_outlined, size: 64),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Tentar novamente'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _TeamsHero extends StatelessWidget {
  const _TeamsHero({
    required this.teamCount,
    required this.myTeamCount,
    required this.onCreate,
  });

  final int teamCount;
  final int myTeamCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(alpha: 0.9),
            colors.surfaceContainerHigh,
          ],
        ),
        border: Border.all(color: colors.primary.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.groups_rounded, color: colors.primary),
          ),
          const SizedBox(height: 18),
          Text(
            'Projetos que andam juntos',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Encontre sua turma, acompanhe as máquinas dos integrantes e construa uma garagem coletiva.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _HeroStat(value: '$teamCount', label: 'equipes'),
              const SizedBox(width: 22),
              _HeroStat(value: '$myTeamCount', label: 'suas'),
              const Spacer(),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Criar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

final class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      avatar: Icon(icon, size: 18),
      label: Text(label),
      showCheckmark: false,
    );
  }
}

final class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team, required this.onTap});

  final Team team;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final membership = team.myRole != null;
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: membership ? colors.primary : colors.outlineVariant,
                width: 3,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: membership
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  team.name.substring(0, 1).toUpperCase(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            team.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    if (team.description != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        team.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaPill(
                          icon: Icons.people_outline,
                          label: '${team.memberCount} integrante${team.memberCount == 1 ? '' : 's'}',
                        ),
                        if (team.location != null)
                          _MetaPill(
                            icon: Icons.location_on_outlined,
                            label: team.location!,
                          ),
                        if (team.myRole != null)
                          _MetaPill(
                            icon: Icons.shield_outlined,
                            label: _roleLabel(team.myRole!),
                            highlighted: true,
                          ),
                        if (team.myRequest == 'pendente')
                          const _MetaPill(
                            icon: Icons.schedule,
                            label: 'Pedido pendente',
                            highlighted: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? colors.primary.withValues(alpha: 0.12)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: highlighted ? colors.primary : null),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

final class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty({required this.view, required this.onCreate});

  final _TeamView view;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final message = switch (view) {
      _TeamView.all => 'Nenhuma equipe foi criada ainda.',
      _TeamView.mine => 'Você ainda não participa de uma equipe.',
      _TeamView.pending => 'Você não tem pedidos pendentes.',
    };
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(Icons.flag_outlined, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (view != _TeamView.pending) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Criar uma equipe'),
            ),
          ],
        ],
      ),
    );
  }
}
