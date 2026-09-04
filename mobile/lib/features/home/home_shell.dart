import 'package:flutter/material.dart';
import 'package:garagem_mobile/features/auth/session_controller.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_detail_screen.dart';
import 'package:garagem_mobile/features/cars/car_form_screen.dart';
import 'package:garagem_mobile/features/cars/car_list.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';

final class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.session,
    required this.carsRepository,
    super.key,
  });

  final SessionController session;
  final CarsRepository carsRepository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _feedRevision = 0;
  int _garageRevision = 0;

  void _refreshCars() {
    setState(() {
      _feedRevision++;
      _garageRevision++;
    });
  }

  Future<void> _openCreateCar() async {
    final created = await Navigator.of(context).push<Car>(
      MaterialPageRoute(
        builder: (_) => CarFormScreen(repository: widget.carsRepository),
      ),
    );

    if (created == null || !mounted) return;
    setState(() => _index = 1);
    _refreshCars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Carro adicionado à sua garagem.')),
    );
  }

  Future<void> _openCar(Car car, {required bool canManage}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CarDetailScreen(
          car: car,
          repository: widget.carsRepository,
          canManage: canManage,
        ),
      ),
    );
    if (mounted) _refreshCars();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CarList(
        key: ValueKey('feed-$_feedRevision'),
        title: 'Explorar projetos',
        emptyMessage: 'Os primeiros projetos aparecerão aqui.',
        loader: widget.carsRepository.feed,
        onCarTap: (car) => _openCar(car, canManage: false),
      ),
      CarList(
        key: ValueKey('garage-$_garageRevision'),
        title: 'Minha garagem',
        emptyMessage: 'Adicione seu carro e comece a registrar a história dele.',
        loader: widget.carsRepository.mine,
        onCarTap: (car) => _openCar(car, canManage: true),
        primaryActionLabel: 'Adicionar carro',
        onPrimaryAction: _openCreateCar,
      ),
      const _TeamsPage(),
      _ProfilePage(session: widget.session),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(Icons.garage_outlined),
            selectedIcon: Icon(Icons.garage),
            label: 'Garagem',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Equipes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

final class _TeamsPage extends StatelessWidget {
  const _TeamsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipes')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_rounded, size: 64),
              SizedBox(height: 16),
              Text(
                'Equipes entram no próximo ciclo.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Cada dono escolherá quais carros quer mostrar na garagem da equipe.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final user = session.user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          CircleAvatar(
            radius: 42,
            child: Text(
              user.name.substring(0, 1).toUpperCase(),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            '@${user.username}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (user.bio != null) ...[
            const SizedBox(height: 16),
            Text(user.bio!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: session.logout,
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}
