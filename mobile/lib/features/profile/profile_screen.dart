import 'dart:async';

import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/config/app_config.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/sharing/gd_share.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/auth/session_controller.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_detail_screen.dart';
import 'package:garagem_mobile/features/cars/car_form_screen.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/cars/saved_projects_screen.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/messages/messages_repository.dart';
import 'package:garagem_mobile/features/profile/edit_profile_screen.dart';
import 'package:garagem_mobile/features/profile/blocked_users_screen.dart';
import 'package:garagem_mobile/features/profile/public_profile.dart';
import 'package:garagem_mobile/features/profile/public_profile_screen.dart';
import 'package:garagem_mobile/features/profile/security_screen.dart';
import 'package:garagem_mobile/features/profile/social_users_screen.dart';
import 'package:garagem_mobile/features/profile/users_repository.dart';
import 'package:garagem_mobile/features/sharing/share_content.dart';
import 'package:garagem_mobile/features/teams/team_detail_screen.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

final class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.session,
    required this.carsRepository,
    required this.evolutionsRepository,
    required this.usersRepository,
    required this.messagesRepository,
    required this.teamsRepository,
    required this.onConversationChanged,
    super.key,
  });

  final SessionController session;
  final CarsRepository carsRepository;
  final EvolutionsRepository evolutionsRepository;
  final UsersRepository usersRepository;
  final MessagesRepository messagesRepository;
  final TeamsRepository teamsRepository;
  final VoidCallback onConversationChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

final class _ProfileScreenState extends State<ProfileScreen> {
  late Future<List<Car>> _cars;
  List<Car> _visibleCars = const [];
  final Map<String, Car> _optimisticCars = {};
  int _carsRevision = 0;
  PublicProfile? _socialProfile;

  @override
  void initState() {
    super.initState();
    _cars = _loadCars();
    unawaited(_loadSocialProfile());
  }

  Future<List<Car>> _loadCars() async {
    final revision = ++_carsRevision;
    final remote = await widget.carsRepository.mine();
    if (!mounted || revision != _carsRevision) return _visibleCars;
    final remoteIds = remote.map((car) => car.id).toSet();
    _optimisticCars.removeWhere((id, _) => remoteIds.contains(id));
    final merged = [
      ..._optimisticCars.values,
      ...remote.where((car) => !_optimisticCars.containsKey(car.id)),
    ];
    _visibleCars = merged;
    return merged;
  }

  Future<void> _loadSocialProfile() async {
    try {
      final profile = await widget.usersRepository.profile(
        widget.session.user!.id,
      );
      if (mounted) setState(() => _socialProfile = profile);
    } catch (error, stackTrace) {
      debugPrint('Falha ao carregar dados sociais: $error\n$stackTrace');
    }
  }

