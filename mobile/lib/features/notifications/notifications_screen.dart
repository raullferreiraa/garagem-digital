import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/notifications/app_notification.dart';
import 'package:garagem_mobile/features/notifications/notifications_repository.dart';

final class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    required this.repository,
    required this.onUnreadChanged,
    required this.onOpen,
    super.key,
  });

  final NotificationsRepository repository;
  final ValueChanged<int> onUnreadChanged;
  final Future<void> Function(AppNotification) onOpen;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

final class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future;
  List<AppNotification>? _items;
  final Set<String> _changing = {};

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<AppNotification>> _fetch() async {
    final items = await widget.repository.all();
    if (mounted) {
      setState(() => _items = items);
      widget.onUnreadChanged(items.where((item) => !item.isRead).length);
    } else {
      _items = items;
    }
    return items;
  }

  Future<void> _reload() async {
    final future = _fetch();
    setState(() => _future = future);
    await future;
  }

  Future<void> _open(AppNotification item) async {
    if (_changing.contains(item.id)) return;
    if (!item.isRead) {
      setState(() => _changing.add(item.id));
      try {
        final updated = await widget.repository.markRead(item.id);
        if (!mounted) return;
        setState(() {
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
  }

  Future<void> _markAllRead() async {
    final items = _items;
    if (items == null || items.every((item) => item.isRead)) return;
    try {
      await widget.repository.markAllRead();
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _items = [
          for (final item in items)
            if (item.isRead) item else item.copyWith(readAt: now),
        ];
      });
      widget.onUnreadChanged(0);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
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
      _ => Icons.notifications_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atividade'),
        actions: [
          IconButton(
            onPressed: _markAllRead,
            tooltip: 'Marcar todas como lidas',
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snapshot) {
          final items = _items ?? snapshot.data;
          if (items == null &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items == null) {
            return Center(
              child: FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: Text(apiErrorMessage(snapshot.error!)),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 190),
                      Icon(Icons.notifications_none_rounded, size: 58),
                      SizedBox(height: 14),
                      Text(
                        'Suas novidades aparecerão aqui.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Material(
                        color: item.isRead
                            ? colors.surfaceContainer
                            : colors.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _open(item),
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundImage: item.actorAvatarUrl == null
                                      ? null
                                      : NetworkImage(item.actorAvatarUrl!),
                                  child: item.actorAvatarUrl == null
                                      ? Icon(_icon(item.type))
                                      : null,
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.message,
                                        style: TextStyle(
                                          fontWeight: item.isRead
                                              ? FontWeight.w500
                                              : FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        _date(item.createdAt),
                                        style:
                                            Theme.of(context).textTheme.labelMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                if (_changing.contains(item.id))
                                  const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
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
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
