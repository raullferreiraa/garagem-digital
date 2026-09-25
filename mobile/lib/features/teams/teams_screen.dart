import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/messages/messages_repository.dart';
import 'package:garagem_mobile/features/profile/users_repository.dart';
import 'package:garagem_mobile/features/teams/team.dart';
import 'package:garagem_mobile/features/teams/team_detail_screen.dart';
import 'package:garagem_mobile/features/teams/team_form_screen.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

enum _TeamView { all, pending, invites }

final class TeamsScreen extends StatefulWidget {
  const TeamsScreen({
    required this.repository,
    required this.carsRepository,
    required this.evolutionsRepository,
    required this.currentUserId,
    required this.usersRepository,
    required this.messagesRepository,
    required this.onConversationChanged,
    required this.unreadTeamMessages,
    required this.onTeamChatChanged,
    required this.refreshRevision,
    required this.onSearch,
    super.key,
  });

  final TeamsRepository repository;
  final CarsRepository carsRepository;
  final EvolutionsRepository evolutionsRepository;
  final String currentUserId;
  final UsersRepository usersRepository;
  final MessagesRepository messagesRepository;
  final VoidCallback onConversationChanged;
  final int unreadTeamMessages;
  final VoidCallback onTeamChatChanged;
  final int refreshRevision;
  final VoidCallback onSearch;

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  List<Team>? _teams;
  Object? _loadError;
  bool _loading = true;
  int _reloadRequest = 0;
  _TeamView _view = _TeamView.all;
  bool _exploringDirectory = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant TeamsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshRevision != oldWidget.refreshRevision) {
      _exploringDirectory = false;
      _reload();
    }
  }

  Future<void> _reload() async {
    final request = ++_reloadRequest;
    try {
      final updated = await widget.repository.list();
      if (!mounted || request != _reloadRequest) return;
      setState(() {
        _teams = updated;
        _loadError = null;
        _loading = false;
        if ((_view == _TeamView.pending &&
                !updated.any((team) => team.myRequest == 'pendente')) ||
            (_view == _TeamView.invites &&
                !updated.any((team) => team.myInvite == 'pendente'))) {
          _view = _TeamView.all;
        }
        if (!updated.any((team) => team.myRole != null)) {
          _exploringDirectory = false;
        }
      });
    } catch (error) {
      if (!mounted || request != _reloadRequest) return;
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
    await _reload();
    widget.onTeamChatChanged();
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
          usersRepository: widget.usersRepository,
          messagesRepository: widget.messagesRepository,
          onConversationChanged: widget.onConversationChanged,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    Team? myTeam;
    for (final team in _teams ?? const <Team>[]) {
      if (team.myRole != null) {
        myTeam = team;
        break;
      }
    }
    if (myTeam != null && !_exploringDirectory) {
      return TeamDetailScreen(
        teamId: myTeam.id,
        repository: widget.repository,
        carsRepository: widget.carsRepository,
        evolutionsRepository: widget.evolutionsRepository,
        currentUserId: widget.currentUserId,
        usersRepository: widget.usersRepository,
        messagesRepository: widget.messagesRepository,
        onConversationChanged: widget.onConversationChanged,
        isMyTeamHome: true,
        refreshRevision: widget.refreshRevision,
        onExploreTeams: () => setState(() => _exploringDirectory = true),
        unreadChatCount: widget.unreadTeamMessages,
        onTeamChatChanged: widget.onTeamChatChanged,
        onMembershipChanged: () {
          _reload();
          widget.onTeamChatChanged();
        },
      );
    }
    final hasTeam =
        (_teams ?? const <Team>[]).any((team) => team.myRole != null);
    return Scaffold(
      appBar: AppBar(
        leading: hasTeam
            ? IconButton(
                tooltip: 'Voltar à minha equipe',
                onPressed: () => setState(() => _exploringDirectory = false),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: Text(hasTeam ? 'Explorar equipes' : 'Encontre uma equipe'),
        actions: [
          IconButton(
            tooltip: 'Buscar equipes',
            onPressed: widget.onSearch,
            icon: const Icon(Icons.search_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const GdSkeleton();
    if (_loadError != null && _teams == null) {
      return _TeamMessage(
        message: apiErrorMessage(_loadError!),
        onRetry: _reload,
      );
    }
    final allTeams = _teams ?? const <Team>[];
    final hasTeam = allTeams.any((team) => team.myRole != null);
    final pendingCount =
        allTeams.where((team) => team.myRequest == 'pendente').length;
    final inviteCount =
        allTeams.where((team) => team.myInvite == 'pendente').length;
    final teams = switch (_view) {
      _TeamView.all => allTeams,
      _TeamView.pending =>
        allTeams.where((team) => team.myRequest == 'pendente').toList(),
      _TeamView.invites =>
        allTeams.where((team) => team.myInvite == 'pendente').toList(),
    };
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (!hasTeam) ...[
            _TeamsIntro(onCreate: _create),
            const SizedBox(height: 24),
          ],
          if (pendingCount > 0 || inviteCount > 0) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Descobrir',
                    icon: Icons.public,
                    selected: _view == _TeamView.all,
                    onSelected: () => setState(() => _view = _TeamView.all),
                  ),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Pedidos ($pendingCount)',
                      icon: Icons.schedule,
                      selected: _view == _TeamView.pending,
                      onSelected: () =>
                          setState(() => _view = _TeamView.pending),
                    ),
                  ],
                  if (inviteCount > 0) ...[
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Convites ($inviteCount)',
                      icon: Icons.mail_outline_rounded,
                      selected: _view == _TeamView.invites,
                      onSelected: () =>
                          setState(() => _view = _TeamView.invites),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          GdSectionTitle(title: _sectionTitle, eyebrow: 'COMUNIDADE'),
          const SizedBox(height: 12),
          if (teams.isEmpty)
            _FilteredEmpty(view: _view)
          else
            for (var index = 0; index < teams.length; index++) ...[
              GdReveal(
                child: _TeamCard(
                    team: teams[index], onTap: () => _open(teams[index].id)),
              ),
              if (index != teams.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  String get _sectionTitle => switch (_view) {
        _TeamView.all => 'Equipes para conhecer',
        _TeamView.pending => 'Pedidos enviados',
        _TeamView.invites => 'Convites recebidos',
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

final class _TeamsIntro extends StatelessWidget {
  const _TeamsIntro({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CULTURA AUTOMOTIVA',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.primary,
                letterSpacing: 2.2,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'A PAIXÃO É MAIOR\nQUANDO É COMPARTILHADA.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Pessoas, máquinas e histórias na mesma direção.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Criar minha equipe'),
        ),
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
      avatar: Icon(icon,
          size: 18,
          color: selected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.primary),
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
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: membership ? colors.primary : colors.outlineVariant,
                width: 2,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GdAvatar(
                name: team.name,
                url: team.avatarUrl,
                size: 52,
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
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        Icon(Icons.north_east_rounded,
                            size: 18, color: colors.onSurfaceVariant),
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
                          label:
                              '${team.memberCount} integrante${team.memberCount == 1 ? '' : 's'}',
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
                        if (team.myInvite == 'pendente')
                          const _MetaPill(
                            icon: Icons.mail_outline_rounded,
                            label: 'Convite recebido',
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
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: highlighted ? colors.primary : null),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label, style: Theme.of(context).textTheme.labelSmall),
          ),
        ],
      ),
    );
  }
}

final class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty({required this.view});

  final _TeamView view;

  @override
  Widget build(BuildContext context) {
    final message = switch (view) {
      _TeamView.all => 'Nenhuma equipe foi criada ainda.',
      _TeamView.pending => 'Você não tem pedidos pendentes.',
      _TeamView.invites => 'Você não tem convites pendentes.',
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
        ],
      ),
    );
  }
}
