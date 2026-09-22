import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/widgets/gd_navigation.dart';
import 'package:garagem_mobile/core/widgets/gd_activity_action.dart';
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
import 'package:garagem_mobile/features/messages/conversations_screen.dart';
import 'package:garagem_mobile/features/messages/messages_repository.dart';
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
    required this.messagesRepository,
    required this.notificationsRepository,
    required this.teamsRepository,
    required this.usersRepository,
    super.key,
  });

  final SessionController session;
  final CarsRepository carsRepository;
  final EvolutionsRepository evolutionsRepository;
  final MessagesRepository messagesRepository;
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
  int _messagesRevision = 0;
  int _profileRevision = 0;
  final _notificationsRevision = ValueNotifier<int>(0);
  bool _activityOpen = false;
  int _unreadNotifications = 0;
  int _unreadMessages = 0;
  int _unreadRequest = 0;
  int _unreadMessagesRequest = 0;
  bool _wasBackgrounded = false;
  Timer? _messagesBadgeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshUnreadNotifications());
    unawaited(_refreshUnreadMessages());
    _messagesBadgeTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_refreshUnreadMessages()),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messagesBadgeTimer?.cancel();
    _notificationsRevision.dispose();
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
      unawaited(_refreshUnreadMessages());
      setState(() {
        _feedRevision++;
        _garageRevision++;
        _teamsRevision++;
        _messagesRevision++;
      });
      _notificationsRevision.value++;
    }
  }

  Future<void> _refreshUnreadNotifications() async {
    final request = ++_unreadRequest;
    try {
      final count = await widget.notificationsRepository.unreadCount();
      if (mounted &&
          request == _unreadRequest &&
          count != _unreadNotifications) {
        setState(() => _unreadNotifications = count);
      }
    } catch (_) {
      // A tela de atividade permite tentar novamente sem bloquear o app.
    }
  }

  Future<void> _refreshUnreadMessages() async {
    final request = ++_unreadMessagesRequest;
    try {
      final count = await widget.messagesRepository.unreadCount();
      if (mounted &&
          request == _unreadMessagesRequest &&
          count != _unreadMessages) {
        setState(() => _unreadMessages = count);
      }
    } catch (_) {
      // A caixa de entrada permite tentar novamente sem bloquear o app.
    }
  }

  void _refreshCars() {
    setState(() {
      _feedRevision++;
      _garageRevision++;
    });
  }

  Future<void> _openActivity() async {
    if (_activityOpen) return;
    _activityOpen = true;
    try {
      await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => ValueListenableBuilder<int>(
          valueListenable: _notificationsRevision,
          builder: (activityContext, revision, __) => NotificationsScreen(
            refreshRevision: revision,
            repository: widget.notificationsRepository,
            onUnreadChanged: (_) => unawaited(_refreshUnreadNotifications()),
            onOpen: (item) => _openNotification(item, activityContext),
          ),
        ),
      ));
    } finally {
      _activityOpen = false;
      if (mounted) unawaited(_refreshUnreadNotifications());
    }
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
          messagesRepository: widget.messagesRepository,
          onConversationChanged: _refreshUnreadMessages,
        ),
      ),
    );
    _refreshFeed();
  }

  Future<void> _openNotification(
      AppNotification notification, BuildContext activityContext) async {
    if (!mounted ||
        !activityContext.mounted ||
        ModalRoute.of(activityContext)?.isCurrent != true) return;
    try {
      if (notification.type == 'solicitacao_equipe_recusada') {
        if (mounted) {
          Navigator.of(context).pop();
          setState(() {
            _index = 2;
            _teamsRevision++;
          });
        }
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
              messagesRepository: widget.messagesRepository,
              onConversationChanged: _refreshUnreadMessages,
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
        if (!mounted ||
            !activityContext.mounted ||
            ModalRoute.of(activityContext)?.isCurrent != true) return;
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
      if (!mounted ||
          !activityContext.mounted ||
          ModalRoute.of(activityContext)?.isCurrent != true) return;
      ScaffoldMessenger.of(activityContext).showSnackBar(
        SnackBar(content: Text(_notificationError(notification, error))),
      );
    }
  }

  String _notificationError(AppNotification notification, Object error) {
    final unavailable =
        error is DioException && error.response?.statusCode == 404;
    if (!unavailable) return apiErrorMessage(error);
    if (notification.evolutionId != null) {
      return 'Esta evolução não está mais disponível.';
    }
    if (notification.carId != null) {
      return 'Este projeto não está mais disponível.';
    }
    if (notification.teamId != null) {
      return 'Esta equipe não está mais disponível.';
    }
    return 'Este conteúdo não está mais disponível.';
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
          messagesRepository: widget.messagesRepository,
          onConversationChanged: _refreshUnreadMessages,
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
        emptyMessage:
            'Adicione seu carro e comece a registrar a história dele.',
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
        messagesRepository: widget.messagesRepository,
        onConversationChanged: _refreshUnreadMessages,
      ),
      ConversationsScreen(
        active: _index == 3,
        refreshRevision: _messagesRevision,
        repository: widget.messagesRepository,
        currentUserId: widget.session.user!.id,
        onUnreadChanged: _refreshUnreadMessages,
        onProfileTap: _openPublicProfile,
        onDiscover: () => setState(() => _index = 0),
      ),
      ProfileScreen(
        key: ValueKey('profile-$_profileRevision'),
        session: widget.session,
        carsRepository: widget.carsRepository,
        evolutionsRepository: widget.evolutionsRepository,
        usersRepository: widget.usersRepository,
        messagesRepository: widget.messagesRepository,
        onConversationChanged: _refreshUnreadMessages,
      ),
    ];

    return Scaffold(
      body: GdActivityScope(
          unreadCount: _unreadNotifications,
          onOpen: _openActivity,
          child: IndexedStack(index: _index, children: [
            for (var i = 0; i < pages.length; i++)
              TickerMode(enabled: i == _index, child: pages[i]),
          ])),
      bottomNavigationBar: GdNavigation(
        selectedIndex: _index,
        unreadMessages: _unreadMessages,
        onSelected: (value) {
          setState(() {
            _index = value;
            if (value == 0) _feedRevision++;
            if (value == 1) _garageRevision++;
            if (value == 2) _teamsRevision++;
            if (value == 3) _messagesRevision++;
            if (value == 4) _profileRevision++;
          });
          unawaited(_refreshUnreadNotifications());
          unawaited(_refreshUnreadMessages());
        },
      ),
    );
  }
}
