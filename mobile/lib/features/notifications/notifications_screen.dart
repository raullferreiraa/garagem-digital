import 'dart:async';

import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/notifications/app_notification.dart';
import 'package:garagem_mobile/features/notifications/notifications_repository.dart';

enum _ActivityFilter { all, projects, people, teams, events }

extension on _ActivityFilter {
  String get label => switch (this) {
        _ActivityFilter.all => 'Tudo',
        _ActivityFilter.projects => 'Projetos',
        _ActivityFilter.people => 'Pessoas',
        _ActivityFilter.teams => 'Equipes',
        _ActivityFilter.events => 'Encontros',
      };

  bool includes(AppNotification item) => switch (this) {
        _ActivityFilter.all => true,
        _ActivityFilter.projects => item.carId != null ||
            item.evolutionId != null ||
            item.commentId != null,
        _ActivityFilter.people => item.type == 'novo_seguidor',
        _ActivityFilter.teams => item.teamId != null ||
            item.type.contains('equipe') ||
            item.type.startsWith('convite_'),
        _ActivityFilter.events =>
          item.eventId != null || item.type.contains('encontro'),
      };
}

final class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    required this.repository,
    required this.onUnreadChanged,
    required this.onOpen,
    required this.refreshRevision,
    super.key,
  });

  final NotificationsRepository repository;
  final ValueChanged<int> onUnreadChanged;
  final Future<void> Function(AppNotification) onOpen;
  final int refreshRevision;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

