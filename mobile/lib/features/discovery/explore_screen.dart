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
    super.key,
  });

  final CarsRepository carsRepository;
  final EvolutionsRepository evolutionsRepository;
  final Future<void> Function(Car) onCarTap;
  final Future<void> Function(Evolution) onEvolutionTap;
  final Future<void> Function(String) onProfileTap;
  final VoidCallback onSearch;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

final class _ExploreScreenState extends State<ExploreScreen> {
  _ExploreView _view = _ExploreView.discover;

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
              segments: const [
                ButtonSegment(
                  value: _ExploreView.discover,
                  icon: Icon(Icons.travel_explore_rounded),
                  label: Text('Descobrir'),
                ),
                ButtonSegment(
                  value: _ExploreView.following,
                  icon: Icon(Icons.people_alt_outlined),
                  label: Text('Seguindo'),
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
                  ? CarList(
                      key: const ValueKey('discover-projects'),
                      title: 'Explorar',
                      mode: CarListMode.explore,
                      embedded: true,
                      emptyMessage: 'Os primeiros projetos aparecerão aqui.',
                      loader: widget.carsRepository.feed,
                      onCarTap: widget.onCarTap,
                      onSearch: widget.onSearch,
                    )
                  : FollowingFeed(
                      key: const ValueKey('following-evolutions'),
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
