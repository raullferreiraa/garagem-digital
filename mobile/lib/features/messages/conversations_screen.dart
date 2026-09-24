import 'dart:async';

import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/messages/conversation.dart';
import 'package:garagem_mobile/features/messages/conversation_screen.dart';
import 'package:garagem_mobile/features/messages/messages_repository.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

final class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({
    required this.active,
    required this.repository,
    required this.currentUserId,
    required this.refreshRevision,
    required this.onUnreadChanged,
    required this.onProfileTap,
    required this.onDiscover,
    required this.teamChat,
    required this.onTeamChatTap,
    required this.onTeamChatChanged,
    super.key,
  });

  final bool active;
  final MessagesRepository repository;
  final String currentUserId;
  final int refreshRevision;
  final VoidCallback onUnreadChanged;
  final ValueChanged<String> onProfileTap;
  final VoidCallback onDiscover;
  final TeamChatSummary? teamChat;
  final VoidCallback onTeamChatTap;
  final VoidCallback onTeamChatChanged;

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

final class _ConversationsScreenState extends State<ConversationsScreen> {
  final _search = TextEditingController();
  List<DirectConversation>? _items;
  Object? _error;
  bool _loading = true;
  int _request = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _reload();
    _configureRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ConversationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshRevision != oldWidget.refreshRevision ||
        widget.active && !oldWidget.active) {
      _reload();
    }
    if (widget.active != oldWidget.active) _configureRefreshTimer();
  }

  void _configureRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = widget.active
        ? Timer.periodic(
            const Duration(seconds: 10),
            (_) => _reload(),
          )
        : null;
  }

  Future<void> _reload() async {
    final request = ++_request;
    try {
      final items = await widget.repository.conversations();
      if (!mounted || request != _request) return;
      setState(() {
        _items = items;
        _error = null;
        _loading = false;
      });
      widget.onUnreadChanged();
      widget.onTeamChatChanged();
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _open(DirectConversation conversation) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => ConversationScreen(
        conversation: conversation,
        repository: widget.repository,
        currentUserId: widget.currentUserId,
        onProfileTap: widget.onProfileTap,
        onChanged: widget.onUnreadChanged,
      ),
    ));
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversas'), actions: [
        IconButton(
            onPressed: widget.onDiscover,
            tooltip: 'Encontrar pessoas',
            icon: const Icon(Icons.person_search_outlined)),
      ]),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _items == null) return const GdSkeleton(compact: true);
    if (_error != null && _items == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 36),
            const SizedBox(height: 12),
            Text(apiErrorMessage(_error!), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente')),
          ]),
        ),
      );
    }
    final items = _items ?? const <DirectConversation>[];
    final query =
        _searchKey(_search.text.trim().replaceFirst(RegExp(r'^@'), ''));
    final visibleItems = query.isEmpty
        ? items
        : items.where((conversation) {
            final user = conversation.otherUser;
            return _searchKey(user.name).contains(query) ||
                _searchKey(user.username).contains(query);
          }).toList();
    final teamChat = widget.teamChat;
    final visibleTeamChat = teamChat != null &&
            (query.isEmpty || _searchKey(teamChat.teamName).contains(query))
        ? teamChat
        : null;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (items.isNotEmpty ||
              teamChat != null ||
              _search.text.isNotEmpty) ...[
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar nas conversas',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        onPressed: () => setState(_search.clear),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 22),
          ],
          if (_error != null) ...[
            Text(
                'Não foi possível atualizar as conversas. O conteúdo anterior foi mantido.',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                    onPressed: _reload, child: const Text('Tentar novamente'))),
          ],
          if (items.isEmpty && teamChat == null && query.isEmpty) ...[
            const GdSectionTitle(
              eyebrow: 'NA PISTA',
              title: 'Conexões reais',
            ),
            const SizedBox(height: 8),
            Text(
              'Troque ideias, detalhes e histórias com outros apaixonados.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
          ] else ...[
            Text('Suas conversas',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
          ],
          if (visibleTeamChat != null) ...[
            _teamChatTile(visibleTeamChat),
            if (visibleItems.isNotEmpty) const SizedBox(height: 4),
          ],
          if (query.isNotEmpty &&
              visibleItems.isEmpty &&
              visibleTeamChat == null)
            _noSearchResults()
          else if (items.isEmpty && teamChat == null)
            _empty()
          else
            ...visibleItems.map(_conversationTile),
        ],
      ),
    );
  }

  Widget _noSearchResults() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(children: [
          Icon(Icons.search_off_rounded,
              size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          const Text('Nenhuma conversa encontrada.'),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(_search.clear),
            child: const Text('Limpar busca'),
          ),
        ]),
      );

  String _searchKey(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[áàâãä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[íìîï]'), 'i')
      .replaceAll(RegExp('[óòôõö]'), 'o')
      .replaceAll(RegExp('[úùûü]'), 'u')
      .replaceAll('ç', 'c');

  Widget _teamChatTile(TeamChatSummary chat) {
    final colors = Theme.of(context).colorScheme;
    final unread = chat.unreadCount > 0;
    final last = chat.lastMessage;
    final mine = last?.authorId == widget.currentUserId;
    final preview = last == null
        ? 'Converse com os integrantes da sua equipe.'
        : '${mine ? 'Você: ' : '${last.authorName}: '}${last.content.replaceAll('\n', ' ')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GdReveal(
        child: Material(
          color: unread
              ? colors.primary.withValues(alpha: .09)
              : colors.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: unread
                  ? colors.primary.withValues(alpha: .32)
                  : colors.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTeamChatTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                GdAvatar(
                  url: chat.teamAvatarUrl,
                  name: chat.teamName,
                  size: 52,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            chat.teamName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: unread
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                          ),
                        ),
                        if (last != null)
                          Text(
                            _relativeDate(last.createdAt),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                      ]),
                      const SizedBox(height: 3),
                      Text(
                        'Conversa da equipe',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colors.primary,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontWeight: unread
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 10),
                          _UnreadBadge(count: chat.unreadCount),
                        ],
                      ]),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(children: [
        Icon(Icons.forum_outlined, color: colors.primary, size: 44),
        const SizedBox(height: 14),
        Text('Sua caixa de entrada está livre.',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Abra o perfil de alguém da comunidade para iniciar uma conversa.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: widget.onDiscover,
          icon: const Icon(Icons.explore_outlined),
          label: const Text('Explorar comunidade'),
        ),
      ]),
    );
  }

  Widget _conversationTile(DirectConversation conversation) {
    final colors = Theme.of(context).colorScheme;
    final unread = conversation.unreadCount > 0;
    final last = conversation.lastMessage;
    final mine = last?.senderId == widget.currentUserId;
    final preview = last == null
        ? 'Conversa iniciada. Envie a primeira mensagem.'
        : '${mine ? 'Você: ' : ''}${last.content.replaceAll('\n', ' ')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GdReveal(
        child: Material(
          color: unread
              ? colors.primary.withValues(alpha: .09)
              : colors.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: unread
                  ? colors.primary.withValues(alpha: .32)
                  : colors.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _open(conversation),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                GdAvatar(
                  url: conversation.otherUser.avatarUrl,
                  name: conversation.otherUser.name,
                  size: 52,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            conversation.otherUser.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: unread
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                          ),
                        ),
                        Text(
                          _relativeDate(
                              last?.createdAt ?? conversation.updatedAt),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ]),
                      const SizedBox(height: 3),
                      Text('@${conversation.otherUser.username}',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colors.primary,
                                  )),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontWeight: unread
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 10),
                          _UnreadBadge(count: conversation.unreadCount),
                        ],
                      ]),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  String _relativeDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    if (difference == 1) return 'ontem';
    if (difference < 7) return '${difference}d';
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
  }
}

final class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}
