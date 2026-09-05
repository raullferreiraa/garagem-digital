import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_detail_screen.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/teams/team.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

final class TeamDetailScreen extends StatefulWidget {
  const TeamDetailScreen({
    required this.teamId,
    required this.repository,
    required this.carsRepository,
    required this.evolutionsRepository,
    required this.currentUserId,
    super.key,
  });

  final String teamId;
  final TeamsRepository repository;
  final CarsRepository carsRepository;
  final EvolutionsRepository evolutionsRepository;
  final String currentUserId;

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  late Future<TeamDetail> _team;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _team = widget.repository.detail(widget.teamId);
  }

  Future<void> _reload() async {
    final next = widget.repository.detail(widget.teamId);
    setState(() => _team = next);
    await next;
  }

  Future<void> _act(Future<void> Function() action, String success) async {
    setState(() => _acting = true);
    try {
      await action();
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _chooseCar(TeamDetail team) async {
    final ownCars = await widget.carsRepository.mine();
    if (!mounted) return;
    if (ownCars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione um carro à sua garagem primeiro.')),
      );
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Carro na equipe', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final car in ownCars)
              ListTile(
                leading: const Icon(Icons.directions_car_outlined),
                title: Text([car.model, car.year].whereType<Object>().join(' ')),
                trailing: team.cars.any((item) => item.id == car.id)
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, car.id),
              ),
            if (team.cars.any((car) => car.ownerId == widget.currentUserId))
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Não mostrar carro nesta equipe'),
                onTap: () => Navigator.pop(context, ''),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await _act(
      () => selected.isEmpty
          ? widget.repository.removeSelectedCar(team.id)
          : widget.repository.selectCar(team.id, selected),
      selected.isEmpty ? 'Carro removido da equipe.' : 'Carro escolhido para a equipe.',
    );
  }

  Future<void> _openCar(Car car) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CarDetailScreen(
          car: car,
          repository: widget.carsRepository,
          evolutionsRepository: widget.evolutionsRepository,
          canManage: car.ownerId == widget.currentUserId,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeamDetail>(
      future: _team,
      builder: (context, snapshot) {
        final team = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: Text(team?.name ?? 'Equipe')),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : snapshot.hasError
                  ? Center(
                      child: FilledButton(
                        onPressed: _reload,
                        child: Text(apiErrorMessage(snapshot.error!)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: _content(team!),
                    ),
        );
      },
    );
  }

  Widget _content(TeamDetail team) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        CircleAvatar(
          radius: 44,
          child: Text(team.name.substring(0, 1).toUpperCase()),
        ),
        const SizedBox(height: 16),
        Text(team.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        if (team.location != null)
          Text(team.location!, textAlign: TextAlign.center),
        if (team.description != null) ...[
          const SizedBox(height: 16),
          Text(team.description!, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 20),
        if (team.myRole == null && team.myRequest != 'pendente')
          FilledButton.icon(
            onPressed: _acting
                ? null
                : () => _act(
                      () => widget.repository.requestEntry(team.id),
                      'Pedido de entrada enviado.',
                    ),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Pedir para entrar'),
          ),
        if (team.myRole == null && team.myRequest == 'pendente')
          const Chip(
            avatar: Icon(Icons.schedule),
            label: Text('Pedido de entrada pendente'),
          ),
        if (team.myRole != null)
          OutlinedButton.icon(
            onPressed: _acting ? null : () => _chooseCar(team),
            icon: const Icon(Icons.garage_outlined),
            label: const Text('Escolher meu carro nesta equipe'),
          ),
        if (team.pendingRequests.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Pedidos de entrada', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final request in team.pendingRequests)
            Card(
              child: ListTile(
                title: Text(request.name),
                subtitle: Text('@${request.username}'),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: 'Recusar',
                      onPressed: _acting
                          ? null
                          : () => _act(
                                () => widget.repository.decideRequest(
                                  team.id,
                                  request.id,
                                  approve: false,
                                ),
                                'Pedido recusado.',
                              ),
                      icon: const Icon(Icons.close),
                    ),
                    IconButton(
                      tooltip: 'Aprovar',
                      onPressed: _acting
                          ? null
                          : () => _act(
                                () => widget.repository.decideRequest(
                                  team.id,
                                  request.id,
                                  approve: true,
                                ),
                                'Novo integrante aprovado.',
                              ),
                      icon: const Icon(Icons.check),
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 28),
        Text('Garagem da equipe', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (team.cars.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Os carros escolhidos pelos integrantes aparecerão aqui.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          for (final car in team.cars) _TeamCarCard(car: car, onTap: () => _openCar(car)),
        const SizedBox(height: 28),
        Text('Integrantes (${team.memberCount})', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final member in team.members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text(member.name.substring(0, 1).toUpperCase())),
            title: Text(member.name),
            subtitle: Text('@${member.username}'),
            trailing: Text(member.role == 'dono' ? 'Dono' : 'Membro'),
          ),
      ],
    );
  }
}

final class _TeamCarCard extends StatelessWidget {
  const _TeamCarCard({required this.car, required this.onTap});

  final Car car;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox.square(
              dimension: 96,
              child: car.photoUrl == null
                  ? const ColoredBox(
                      color: Color(0xFF24262A),
                      child: Icon(Icons.directions_car),
                    )
                  : Image.network(car.photoUrl!, fit: BoxFit.cover),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(car.model, style: Theme.of(context).textTheme.titleMedium),
                    Text('@${car.ownerUsername}'),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}
