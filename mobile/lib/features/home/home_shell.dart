import 'dart:async';

import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/auth/session_controller.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_detail_screen.dart';
import 'package:garagem_mobile/features/cars/car_form_screen.dart';
import 'package:garagem_mobile/features/cars/car_list.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';
import 'package:garagem_mobile/features/evolutions/evolution_detail_screen.dart';
import 'package:garagem_mobile/features/discovery/explore_screen.dart';
import 'package:garagem_mobile/features/discovery/search_screen.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/notifications/app_notification.dart';
import 'package:garagem_mobile/features/notifications/notifications_repository.dart';
import 'package:garagem_mobile/features/notifications/notifications_screen.dart';
import 'package:garagem_mobile/features/profile/profile_screen.dart';
import 'package:garagem_mobile/features/profile/public_profile_screen.dart';
import 'package:garagem_mobile/features/profile/users_repository.dart';
import 'package:garagem_mobile/features/teams/team.dart';
import 'package:garagem_mobile/features/teams/team_detail_screen.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';
import 'package:garagem_mobile/features/teams/teams_screen.dart';

final class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.session,
    required this.carsRepository,
    required this.evolutionsRepository,
    required this.notificationsRepository,
    required this.teamsRepository,
    required this.usersRepository,
    super.key,
  });

  final SessionController session;
  final CarsRepository carsRepository;
  final EvolutionsRepository evolutionsRepository;
  final NotificationsRepository notificationsRepository;
  final TeamsRepository teamsRepository;
  final UsersRepository usersRepository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

final class _HomeShellState extends State<HomeShell>
    with WidgetsBindingObserver {
  int _index = 0;
  int _feedRevision = 0;
  int _garageRevision = 0;
  int _teamsRevision = 0;
  int _profileRevision = 0;
  int _notificationsRevision = 0;
  int _unreadNotifications = 0;
  int _unreadRequest = 0;
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshUnreadNotifications());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      unawaited(_refreshUnreadNotifications());
      setState(() {
        _feedRevision++;
        _garageRevision++;
        _teamsRevision++;
        _notificationsRevision++;
      });
    }
  }

  Future<void> _refreshUnreadNotifications() async {
    final request = ++_unreadRequest;
    try {
      final count = await widget.notificationsRepository.unreadCount();
      if (mounted && request == _unreadRequest &&
          count != _unreadNotifications) {
        setState(() => _unreadNotifications = count);
      }
    } catch (_) {
      // A tela de atividade permite tentar novamente sem bloquear o app.
    }
  }

  void _setUnreadNotifications(int count) {
    _unreadRequest++;
    if (mounted && count != _unreadNotifications) {
      setState(() => _unreadNotifications = count);
    }
  }

  void _refreshCars() {
    setState(() {
      _feedRevision++;
      _garageRevision++;
    });
  }

  void _refreshFeed() {
    if (mounted) setState(() => _feedRevision++);
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
    _refreshFeed();
  }



  Future<void> _openNotification(AppNotification notification) async {
    try {
      if (notification.type == 'solicitacao_equipe_recusada') {
        if (mounted) setState(() => _index = 2);
        return;
      }
      if (notification.teamId != null) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => TeamDetailScreen(
              teamId: notification.teamId!,
              repository: widget.teamsRepository,
              carsRepository: widget.carsRepository,
              evolutionsRepository: widget.evolutionsRepository,
              currentUserId: widget.session.user!.id,
              usersRepository: widget.usersRepository,
            ),
          ),
        );
        return;
      }

      if (notification.carId != null && notification.evolutionId != null) {
        final evolution = await widget.evolutionsRepository.detail(
          notification.carId!,
          notification.evolutionId!,
        );
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => EvolutionDetailScreen(
              evolution: evolution,
              repository: widget.evolutionsRepository,
              currentUserId: widget.session.user!.id,
              highlightCommentId: notification.commentId,
              onProfileTap: _openPublicProfile,
            ),
          ),
        );
        return;
      }

      if (notification.actorId != null) {
        await _openPublicProfile(notification.actorId!);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
    }
  }

  Future<void> _openEvolution(Evolution evolution) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EvolutionDetailScreen(
          evolution: evolution,
          repository: widget.evolutionsRepository,
          currentUserId: widget.session.user!.id,
          onProfileTap: _openPublicProfile,
        ),
      ),
    );
    _refreshFeed();
  }

  Future<void> _openTeam(Team team) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TeamDetailScreen(
          teamId: team.id,
          repository: widget.teamsRepository,
          carsRepository: widget.carsRepository,
          evolutionsRepository: widget.evolutionsRepository,
          currentUserId: widget.session.user!.id,
          usersRepository: widget.usersRepository,
        ),
      ),
    );
  }

  Future<void> _openSearch({
    SearchCategory initialCategory = SearchCategory.projects,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          initialCategory: initialCategory,
          carsRepository: widget.carsRepository,
          usersRepository: widget.usersRepository,
          teamsRepository: widget.teamsRepository,
          onCarTap: (car) => _openCar(
            car,
            canManage: car.ownerId == widget.session.user!.id,
          ),
          onUserTap: _openPublicProfile,
          onTeamTap: _openTeam,
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
          onProfileTap: _openPublicProfile,
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
      ExploreScreen(
        refreshRevision: _feedRevision,
        carsRepository: widget.carsRepository,
        evolutionsRepository: widget.evolutionsRepository,
        onCarTap: (car) => _openCar(car, canManage: false),
        onEvolutionTap: _openEvolution,
        onProfileTap: _openPublicProfile,
        onSearch: () => _openSearch(),
      ),
      CarList(
        refreshRevision: _garageRevision,
        title: 'Garagem',
        mode: CarListMode.garage,
        emptyMessage: 'Adicione seu carro e comece a registrar a história dele.',
        loader: widget.carsRepository.mine,
        onCarTap: (car) => _openCar(car, canManage: true),
        primaryActionLabel: 'Adicionar carro',
        onPrimaryAction: _openCreateCar,
      ),
      TeamsScreen(
        refreshRevision: _teamsRevision,
        onSearch: () => _openSearch(initialCategory: SearchCategory.teams),
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
      NotificationsScreen(
        refreshRevision: _notificationsRevision,
        repository: widget.notificationsRepository,
        onUnreadChanged: _setUnreadNotifications,
        onOpen: _openNotification,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
            if (value == 0) _feedRevision++;
            if (value == 1) _garageRevision++;
            if (value == 2) _teamsRevision++;
            if (value == 3) _profileRevision++;
            if (value == 4) _notificationsRevision++;
          });
          unawaited(_refreshUnreadNotifications());
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explorar',
          ),
          const NavigationDestination(
            icon: Icon(Icons.garage_outlined),
            selectedIcon: Icon(Icons.garage),
            label: 'Garagem',
          ),
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Equipes',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _unreadNotifications > 0,
              label: Text(
                _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
              ),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _unreadNotifications > 0,
              label: Text(
                _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
              ),
              child: const Icon(Icons.notifications),
            ),
            label: 'Avisos',
          ),
        ],
      ),
    );
  }
}
