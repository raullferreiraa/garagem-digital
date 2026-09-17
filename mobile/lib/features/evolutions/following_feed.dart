import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/evolutions/following_feed_item.dart';

final class FollowingFeed extends StatefulWidget {
  const FollowingFeed({
    required this.repository,
    required this.onEvolutionTap,
    required this.onProfileTap,
    super.key,
  });

  final EvolutionsRepository repository;
  final Future<void> Function(Evolution) onEvolutionTap;
  final Future<void> Function(String) onProfileTap;

  @override
  State<FollowingFeed> createState() => _FollowingFeedState();
}

final class _FollowingFeedState extends State<FollowingFeed> {
  late Future<List<FollowingFeedItem>> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.repository.followingFeed();
  }

  Future<void> _reload() async {
    final future = widget.repository.followingFeed();
    setState(() => _items = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FollowingFeedItem>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _FeedMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Não foi possível carregar',
            message: apiErrorMessage(snapshot.error!),
            actionLabel: 'Tentar novamente',
            onAction: _reload,
          );
        }
        final items = snapshot.data ?? const <FollowingFeedItem>[];
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (items.isEmpty)
                const _FeedMessage(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Acompanhe novas histórias',
                  message:
                      'Siga pessoas e as evoluções recentes dos projetos delas aparecerão aqui.',
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Atualizações recentes',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    Text(
                      '${items.length}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < items.length; index++) ...[
                  _EvolutionFeedCard(
                    item: items[index],
                    onTap: () => widget.onEvolutionTap(items[index].evolution),
                    onProfileTap: () =>
                        widget.onProfileTap(items[index].car.ownerId),
                  ),
                  if (index != items.length - 1) const SizedBox(height: 14),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

final class _EvolutionFeedCard extends StatelessWidget {
  const _EvolutionFeedCard({
    required this.item,
    required this.onTap,
    required this.onProfileTap,
  });

  final FollowingFeedItem item;
  final VoidCallback onTap;
  final VoidCallback onProfileTap;

  String _date(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final evolution = item.evolution;
    final car = item.car;
    final imageUrl = evolution.photos.isNotEmpty
        ? evolution.photos.first.url
        : car.photoUrl;
    final ownerInitial =
        car.ownerName.isEmpty ? '?' : car.ownerName[0].toUpperCase();

    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                child: Row(
                  children: [
                    InkWell(
                      onTap: onProfileTap,
                      customBorder: const CircleBorder(),
                      child: CircleAvatar(
                        radius: 21,
                        backgroundImage: car.ownerAvatarUrl == null
                            ? null
                            : NetworkImage(car.ownerAvatarUrl!),
                        child: car.ownerAvatarUrl == null
                            ? Text(ownerInitial)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: InkWell(
                        onTap: onProfileTap,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@${car.ownerUsername}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              [car.model, car.year]
                                  .where((value) => value != null)
                                  .join(' '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      _date(evolution.timelineDate),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              if (imageUrl != null)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: colors.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (evolution.category != null) ...[
                      Text(
                        (evolutionCategoryLabels[evolution.category] ??
                                evolution.category!)
                            .toUpperCase(),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      evolution.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      evolution.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 18,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Abrir evolução',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded, color: colors.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _FeedMessage extends StatelessWidget {
  const _FeedMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 90, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (onAction != null) ...[
              const SizedBox(height: 18),
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
