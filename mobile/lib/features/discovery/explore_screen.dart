import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/widgets/gd_activity_action.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_list.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/evolutions/following_feed.dart';

enum _ExploreView { discover, following }

final class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    required this.carsRepository,
    required this.evolutionsRepository,
    required this.onCarTap,
    required this.onEvolutionTap,
    required this.onProfileTap,
    required this.onSearch,
    required this.refreshRevision,
    super.key,
  });

  final CarsRepository carsRepository;
  final EvolutionsRepository evolutionsRepository;
  final Future<void> Function(Car) onCarTap;
  final Future<void> Function(Evolution) onEvolutionTap;
  final Future<void> Function(String) onProfileTap;
  final VoidCallback onSearch;
  final int refreshRevision;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

final class _ExploreScreenState extends State<ExploreScreen> {
  _ExploreView _view = _ExploreView.discover;
  CarFeedOrder _discoverOrder = CarFeedOrder.recent;

  Widget _discoverProjects() {
    return Column(
      key: const ValueKey('discover-projects'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: _OrderButton(
                  label: 'Recentes',
                  icon: Icons.schedule_rounded,
                  selected: _discoverOrder == CarFeedOrder.recent,
                  onTap: () {
                    setState(() => _discoverOrder = CarFeedOrder.recent);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OrderButton(
                  label: 'Em alta',
                  icon: Icons.local_fire_department_outlined,
                  selected: _discoverOrder == CarFeedOrder.trending,
                  onTap: () {
                    setState(() => _discoverOrder = CarFeedOrder.trending);
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: CarList(
            key: ValueKey('discover-${_discoverOrder.name}'),
            refreshRevision: widget.refreshRevision,
            title: 'Explorar',
            mode: CarListMode.explore,
            embedded: true,
            emptyMessage: 'Os primeiros projetos aparecerão aqui.',
            loader: () => widget.carsRepository.feed(order: _discoverOrder),
            pageLoader: _discoverOrder == CarFeedOrder.recent
                ? (cursor) => widget.carsRepository.feedPage(cursor: cursor)
                : null,
            onCarTap: widget.onCarTap,
            onSearch: widget.onSearch,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar'),
        actions: [
          const GdActivityAction(),
          IconButton(
            onPressed: widget.onSearch,
            tooltip: 'Buscar',
            icon: const Icon(Icons.search_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: _ExploreTab(
                    label: 'Descobrir',
                    selected: _view == _ExploreView.discover,
                    onTap: () => setState(() => _view = _ExploreView.discover),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _ExploreTab(
                    label: 'Seguindo',
                    selected: _view == _ExploreView.following,
                    onTap: () => setState(() => _view = _ExploreView.following),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              child: _view == _ExploreView.discover
                  ? _discoverProjects()
                  : FollowingFeed(
                      key: const ValueKey('following-evolutions'),
                      refreshRevision: widget.refreshRevision,
                      repository: widget.evolutionsRepository,
                      onEvolutionTap: widget.onEvolutionTap,
                      onProfileTap: widget.onProfileTap,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ExploreTab extends StatelessWidget {
  const _ExploreTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color:
                          selected ? colors.onSurface : colors.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
              ),
            ),
            AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              height: selected ? 3 : 1,
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}

final class _OrderButton extends StatelessWidget {
  const _OrderButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? colors.primary : colors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color:
                        selected ? colors.onPrimary : colors.onSurfaceVariant),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: selected ? colors.onPrimary : colors.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