  Future<void> _reload() async {
    final next = _loadCars();
    setState(() {
      _cars = next;
    });
    try {
      await Future.wait<Object?>([next, _loadSocialProfile()]);
    } catch (_) {
      // O FutureBuilder apresenta o erro e permite tentar novamente.
    }
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
          teamsRepository: widget.teamsRepository,
          onConversationChanged: widget.onConversationChanged,
        ),
      ),
    );
    if (mounted) await _loadSocialProfile();
  }

  Future<void> _openConnections({required bool following}) async {
    final userId = widget.session.user!.id;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SocialUsersScreen(
          title: following ? 'Seguindo' : 'Seguidores',
          loader: () => following
              ? widget.usersRepository.following(userId)
              : widget.usersRepository.followers(userId),
          onUserTap: _openPublicProfile,
        ),
      ),
    );
    if (mounted) await _loadSocialProfile();
  }

  Future<void> _editProfile() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(session: widget.session),
      ),
    );
    if (changed != true || !mounted) return;
    await _loadSocialProfile();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil atualizado.')),
    );
  }

  Future<void> _openCar(Car car) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CarDetailScreen(
          car: car,
          repository: widget.carsRepository,
          evolutionsRepository: widget.evolutionsRepository,
          canManage: true,
          currentUserId: widget.session.user!.id,
          onProfileTap: _openPublicProfile,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _openTeam(ProfileTeam team) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => TeamDetailScreen(
        teamId: team.id,
        repository: widget.teamsRepository,
        carsRepository: widget.carsRepository,
        evolutionsRepository: widget.evolutionsRepository,
        currentUserId: widget.session.user!.id,
        usersRepository: widget.usersRepository,
        messagesRepository: widget.messagesRepository,
        onConversationChanged: widget.onConversationChanged,
      ),
    ));
    if (mounted) await _loadSocialProfile();
  }

  Future<void> _createCar() async {
    final created = await Navigator.of(context).push<Car>(
      MaterialPageRoute(
        builder: (_) => CarFormScreen(repository: widget.carsRepository),
      ),
    );
    if (created == null || !mounted) return;
    ++_carsRevision;
    _optimisticCars[created.id] = created;
    final visible = [
      created,
      ..._visibleCars.where((car) => car.id != created.id),
    ];
    setState(() {
      _visibleCars = visible;
      _cars = Future.value(visible);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Projeto adicionado à sua garagem.')),
    );
    unawaited(_reload());
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Você precisará entrar novamente para acessar sua garagem.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (shouldLogout == true) await widget.session.logout();
  }

  Future<void> _openSecurity() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SecurityScreen(session: widget.session),
      ),
    );
  }

  Future<void> _openSavedProjects() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => SavedProjectsScreen(
        repository: widget.carsRepository,
        evolutionsRepository: widget.evolutionsRepository,
        currentUserId: widget.session.user!.id,
        onProfileTap: _openPublicProfile,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            onPressed: _openSavedProjects,
            tooltip: 'Projetos salvos',
            icon: const Icon(Icons.bookmark_border_rounded),
          ),
          GdShareAction(
            payload: ShareContent.profileValues(
              name: user.name,
              username: user.username,
              projectCount: _socialProfile?.projectCount,
            ),
            tooltip: 'Compartilhar perfil',
          ),
          IconButton(
            onPressed: _editProfile,
            tooltip: 'Editar perfil',
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<Car>>(
        future: _cars,
        builder: (context, snapshot) {
          final cars = _visibleCars;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
              children: [
                GdReveal(
                    child: _ProfileHero(
                  name: user.name,
                  username: user.username,
                  bio: user.bio,
                  city: user.city,
                  state: user.state,
                  avatarUrl: AppConfig.resolveApiUrl(user.avatarUrl),
                  projectsCount: cars.length,
                  followersCount: _socialProfile?.followerCount ?? 0,
                  followingCount: _socialProfile?.followingCount ?? 0,
                  onFollowers: () => _openConnections(following: false),
                  onFollowing: () => _openConnections(following: true),
                  onEdit: _editProfile,
                )),
                if (_socialProfile?.team case final team?) ...[
                  const SizedBox(height: 24),
                  const GdSectionTitle(
                      title: 'Minha equipe', eyebrow: 'NA MESMA PISTA'),
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: GdAvatar(
                          name: team.name, url: team.avatarUrl, size: 48),
                      title: Text(team.name),
                      subtitle: const Text('Ver equipe'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openTeam(team),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                GdSectionTitle(
                  title: 'Minha coleção',
                  eyebrow: 'FEITO DO SEU JEITO',
                  trailing: snapshot.connectionState == ConnectionState.waiting
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _CountBadge(count: cars.length),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _createCar,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar projeto'),
                  ),
                ),
                const SizedBox(height: 16),
                if (snapshot.hasError)
                  _ProfileMessage(
                    icon: Icons.cloud_off_outlined,
                    message: apiErrorMessage(snapshot.error!),
                    actionLabel: 'Tentar novamente',
                    onAction: _reload,
                  )
                else if (snapshot.connectionState == ConnectionState.waiting &&
                    cars.isEmpty)
                  const SizedBox(
                    height: 260,
                    child: GdSkeleton(compact: true),
                  )
                else if (snapshot.connectionState != ConnectionState.waiting &&
                    cars.isEmpty)
                  _ProfileMessage(
                    icon: Icons.garage_outlined,
                    message: 'Sua garagem ainda não tem nenhum projeto.',
                    actionLabel: 'Adicionar projeto',
                    onAction: _createCar,
                  )
                else
                  ...cars.map(
                    (car) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ProjectCard(
                        car: car,
                        onTap: () => _openCar(car),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 20),
                const GdSectionTitle(title: 'Sua conta', eyebrow: 'SÓ VOCÊ VÊ'),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(Icons.alternate_email),
                  title: const Text('Nome de usuário'),
                  subtitle: Text('@${user.username}'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('E-mail da conta'),
                  subtitle: Text(user.email),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Senha e segurança'),
                  subtitle: const Text('Proteja o acesso à sua garagem'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openSecurity,
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(Icons.block_outlined),
                  title: const Text('Perfis bloqueados'),
                  subtitle: const Text('Gerencie quem você bloqueou'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => BlockedUsersScreen(
                        repository: widget.usersRepository,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair da conta'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

final class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.username,
    required this.bio,
    required this.city,
    required this.state,
    required this.avatarUrl,
    required this.projectsCount,
    required this.followersCount,
    required this.followingCount,
    required this.onFollowers,
    required this.onFollowing,
    required this.onEdit,
  });

  final String name;
  final String username;
  final String? bio;
  final String? city;
  final String? state;
  final String? avatarUrl;
  final int projectsCount;
  final int followersCount;
  final int followingCount;
  final VoidCallback onFollowers;
  final VoidCallback onFollowing;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final location = [city, state]
        .where((value) => value != null && value.isNotEmpty)
        .join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(
              'QUEM ESTÁ AO VOLANTE',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 2,
                color: colors.primary,
              ),
            )),
            Icon(Icons.sports_motorsports_outlined,
                color: colors.primary, size: 24),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GdAvatar(name: name, url: avatarUrl, size: 88),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.headlineLarge),
                  const SizedBox(height: 3),
                  Text('@$username',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.primary,
                      )),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: colors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(
                        location,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: colors.onSurfaceVariant),
                      )),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          bio?.isNotEmpty == true
              ? bio!
              : 'Sua história também faz parte do projeto. Adicione uma bio.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: colors.onSurfaceVariant, height: 1.6),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: colors.outlineVariant),
              bottom: BorderSide(color: colors.outlineVariant),
            ),
          ),
          child: Row(children: [
            _ProfileSocialStat(value: projectsCount, label: 'projetos'),
            _ProfileSocialStat(
                value: followersCount, label: 'seguidores', onTap: onFollowers),
            _ProfileSocialStat(
                value: followingCount, label: 'seguindo', onTap: onFollowing),
          ]),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Editar perfil'),
          ),
        ),
      ],
    );
  }
}

final class _ProfileSocialStat extends StatelessWidget {
  const _ProfileSocialStat(
      {required this.value, required this.label, this.onTap});

  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Column(children: [
            Text('$value', style: theme.textTheme.headlineMedium),
            Text(label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ]),
        ),
      ),
    );
  }
}

final class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.car, required this.onTap});

  final Car car;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title =
        [car.model, car.year].where((value) => value != null).join(' ');
    return GdReveal(
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: GdImage(url: car.photoUrl, semanticLabel: title),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (car.projectStatus != null) ...[
                        Text(
                          car.projectStatus!.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                      ],
                      Text(title, style: theme.textTheme.titleLarge),
                    ],
                  )),
                  const SizedBox(width: 12),
                  Icon(Icons.north_east_rounded,
                      color: theme.colorScheme.primary, size: 22),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

final class _ProfileMessage extends StatelessWidget {
  const _ProfileMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onAction != null) ...[
              const SizedBox(height: 16),
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
