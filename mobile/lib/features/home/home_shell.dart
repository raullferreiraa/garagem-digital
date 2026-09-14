import 'package:flutter/material.dart';
import 'package:garagem_mobile/features/auth/session_controller.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_detail_screen.dart';
import 'package:garagem_mobile/features/cars/car_form_screen.dart';
import 'package:garagem_mobile/features/cars/car_list.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/profile/profile_screen.dart';
import 'package:garagem_mobile/features/profile/public_profile_screen.dart';
import 'package:garagem_mobile/features/profile/users_repository.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';
import 'package:garagem_mobile/features/teams/teams_screen.dart';

final class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.session,
    required this.carsRepository,
    required this.evolutionsRepository,
    required this.teamsRepository,
    required this.usersRepository,
    super.key,
  });

  final SessionController session;
  final CarsRepository carsRepository;
  final EvolutionsRepository evolutionsRepository;
  final TeamsRepository teamsRepository;
  final UsersRepository usersRepository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

final class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _feedRevision = 0;
  int _garageRevision = 0;
  int _profileRevision = 0;

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

  Future<void> _openPublicProfile(String userId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: userId,
          currentUserId: widget.session.user!.id,
          usersRepository: widget.usersRepository,
          carsRepository: widget.carsRepository,
          evolutionsRepository: widget.evolutionsRepository,
        ),
      ),
    );
  }

  Future<void> _openCar(Car car, {required bool canManage}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CarDetailScreen(
          car: car,
          repository: widget.carsRepository,
          evolutionsRepository: widget.evolutionsRepository,
          canManage: canManage,
          currentUserId: widget.session.user!.id,
          onOwnerTap: car.ownerId == widget.session.user!.id
              ? null
              : () => _openPublicProfile(car.ownerId),
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
      TeamsScreen(
        repository: widget.teamsRepository,
        carsRepository: widget.carsRepository,
        evolutionsRepository: widget.evolutionsRepository,
        currentUserId: widget.session.user!.id,
        usersRepository: widget.usersRepository,
      ),
      ProfileScreen(
        key: ValueKey('profile-$_profileRevision'),
        session: widget.session,
        carsRepository: widget.carsRepository,
        evolutionsRepository: widget.evolutionsRepository,
        usersRepository: widget.usersRepository,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
            if (value == 3) _profileRevision++;
          });
        },
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
