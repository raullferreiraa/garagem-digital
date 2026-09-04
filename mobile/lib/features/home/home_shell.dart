import 'package:flutter/material.dart';
import 'package:garagem_mobile/features/auth/session_controller.dart';
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      CarList(
        title: 'Explorar projetos',
        emptyMessage: 'Os primeiros projetos aparecerao aqui.',
        loader: widget.carsRepository.feed,
      ),
      CarList(
        title: 'Minha garagem',
        emptyMessage: 'Adicione seu carro e comece a registrar a historia dele.',
        loader: widget.carsRepository.mine,
        primaryAction: const _AddCarButton(),
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

final class _AddCarButton extends StatelessWidget {
  const _AddCarButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastro de carro e o proximo fluxo.')),
      ),
      icon: const Icon(Icons.add),
      label: const Text('Adicionar carro'),
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
                'Equipes entram no proximo ciclo.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Cada dono escolhera quais carros quer mostrar na garagem da equipe.',
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
