import 'dart:async';

import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/config/app_config.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/auth/session_controller.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_detail_screen.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/profile/edit_profile_screen.dart';
import 'package:garagem_mobile/features/profile/public_profile.dart';
import 'package:garagem_mobile/features/profile/public_profile_screen.dart';
import 'package:garagem_mobile/features/profile/social_users_screen.dart';
import 'package:garagem_mobile/features/profile/users_repository.dart';

final class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.session,
    required this.carsRepository,
    required this.evolutionsRepository,
    required this.usersRepository,
    super.key,
  });

  final SessionController session;
  final CarsRepository carsRepository;
  final EvolutionsRepository evolutionsRepository;
  final UsersRepository usersRepository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

final class _ProfileScreenState extends State<ProfileScreen> {
  late Future<List<Car>> _cars;
  PublicProfile? _socialProfile;

  @override
  void initState() {
    super.initState();
    _cars = widget.carsRepository.mine();
    unawaited(_loadSocialProfile());
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
    final next = widget.carsRepository.mine();
    setState(() => _cars = next);
    await Future.wait<Object?>([next, _loadSocialProfile()]);
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
        ),
      ),
    );
    if (mounted) await _reload();
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

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
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
          final cars = snapshot.data ?? const <Car>[];
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
              children: [
                _ProfileHero(
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
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Meus projetos',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      _CountBadge(count: cars.length),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'As máquinas que contam a sua história.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                if (snapshot.hasError)
                  _ProfileMessage(
                    icon: Icons.cloud_off_outlined,
                    message: apiErrorMessage(snapshot.error!),
                    actionLabel: 'Tentar novamente',
                    onAction: _reload,
                  )
                else if (snapshot.connectionState != ConnectionState.waiting &&
                    cars.isEmpty)
                  const _ProfileMessage(
                    icon: Icons.garage_outlined,
                    message: 'Sua garagem ainda não tem nenhum projeto.',
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
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(Icons.alternate_email),
                  title: const Text('Username'),
                  subtitle: Text('@${user.username}'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('E-mail da conta'),
                  subtitle: Text(user.email),
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
    final location = [city, state]
        .where((value) => value != null && value.isNotEmpty)
        .join(' - ');
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7A351F), Color(0xFF36231F)],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF9B5B47)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(name: name, avatarUrl: avatarUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '@$username',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 18),
                          const SizedBox(width: 5),
                          Expanded(child: Text(location)),
                        ],
                      ),
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
                : 'Conte um pouco sobre você e sua relação com carros.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _ProfileSocialStat(
                value: followersCount,
                label: 'seguidores',
                onTap: onFollowers,
              ),
              const SizedBox(width: 10),
              _ProfileSocialStat(
                value: followingCount,
                label: 'seguindo',
                onTap: onFollowing,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.garage_outlined),
                      const SizedBox(width: 10),
                      Text(
                        '$projectsCount ${projectsCount == 1 ? 'projeto' : 'projetos'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _ProfileSocialStat extends StatelessWidget {
  const _ProfileSocialStat({
    required this.value,
    required this.label,
    required this.onTap,
  });

  final int value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF8D3E24),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFFFAE96)),
      ),
      child: avatarUrl == null
          ? Center(
              child: Text(
                name.substring(0, 1).toUpperCase(),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            )
          : Image.network(
              avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 42),
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
    final title = [car.model, car.year]
        .where((value) => value != null)
        .join(' ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 124,
              height: 112,
              child: car.photoUrl == null
                  ? const ColoredBox(
                      color: Color(0xFF24262A),
                      child: Icon(Icons.directions_car_rounded, size: 44),
                    )
                  : Image.network(
                      car.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFF24262A),
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (car.projectStatus != null) ...[
                      const SizedBox(height: 8),
                      Text(car.projectStatus!),
                    ],
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Icon(Icons.chevron_right),
            ),
          ],
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
