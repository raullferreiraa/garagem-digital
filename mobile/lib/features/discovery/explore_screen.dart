import 'package:flutter/material.dart';
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text(
                'Ordenar por',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Spacer(),
              ChoiceChip(
                label: const Text('Recentes'),
                avatar: const Icon(Icons.schedule_rounded, size: 18),
                selected: _discoverOrder == CarFeedOrder.recent,
                showCheckmark: false,
                onSelected: (_) {
                  setState(() => _discoverOrder = CarFeedOrder.recent);
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Em alta'),
                avatar: const Icon(Icons.local_fire_department_outlined, size: 18),
                selected: _discoverOrder == CarFeedOrder.trending,
                showCheckmark: false,
                onSelected: (_) {
                  setState(() => _discoverOrder = CarFeedOrder.trending);
                },
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<_ExploreView>(
              expandedInsets: EdgeInsets.zero,
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _ExploreView.following,
                  icon: Icon(Icons.people_alt_outlined),
                  label: Text('Seguindo'),
                ),
                ButtonSegment(
                  value: _ExploreView.discover,
                  icon: Icon(Icons.travel_explore_rounded),
                  label: Text('Descobrir'),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (selection) {
                setState(() => _view = selection.first);
              },
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
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
