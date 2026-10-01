import 'dart:async';

import 'package:flutter/material.dart';
import 'package:garona_mobile/core/network/api_client.dart';
import 'package:garona_mobile/core/widgets/garona_ui.dart';
import 'package:garona_mobile/features/cars/car.dart';
import 'package:garona_mobile/features/cars/car_detail_screen.dart';
import 'package:garona_mobile/features/cars/cars_repository.dart';
import 'package:garona_mobile/features/evolutions/evolutions_repository.dart';

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
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';
  int _loadRequest = 0;
  final List<Car> _items = [];
  String? _nextCursor;
  Object? _error;
  bool _loading = false;
  bool _loaded = false;
  final Set<String> _removing = {};

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (_query == query) return;
    _query = query;
    ++_loadRequest;
    _searchDebounce = Timer(
      query.isEmpty ? Duration.zero : const Duration(milliseconds: 300),
      () => _load(reset: true),
    );
    setState(() {
      _items.clear();
      _nextCursor = null;
      _loaded = false;
      _loading = true;
      _error = null;
    });
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final request = ++_loadRequest;
    final query = _query;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _loaded = false;
        _items.clear();
        _nextCursor = null;
      }
    });
    try {
      final page = await widget.repository.saved(
        cursor: reset ? null : _nextCursor,
        query: query,
      );
      if (!mounted || request != _loadRequest) return;
      setState(() {
        final known = _items.map((item) => item.id).toSet();
        _items.addAll(page.items.where((item) => known.add(item.id)));
        _nextCursor = page.nextCursor;
        _loaded = true;
      });
    } catch (error) {
      if (mounted && request == _loadRequest) setState(() => _error = error);
    } finally {
      if (mounted && request == _loadRequest) {
        setState(() => _loading = false);
      }
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

  Future<void> _removeSaved(Car car) async {
    if (_removing.contains(car.id)) return;
    setState(() => _removing.add(car.id));
    try {
      await widget.repository.setSaved(car.id, saved: false);
      if (!mounted) return;
      final previousIndex = _items.indexWhere((item) => item.id == car.id);
      setState(() => _items.removeWhere((item) => item.id == car.id));
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 5),
        persist: false,
        content: const Text('Projeto removido dos salvos.'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () => _restoreSaved(car, previousIndex),
        ),
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _removing.remove(car.id));
    }
  }

  Future<void> _restoreSaved(Car car, int index) async {
    try {
      await widget.repository.setSaved(car.id, saved: true);
      if (!mounted) return;
      setState(() {
        if (_items.any((item) => item.id == car.id)) return;
        _items.insert(index.clamp(0, _items.length), car);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projetos salvos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _searchChanged,
              onSubmitted: (_) {
                _searchDebounce?.cancel();
                _load(reset: true);
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar projeto ou pessoa',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        onPressed: () {
                          _searchController.clear();
                          _searchChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
        ),
      ),
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
              _Message(
                icon: Icons.bookmark_border_rounded,
                text: _query.isEmpty
                    ? 'Nenhum projeto salvo ainda. Encontre um projeto e toque no marcador para guardá-lo aqui.'
                    : 'Nenhum projeto salvo encontrado para “$_query”.',
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
                                child: GaronaImage(
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
                            IconButton(
                              tooltip: 'Remover ${car.model} dos salvos',
                              onPressed: _removing.contains(car.id)
                                  ? null
                                  : () => _removeSaved(car),
                              icon: _removing.contains(car.id)
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Icon(Icons.bookmark_rounded,
                                      color: colors.primary),
                            ),
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
