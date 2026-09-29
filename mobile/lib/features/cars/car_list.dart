import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/core/widgets/gd_premium.dart';
import 'package:garagem_mobile/features/cars/project_card.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';

enum CarListMode { explore, garage }

final class CarList extends StatefulWidget {
  const CarList({
    required this.title,
    required this.emptyMessage,
    required this.loader,
    required this.onCarTap,
    this.pageLoader,
    this.mode = CarListMode.explore,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.onSearch,
    this.embedded = false,
    this.refreshRevision = 0,
    super.key,
  }) : assert(onPrimaryAction == null || primaryActionLabel != null);

  final String title;
  final String emptyMessage;
  final Future<List<Car>> Function() loader;
  final Future<CarPage> Function(String? cursor)? pageLoader;
  final ValueChanged<Car> onCarTap;
  final CarListMode mode;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSearch;
  final bool embedded;
  final int refreshRevision;

  @override
  State<CarList> createState() => _CarListState();
}

class _CarListState extends State<CarList> {
  late Future<List<Car>> _cars;
  List<Car>? _lastCars;
  int _loadRequest = 0;
  String? _nextCursor;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;

  Future<List<Car>> _load() async {
    final request = ++_loadRequest;
    _nextCursor = null;
    _loadingMore = false;
    _loadMoreFailed = false;
    final page = await widget.pageLoader?.call(null);
    final cars = page?.items ?? await widget.loader();
    if (request == _loadRequest) {
      _lastCars = cars;
      _nextCursor = page?.nextCursor;
    }
    return cars;
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    final pageLoader = widget.pageLoader;
    if (cursor == null || pageLoader == null || _loadingMore) return;
    final request = _loadRequest;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    try {
      final page = await pageLoader(cursor);
      if (!mounted || request != _loadRequest) return;
      setState(() {
        final existing = _lastCars ?? const <Car>[];
        final ids = existing.map((car) => car.id).toSet();
        _lastCars = [
          ...existing,
          ...page.items.where((car) => ids.add(car.id)),
        ];
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _loadingMore = false;
        _loadMoreFailed = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _cars = _load();
  }

  @override
  void didUpdateWidget(covariant CarList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshRevision != oldWidget.refreshRevision) _cars = _load();
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() {
      _cars = next;
    });
    try {
      await next;
    } catch (_) {
      // O FutureBuilder mostra a falha e mantém os últimos cards carregados.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGarage = widget.mode == CarListMode.garage;
    final body = FutureBuilder<List<Car>>(
      future: _cars,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _lastCars == null) {
          return const GdSkeleton();
        }
        if (snapshot.hasError && _lastCars == null) {
          return _MessageState(
            icon: Icons.cloud_off_outlined,
            message: apiErrorMessage(snapshot.error!),
            actionLabel: 'Tentar novamente',
            onAction: _reload,
          );
        }

        final cars = _lastCars ?? snapshot.data ?? const <Car>[];
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (snapshot.hasError) ...[
                _RefreshError(onRetry: _reload),
                const SizedBox(height: 12),
              ],
              if (isGarage) ...[
                _GarageHeader(
                  carCount: cars.length,
                  onCreate: widget.onPrimaryAction,
                ),
                const SizedBox(height: 24),
              ],
              GdSectionTitle(
                title: isGarage ? 'Seus projetos' : 'Projetos para descobrir',
                trailing: Text(
                  cars.length.toString().padLeft(2, '0'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              if (cars.isEmpty)
                _EmptyGarage(
                  message: widget.emptyMessage,
                  isGarage: isGarage,
                  onCreate: widget.onPrimaryAction,
                )
              else
                for (var index = 0; index < cars.length; index++) ...[
                  GdReveal(
                    key: ValueKey(cars[index].id),
                    child: GdProjectCard(
                      car: cars[index],
                      highlighted: isGarage,
                      onTap: () => widget.onCarTap(cars[index]),
                    ),
                  ),
                  if (index != cars.length - 1) const SizedBox(height: 24),
                ],
              if (_nextCursor != null) ...[
                const SizedBox(height: 20),
                if (_loadMoreFailed)
                  const Center(
                    child: Text('Não foi possível carregar mais projetos.'),
                  ),
                if (_loadMoreFailed) const SizedBox(height: 8),
                Center(
                  child: _loadingMore
                      ? const CircularProgressIndicator()
                      : OutlinedButton(
                          onPressed: _loadMore,
                          child: Text(_loadMoreFailed
                              ? 'Tentar novamente'
                              : 'Carregar mais projetos'),
                        ),
                ),
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

final class _RefreshError extends StatelessWidget {
  const _RefreshError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.cloud_off_outlined),
        title: const Text('Não foi possível atualizar a lista.'),
        trailing: TextButton(
          onPressed: onRetry,
          child: const Text('Tentar novamente'),
        ),
      ),
    );
  }
}

final class _GarageHeader extends StatelessWidget {
  const _GarageHeader({required this.carCount, this.onCreate});

  final int carCount;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sua garagem, sua história',
          style: type.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Cada detalhe faz parte do seu projeto.',
          style: type.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(color: colors.primary, width: 3),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final summary = Row(
                children: [
                  Text(
                    carCount.toString().padLeft(2, '0'),
                    style: type.headlineLarge?.copyWith(color: colors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      carCount == 1
                          ? 'projeto na garagem'
                          : 'projetos na garagem',
                      style: type.bodySmall,
                    ),
                  ),
                ],
              );
              if (onCreate == null) return summary;
              final action = FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Adicionar'),
              );
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(14) > 17) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [summary, const SizedBox(height: 14), action],
                );
              }
              return Row(
                children: [
                  Expanded(child: summary),
                  const SizedBox(width: 14),
                  action,
                ],
              );
            },
          ),
        ),
      ],
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
  Widget build(BuildContext context) => GdEmptyState(
        icon: isGarage ? Icons.garage_outlined : Icons.travel_explore_outlined,
        title: message,
        action: onCreate == null
            ? null
            : FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar projeto')),
      );
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
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: GdEmptyState(
            icon: icon,
            title: message,
            action: onAction == null
                ? null
                : FilledButton(onPressed: onAction, child: Text(actionLabel!))),
      );
}
