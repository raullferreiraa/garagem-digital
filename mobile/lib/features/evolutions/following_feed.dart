import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/evolutions/following_feed_item.dart';

final class FollowingFeed extends StatefulWidget {
  const FollowingFeed({
    required this.repository,
    required this.onEvolutionTap,
    required this.onProfileTap,
    this.refreshRevision = 0,
    super.key,
  });

  final EvolutionsRepository repository;
  final Future<void> Function(Evolution) onEvolutionTap;
  final Future<void> Function(String) onProfileTap;
  final int refreshRevision;

  @override
  State<FollowingFeed> createState() => _FollowingFeedState();
}

final class _FollowingFeedState extends State<FollowingFeed> {
  late Future<List<FollowingFeedItem>> _items;
  List<FollowingFeedItem>? _lastItems;
  int _loadRequest = 0;

  Future<List<FollowingFeedItem>> _load() async {
    final request = ++_loadRequest;
    final items = await widget.repository.followingFeed();
    if (request == _loadRequest) _lastItems = items;
    return items;
  }

  @override
  void initState() {
    super.initState();
    _items = _load();
  }

  @override
  void didUpdateWidget(covariant FollowingFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshRevision != oldWidget.refreshRevision) _items = _load();
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() => _items = future);
    try {
      await future;
    } catch (_) {
      // O feed anterior continua visível e a tela oferece nova tentativa.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FollowingFeedItem>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _lastItems == null) {
          return const GdSkeleton();
        }
        if (snapshot.hasError && _lastItems == null) {
          return _FeedMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Não foi possível carregar',
            message: apiErrorMessage(snapshot.error!),
            actionLabel: 'Tentar novamente',
            onAction: _reload,
          );
        }
        final items =
            snapshot.data ?? _lastItems ?? const <FollowingFeedItem>[];
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              if (snapshot.hasError) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud_off_outlined),
                    title: const Text('Não foi possível atualizar o feed.'),
                    trailing: TextButton(
                      onPressed: _reload,
                      child: const Text('Tentar novamente'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (items.isEmpty)
                const _FeedMessage(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Acompanhe novas histórias',
                  message:
                      'Siga pessoas e as evoluções recentes dos projetos delas aparecerão aqui.',
                )
              else ...[
                GdSectionTitle(
                  title: 'Atualizações recentes',
                  eyebrow: 'DA SUA COMUNIDADE',
                  trailing: Text(
                    items.length.toString().padLeft(2, '0'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 20),
                for (var index = 0; index < items.length; index++) ...[
                  GdReveal(
                    key: ValueKey(items[index].evolution.id),
                    child: _EvolutionFeedCard(
                      item: items[index],
                      onTap: () =>
                          widget.onEvolutionTap(items[index].evolution),
                      onProfileTap: () =>
                          widget.onProfileTap(items[index].car.ownerId),
                    ),
                  ),
                  if (index != items.length - 1) const SizedBox(height: 24),
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
    final imageUrl =
        evolution.photos.isNotEmpty ? evolution.photos.first.url : car.photoUrl;

    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
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
                      child: GdAvatar(
                        size: 38,
                        url: car.ownerAvatarUrl,
                        name: car.ownerName,
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
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        _date(evolution.timelineDate),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              if (imageUrl != null)
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: GdImage(
                    url: imageUrl,
                    semanticLabel: evolution.title,
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
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      evolution.title,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
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
                    const SizedBox(height: 18),
                    Divider(height: 1, color: colors.outlineVariant),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          'Abrir evolução',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_outward_rounded,
                            size: 18, color: colors.primary),
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
