import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/teams/team.dart';
import 'package:garagem_mobile/features/teams/team_detail_screen.dart';
import 'package:garagem_mobile/features/teams/team_form_screen.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

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
      appBar: AppBar(title: const Text('Equipes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Criar equipe'),
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
    final teams = _teams ?? const <Team>[];
    if (teams.isEmpty) {
      return const _TeamMessage(
        message: 'Crie a primeira equipe e reúna projetos automotivos.',
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: teams.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final team = teams[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 28,
                child: Text(team.name.substring(0, 1).toUpperCase()),
              ),
              title: Text(team.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (team.location != null) Text(team.location!),
                  Text(
                    '${team.memberCount} integrante${team.memberCount == 1 ? '' : 's'}',
                  ),
                  if (team.myRole != null)
                    Text('Você é ${_roleLabel(team.myRole!)}'),
                  if (team.myRequest == 'pendente')
                    const Text('Pedido de entrada pendente'),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(team.id),
            ),
          );
        },
      ),
    );
  }
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