final class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future;
  List<AppNotification>? _items;
  int _fetchRequest = 0;
  final Set<String> _changing = {};
  final Set<String> _newThisVisit = {};
  _ActivityFilter _filter = _ActivityFilter.all;
  bool _opening = false;
  bool _acknowledging = false;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshRevision != oldWidget.refreshRevision) _future = _fetch();
  }

  Future<List<AppNotification>> _fetch() async {
    final request = ++_fetchRequest;
    final items = await widget.repository.all();
    if (mounted && request == _fetchRequest) {
      setState(() {
        _items = items;
        _hasMore = items.length == 100;
        _loadingMore = false;
        _loadMoreFailed = false;
        _newThisVisit.addAll(
          items.where((item) => !item.isRead).map((item) => item.id),
        );
      });
      widget.onUnreadChanged(items.where((item) => !item.isRead).length);
      if (items.any((item) => !item.isRead)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_acknowledgeVisible());
        });
      }
    }
    return items;
  }

  Future<void> _loadMore() async {
    final items = _items;
    if (_loadingMore || !_hasMore || items == null || items.isEmpty) return;
    final request = _fetchRequest;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    try {
      final older = await widget.repository.olderThan(items.last);
      if (!mounted || request != _fetchRequest) return;
      setState(() {
        final knownIds = _items!.map((item) => item.id).toSet();
        _items = [
          ..._items!,
          ...older.where((item) => knownIds.add(item.id)),
        ];
        _hasMore = older.length == 100;
        _loadingMore = false;
        _newThisVisit.addAll(
          older.where((item) => !item.isRead).map((item) => item.id),
        );
      });
      await _acknowledgeVisible();
    } catch (_) {
      if (!mounted || request != _fetchRequest) return;
      setState(() {
        _loadingMore = false;
        _loadMoreFailed = true;
      });
    }
  }

  Widget _moreButton() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            if (_loadMoreFailed) ...[
              const Text('Não foi possível carregar avisos antigos.'),
              const SizedBox(height: 8),
            ],
            if (_loadingMore)
              const CircularProgressIndicator()
            else
              OutlinedButton(
                onPressed: _loadMore,
                child: Text(_loadMoreFailed
                    ? 'Tentar novamente'
                    : 'Carregar avisos antigos'),
              ),
          ],
        ),
      );

  Future<void> _acknowledgeVisible() async {
    if (_acknowledging) return;
    final items = _items;
    if (items == null || items.every((item) => item.isRead)) return;
    _acknowledging = true;
    try {
      final readIds =
          items.where((item) => !item.isRead).map((item) => item.id).toSet();
      for (final id in readIds) {
        await widget.repository.markRead(id);
      }
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _fetchRequest++;
        _items = [
          for (final item in _items!)
            readIds.contains(item.id) ? item.copyWith(readAt: now) : item,
        ];
      });
      final unread = await widget.repository.unreadCount();
      if (mounted) widget.onUnreadChanged(unread);
    } catch (_) {
      // Um novo acesso ou refresh tenta confirmar os avisos restantes.
    } finally {
      _acknowledging = false;
    }
  }

  Future<void> _reload() async {
    final future = _fetch();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // A lista anterior continua na tela; o usuário pode tentar novamente.
    }
  }

  Future<void> _open(AppNotification item) async {
    if (_opening) return;
    _opening = true;
    try {
      if (!item.isRead) {
        setState(() => _changing.add(item.id));
        try {
          final updated = await widget.repository.markRead(item.id);
          if (!mounted) return;
          setState(() {
            _fetchRequest++;
            _changing.remove(item.id);
            _items = [
              for (final current in _items!)
                if (current.id == updated.id) updated else current,
            ];
          });
          widget.onUnreadChanged(
            _items!.where((notification) => !notification.isRead).length,
          );
        } catch (error) {
          if (!mounted) return;
          setState(() => _changing.remove(item.id));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(apiErrorMessage(error))),
          );
          return;
        }
      }
      if (mounted) await widget.onOpen(item);
    } finally {
      _opening = false;
    }
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);
    if (difference.inMinutes < 1) return 'Agora';
    if (difference.inHours < 1) return 'Há ${difference.inMinutes} min';
    if (difference.inDays < 1) return 'Há ${difference.inHours} h';
    if (difference.inDays < 7) return 'Há ${difference.inDays} d';
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  IconData _icon(String type) {
    return switch (type) {
      'novo_seguidor' => Icons.person_add_alt_1,
      'comentario_evolucao' => Icons.mode_comment_outlined,
      'resposta_comentario' => Icons.reply_rounded,
      'curtida_evolucao' => Icons.favorite,
      'curtida_comentario' => Icons.favorite_border,
      'solicitacao_equipe' => Icons.group_add_outlined,
      'solicitacao_equipe_aprovada' => Icons.verified_outlined,
      'solicitacao_equipe_recusada' => Icons.person_remove_outlined,
      'convite_equipe' => Icons.mail_outline_rounded,
      'convite_equipe_aceito' => Icons.group_add_outlined,
      'convite_equipe_recusado' => Icons.person_remove_outlined,
      'nova_edicao_encontro' => Icons.event_available_outlined,
      'edicao_encontro_alterada' => Icons.edit_calendar_outlined,
      'edicao_encontro_cancelada' => Icons.event_busy_outlined,
      _ => Icons.notifications_outlined,
    };
  }

  String _dayLabel(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) return 'HOJE';
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (day == yesterday) return 'ONTEM';
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Atividade')),
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snapshot) {
          final allItems = _items ?? snapshot.data;
          if (allItems == null &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const GdSkeleton(compact: true);
          }
          if (allItems == null) {
            return Center(
              child: FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: Text(apiErrorMessage(snapshot.error!)),
              ),
            );
          }
          final items = allItems.where(_filter.includes).toList();
          final newThisVisit =
              allItems.where((item) => _newThisVisit.contains(item.id)).length;
          return Column(
            children: [
              if (snapshot.hasError)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud_off_outlined),
                    title: const Text('Não foi possível atualizar os avisos.'),
                    trailing: TextButton(
                      onPressed: _reload,
                      child: const Text('Tentar novamente'),
                    ),
                  ),
                ),
              if (allItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GdSectionTitle(
                        title: newThisVisit == 0
                            ? 'Você está em dia.'
                            : '$newThisVisit ${newThisVisit == 1 ? 'novidade nesta visita' : 'novidades nesta visita'}',
                        eyebrow: 'NA SUA COMUNIDADE',
                        trailing: Icon(
                          newThisVisit == 0
                              ? Icons.done_all_rounded
                              : Icons.bolt_rounded,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              if (allItems.isNotEmpty)
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      for (final filter in _ActivityFilter.values) ...[
                        ChoiceChip(
                          label: Text(filter.label),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _reload,
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: [
                            const SizedBox(height: 48),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(Icons.notifications_none_rounded,
                                    size: 32, color: colors.onPrimary),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                                allItems.isEmpty
                                    ? 'A conversa começa aqui.'
                                    : 'Nada em ${_filter.label.toLowerCase()} por aqui.',
                                style:
                                    Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 12),
                            Text(
                                allItems.isEmpty
                                    ? 'Suas novidades aparecerão aqui.'
                                    : 'Escolha outro filtro para ver suas atividades.',
                                style: Theme.of(context).textTheme.bodyLarge),
                            const SizedBox(height: 8),
                            if (allItems.isEmpty)
                              Text(
                                  'Seguidores, equipes e interações com seus projetos, '
                                  'tudo no mesmo lugar.',
                                  style: TextStyle(
                                      color: colors.onSurfaceVariant)),
                            if (_hasMore) _moreButton(),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                          itemCount: items.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == items.length) return _moreButton();
                            final item = items[index];
                            final isNewThisVisit =
                                _newThisVisit.contains(item.id);
                            final dayLabel = _dayLabel(item.createdAt);
                            final showDay = index == 0 ||
                                _dayLabel(items[index - 1].createdAt) !=
                                    dayLabel;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showDay)
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(0, 8, 0, 12),
                                    child: Row(children: [
                                      Text(dayLabel,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                  letterSpacing: 1.6,
                                                  color:
                                                      colors.onSurfaceVariant)),
                                      const SizedBox(width: 12),
                                      const Expanded(child: Divider()),
                                    ]),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Material(
                                    key: ValueKey('notification-${item.id}'),
                                    color: isNewThisVisit
                                        ? colors.primary.withValues(alpha: 0.10)
                                        : colors.surface,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: isNewThisVisit
                                            ? colors.primary
                                                .withValues(alpha: 0.28)
                                            : Colors.transparent,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => _open(item),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 16),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (item.eventId != null)
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: colors.primary
                                                      .withValues(alpha: 0.14),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                child: Icon(
                                                  _icon(item.type),
                                                  color: colors.primary,
                                                ),
                                              )
                                            else
                                              Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  GdAvatar(
                                                      url: item.actorAvatarUrl,
                                                      name:
                                                          item.actorUsername ??
                                                              'GD',
                                                      size: 44),
                                                  Positioned(
                                                    right: -3,
                                                    bottom: -3,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              4),
                                                      decoration: BoxDecoration(
                                                        color: !isNewThisVisit
                                                            ? colors
                                                                .surfaceContainerHighest
                                                            : colors.primary,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                            color:
                                                                colors.surface,
                                                            width: 2),
                                                      ),
                                                      child: Icon(
                                                          _icon(item.type),
                                                          size: 12,
                                                          color: !isNewThisVisit
                                                              ? colors
                                                                  .onSurfaceVariant
                                                              : colors
                                                                  .onPrimary),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            const SizedBox(width: 13),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.message,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              !isNewThisVisit
                                                                  ? FontWeight
                                                                      .w500
                                                                  : FontWeight
                                                                      .w700,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 5),
                                                  Text(
                                                    _date(item.createdAt),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: colors
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (_changing.contains(item.id))
                                              const SizedBox.square(
                                                dimension: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            else if (!item.isRead)
                                              Container(
                                                width: 9,
                                                height: 9,
                                                decoration: BoxDecoration(
                                                  color: colors.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
