import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_detail_screen.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';

final class SavedProjectsScreen extends StatefulWidget {
  const SavedProjectsScreen({
    required this.repository,
    required this.evolutionsRepository,
    required this.currentUserId,
    required this.onProfileTap,
    super.key,
  });

  final CarsRepository repository;
  final EvolutionsRepository evolutionsRepository;
  final String currentUserId;
  final ValueChanged<String> onProfileTap;

  @override
  State<SavedProjectsScreen> createState() => _SavedProjectsScreenState();
}

final class _SavedProjectsScreenState extends State<SavedProjectsScreen> {
  final List<Car> _items = [];
  String? _nextCursor;
  Object? _error;
  bool _loading = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.saved(
        cursor: reset ? null : _nextCursor,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        final known = _items.map((item) => item.id).toSet();
        _items.addAll(page.items.where((item) => known.add(item.id)));
        _nextCursor = page.nextCursor;
        _loaded = true;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Car car) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => CarDetailScreen(
        car: car,
        repository: widget.repository,
        evolutionsRepository: widget.evolutionsRepository,
        canManage: car.ownerId == widget.currentUserId,
        currentUserId: widget.currentUserId,
        onProfileTap: widget.onProfileTap,
        onOwnerTap: () => widget.onProfileTap(car.ownerId),
      ),
    ));
    if (mounted) await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Projetos salvos')),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            if (_loading && !_loaded)
              const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && !_loaded)
              _Message(
                icon: Icons.cloud_off_outlined,
                text: apiErrorMessage(_error!),
                action: 'Tentar novamente',
                onPressed: () => _load(reset: true),
              )
            else if (_items.isEmpty)
              const _Message(
                icon: Icons.bookmark_border_rounded,
                text:
                    'Nenhum projeto salvo ainda. Encontre um projeto e toque no marcador para guardá-lo aqui.',
              )
            else ...[
              for (final car in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _open(car),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 74,
                                height: 74,
                                child: GdImage(
                                    url: car.photoUrl,
                                    semanticLabel: car.model),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    [car.model, car.year]
                                        .whereType<Object>()
                                        .join(' '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text('@${car.ownerUsername}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: colors.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_error != null)
                Text(apiErrorMessage(_error!), textAlign: TextAlign.center),
              if (_nextCursor != null || _error != null)
                Center(
                  child: TextButton.icon(
                    onPressed: _loading ? null : () => _load(),
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more_rounded),
                    label: Text(
                        _error != null ? 'Tentar novamente' : 'Carregar mais'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.action,
    this.onPressed,
  });

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 16),
        child: Column(children: [
          Icon(icon, size: 44),
          const SizedBox(height: 14),
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: onPressed, child: Text(action!)),
          ],
        ]),
      );
}
