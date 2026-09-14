import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_detail_screen.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/profile/public_profile.dart';
import 'package:garagem_mobile/features/profile/social_users_screen.dart';
import 'package:garagem_mobile/features/profile/users_repository.dart';

typedef _ProfileData = ({PublicProfile profile, List<Car> cars});

final class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    required this.userId,
    required this.currentUserId,
    required this.usersRepository,
    required this.carsRepository,
    required this.evolutionsRepository,
    super.key,
  });

  final String userId;
  final String currentUserId;
  final UsersRepository usersRepository;
  final CarsRepository carsRepository;
  final EvolutionsRepository evolutionsRepository;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

final class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late Future<_ProfileData> _data;
  _ProfileData? _visibleData;
  bool _changingFollow = false;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_ProfileData> _load() async {
    final profile = await widget.usersRepository.profile(widget.userId);
    final cars = await widget.usersRepository.cars(widget.userId);
    return (profile: profile, cars: cars);
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() => _data = next);
    final loaded = await next;
    if (mounted) setState(() => _visibleData = loaded);
  }

  PublicProfile _withFollowState(
    PublicProfile profile, {
    required bool followed,
  }) {
    final difference = followed == profile.followedByMe
        ? 0
        : followed
            ? 1
            : -1;
    return PublicProfile(
      id: profile.id,
      name: profile.name,
      username: profile.username,
      projectCount: profile.projectCount,
      followerCount: profile.followerCount + difference,
      followingCount: profile.followingCount,
      followedByMe: followed,
      avatarUrl: profile.avatarUrl,
      bio: profile.bio,
      city: profile.city,
      state: profile.state,
    );
  }

  Future<void> _toggleFollow(_ProfileData data) async {
    final previous = data;
    final shouldFollow = !data.profile.followedByMe;
    final optimistic = (
      profile: _withFollowState(data.profile, followed: shouldFollow),
      cars: data.cars,
    );
    setState(() {
      _changingFollow = true;
      _visibleData = optimistic;
    });

    try {
      if (shouldFollow) {
        await widget.usersRepository.follow(data.profile.id);
      } else {
        await widget.usersRepository.unfollow(data.profile.id);
      }

      try {
        final confirmed = await widget.usersRepository.profile(data.profile.id);
        if (mounted) {
          setState(() {
            _visibleData = (profile: confirmed, cars: data.cars);
          });
        }
      } catch (_) {
        // A ação principal já terminou. A confirmação pode esperar o próximo
        // pull-to-refresh sem apresentar um falso erro ao usuário.
      }
    } catch (error) {
      try {
        final confirmed = await widget.usersRepository.profile(data.profile.id);
        if (!mounted) return;
        if (confirmed.followedByMe == shouldFollow) {
          setState(() {
            _visibleData = (profile: confirmed, cars: data.cars);
          });
          return;
        }
      } catch (_) {
        // Se nem a reconciliação responder, restauramos o estado anterior.
      }

      if (mounted) {
        setState(() => _visibleData = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _changingFollow = false);
    }
  }

  Future<void> _openProfile(String userId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: userId,
          currentUserId: widget.currentUserId,
          usersRepository: widget.usersRepository,
          carsRepository: widget.carsRepository,
          evolutionsRepository: widget.evolutionsRepository,
        ),
      ),
    );
  }

  Future<void> _openConnections(
    PublicProfile profile, {
    required bool following,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SocialUsersScreen(
          title: following ? 'Seguindo' : 'Seguidores',
          loader: () => following
              ? widget.usersRepository.following(profile.id)
              : widget.usersRepository.followers(profile.id),
          onUserTap: _openProfile,
        ),
      ),
    );
    if (mounted) await _reload();
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
    return FutureBuilder<_ProfileData>(
      future: _data,
      builder: (context, snapshot) {
        final data = _visibleData ?? snapshot.data;
        return Scaffold(
          appBar: AppBar(title: const Text('Perfil')),
          body: data != null
              ? RefreshIndicator(
                  onRefresh: _reload,
                  child: _content(data),
                )
              : snapshot.hasError
                  ? Center(
                      child: FilledButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                        label: Text(apiErrorMessage(snapshot.error!)),
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget _content(_ProfileData data) {
    final profile = data.profile;
    final colors = Theme.of(context).colorScheme;
    final isMe = profile.id == widget.currentUserId;
    final location = [profile.city, profile.state]
        .where((item) => item != null && item.isNotEmpty)
        .join(' · ');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [
                colors.primaryContainer,
                colors.surfaceContainerHigh,
              ],
            ),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 46,
                backgroundImage: profile.avatarUrl == null
                    ? null
                    : NetworkImage(profile.avatarUrl!),
                child: profile.avatarUrl == null
                    ? Text(
                        profile.name.substring(0, 1).toUpperCase(),
                        style: Theme.of(context).textTheme.headlineLarge,
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              Text(
                profile.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(
                '@${profile.username}',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 17),
                    const SizedBox(width: 4),
                    Text(location),
                  ],
                ),
              ],
              if (profile.bio != null) ...[
                const SizedBox(height: 14),
                Text(
                  profile.bio!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.4),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  _Stat(value: profile.projectCount, label: 'projetos'),
                  _Stat(
                    value: profile.followerCount,
                    label: 'seguidores',
                    onTap: () => _openConnections(
                      profile,
                      following: false,
                    ),
                  ),
                  _Stat(
                    value: profile.followingCount,
                    label: 'seguindo',
                    onTap: () => _openConnections(
                      profile,
                      following: true,
                    ),
                  ),
                ],
              ),
              if (!isMe) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: profile.followedByMe
                      ? OutlinedButton.icon(
                          onPressed: _changingFollow
                              ? null
                              : () => _toggleFollow(data),
                          icon: const Icon(Icons.person_remove_outlined),
                          label: const Text('Seguindo'),
                        )
                      : FilledButton.icon(
                          onPressed: _changingFollow
                              ? null
                              : () => _toggleFollow(data),
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Seguir'),
                        ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                'Projetos',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Text('${data.cars.length}'),
          ],
        ),
        const SizedBox(height: 14),
        if (data.cars.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              children: [
                Icon(Icons.garage_outlined, size: 44),
                SizedBox(height: 10),
                Text('Esta garagem ainda não tem projetos.'),
              ],
            ),
          )
        else
          for (final car in data.cars)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openCar(car),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 112,
                        height: 94,
                        child: car.photoUrl == null
                            ? ColoredBox(
                                color: colors.surfaceContainerHighest,
                                child: const Icon(
                                  Icons.directions_car,
                                  size: 38,
                                ),
                              )
                            : Image.network(
                                car.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image_outlined,
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [car.model, car.year]
                                  .whereType<Object>()
                                  .join(' '),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (car.projectStatus != null)
                              Text(
                                car.projectStatus!,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

final class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.onTap,
  });

  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(
                '$value',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
