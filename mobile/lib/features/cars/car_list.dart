import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/cars/car.dart';

enum CarListMode { explore, garage }

final class CarList extends StatefulWidget {
  const CarList({
    required this.title,
    required this.emptyMessage,
    required this.loader,
    required this.onCarTap,
    this.mode = CarListMode.explore,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.onSearch,
    this.embedded = false,
    super.key,
  }) : assert(onPrimaryAction == null || primaryActionLabel != null);

  final String title;
  final String emptyMessage;
  final Future<List<Car>> Function() loader;
  final ValueChanged<Car> onCarTap;
  final CarListMode mode;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSearch;
  final bool embedded;

  @override
  State<CarList> createState() => _CarListState();
}

class _CarListState extends State<CarList> {
  late Future<List<Car>> _cars;

  @override
  void initState() {
    super.initState();
    _cars = widget.loader();
  }

  Future<void> _reload() async {
    final next = widget.loader();
    setState(() => _cars = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final isGarage = widget.mode == CarListMode.garage;
    final body = FutureBuilder<List<Car>>(
        future: _cars,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_outlined,
              message: apiErrorMessage(snapshot.error!),
              actionLabel: 'Tentar novamente',
              onAction: _reload,
            );
          }

          final cars = snapshot.data ?? const <Car>[];
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _CarsHero(
                  mode: widget.mode,
                  carCount: cars.length,
                  onCreate: widget.onPrimaryAction,
                  onSearch: widget.onSearch,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isGarage ? 'Seus projetos' : 'Projetos para descobrir',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${cars.length}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (cars.isEmpty)
                  _EmptyGarage(
                    message: widget.emptyMessage,
                    isGarage: isGarage,
                    onCreate: widget.onPrimaryAction,
                  )
                else
                  for (var index = 0; index < cars.length; index++) ...[
                    _CarCard(
                      car: cars[index],
                      highlighted: isGarage,
                      onTap: () => widget.onCarTap(cars[index]),
                    ),
                    if (index != cars.length - 1)
                      const SizedBox(height: 14),
                  ],
              ],
            ),
          );
        },
      );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.onSearch != null)
            IconButton(
              onPressed: widget.onSearch,
              tooltip: 'Buscar',
              icon: const Icon(Icons.search_rounded),
            ),
          if (widget.onPrimaryAction != null)
            IconButton(
              onPressed: widget.onPrimaryAction,
              tooltip: widget.primaryActionLabel,
              icon: const Icon(Icons.add_circle_outline),
            ),
          if (widget.onPrimaryAction != null) const SizedBox(width: 8),
        ],
      ),
      body: body,
    );
  }
}

final class _CarsHero extends StatelessWidget {
  const _CarsHero({
    required this.mode,
    required this.carCount,
    this.onCreate,
    this.onSearch,
  });

  final CarListMode mode;
  final int carCount;
  final VoidCallback? onCreate;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isGarage = mode == CarListMode.garage;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(alpha: 0.9),
            colors.surfaceContainerHigh,
          ],
        ),
        border: Border.all(color: colors.primary.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isGarage ? Icons.garage_rounded : Icons.explore_rounded,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isGarage
                ? 'Sua garagem, sua história'
                : 'Máquinas que contam histórias',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            isGarage
                ? 'Organize seus projetos e registre cada etapa da evolução.'
                : 'Descubra projetos reais, acompanhe ideias e encontre novas inspirações.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
          if (!isGarage && onSearch != null) ...[
            const SizedBox(height: 18),
            Material(
              color: colors.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: onSearch,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: colors.primary),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'Buscar projetos, pessoas e equipes',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              _HeroStat(
                value: '$carCount',
                label: carCount == 1 ? 'projeto' : 'projetos',
              ),
              if (isGarage) ...[
                const Spacer(),
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

final class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

final class _CarCard extends StatelessWidget {
  const _CarCard({
    required this.car,
    required this.highlighted,
    required this.onTap,
  });

  final Car car;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final details = <(IconData, String)>[
      if (car.year != null) (Icons.calendar_today_outlined, '${car.year}'),
      if (car.engine != null) (Icons.settings_outlined, car.engine!),
      if (car.color != null) (Icons.palette_outlined, car.color!),
      if (car.likesCount > 0)
        (Icons.favorite_outline_rounded, '${car.likesCount}'),
      if (car.commentsCount > 0)
        (Icons.chat_bubble_outline_rounded, '${car.commentsCount}'),
    ];
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
            border: Border.all(
              color: highlighted
                  ? colors.primary.withValues(alpha: 0.42)
                  : colors.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 15, 13, 13),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: car.ownerAvatarUrl == null
                          ? null
                          : NetworkImage(car.ownerAvatarUrl!),
                      child: car.ownerAvatarUrl == null
                          ? Text(
                              ownerInitial,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${car.ownerUsername}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Icon(
                        Icons.arrow_outward_rounded,
                        size: 20,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              AspectRatio(
                aspectRatio: 16 / 10,
                child: car.photoUrl == null
                    ? ColoredBox(
                        color: colors.surfaceContainerHighest,
                        child: Icon(
                          Icons.directions_car_rounded,
                          size: 78,
                          color: colors.onSurfaceVariant,
                        ),
                      )
                    : Image.network(
                        car.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(
                          color: colors.surfaceContainerHighest,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 52,
                          ),
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primaryContainer.withValues(alpha: 0.42),
                      colors.surfaceContainer,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                highlighted
                                    ? 'SEU PROJETO'
                                    : 'PROJETO AUTOMOTIVO',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.1,
                                    ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                [car.model, car.year]
                                    .where((value) => value != null)
                                    .join(' '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                        if (car.projectStatus != null) ...[
                          const SizedBox(width: 12),
                          _StatusPill(label: car.projectStatus!),
                        ],
                      ],
                    ),
                    if (car.history != null && car.history!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        car.history!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.35,
                            ),
                      ),
                    ],
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 15),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final detail in details)
                            _MetaPill(icon: detail.$1, label: detail.$2),
                        ],
                      ),
                    ],
                    const SizedBox(height: 17),
                    Divider(color: colors.outlineVariant),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          size: 18,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Abrir projeto',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.primary,
                        ),
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

final class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

final class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.primary),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

final class _EmptyGarage extends StatelessWidget {
  const _EmptyGarage({
    required this.message,
    required this.isGarage,
    this.onCreate,
  });

  final String message;
  final bool isGarage;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            isGarage
                ? Icons.garage_outlined
                : Icons.travel_explore_outlined,
            size: 54,
          ),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
          if (onCreate != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar projeto'),
            ),
          ],
        ],
      ),
    );
  }
}

final class _MessageState extends StatelessWidget {
  const _MessageState({
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
