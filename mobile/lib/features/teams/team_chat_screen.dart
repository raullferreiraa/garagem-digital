import 'dart:async';

import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/teams/team.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

final class TeamChatScreen extends StatefulWidget {
  const TeamChatScreen({
    required this.team,
    required this.repository,
    required this.currentUserId,
    super.key,
  });

  final Team team;
  final TeamsRepository repository;
  final String currentUserId;

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

final class _TeamChatScreenState extends State<TeamChatScreen>
    with WidgetsBindingObserver {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  List<TeamChatMessage>? _messages;
  String? _nextCursor;
  Object? _error;
  bool _loadingOlder = false;
  bool _sending = false;
  bool _refreshing = false;
  int _request = 0;
  Timer? _refreshTimer;
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitial();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refreshLatest(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      if (_messages == null) {
        unawaited(_loadInitial());
      } else {
        unawaited(_refreshLatest());
      }
    }
  }

  Future<void> _loadInitial() async {
    final request = ++_request;
    try {
      final page = await widget.repository.chat(widget.team.id);
      if (!mounted || request != _request) return;
      setState(() {
        _messages = page.items;
        _nextCursor = page.nextCursor;
        _error = null;
      });
      _scrollToEnd();
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() => _error = error);
    }
  }

  Future<void> _refreshLatest() async {
    if (_messages == null ||
        _sending ||
        _refreshing ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ModalRoute.of(context)?.isCurrent != true) return;
    _refreshing = true;
    try {
      final page = await widget.repository.chat(widget.team.id);
      if (!mounted) return;
      final known = _messages!.map((item) => item.id).toSet();
      final additions = page.items.where((item) => known.add(item.id)).toList();
      if (additions.isEmpty) return;
      final nearEnd = !_scroll.hasClients ||
          _scroll.position.maxScrollExtent - _scroll.offset < 120;
      setState(() {
        _messages = [..._messages!, ...additions]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
      if (nearEnd) _scrollToEnd();
    } catch (_) {
      // A atualização silenciosa tenta novamente no próximo ciclo.
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _loadOlder() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingOlder) return;
    final previousExtent =
        _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
    final previousOffset = _scroll.hasClients ? _scroll.offset : 0.0;
    setState(() => _loadingOlder = true);
    try {
      final page = await widget.repository.chat(widget.team.id, cursor: cursor);
      if (!mounted) return;
      final known = _messages!.map((item) => item.id).toSet();
      setState(() {
        _messages = [
          ...page.items.where((item) => known.add(item.id)),
          ..._messages!,
        ];
        _nextCursor = page.nextCursor;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        final addedExtent = _scroll.position.maxScrollExtent - previousExtent;
        _scroll.jumpTo(previousOffset + addedExtent);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _send() async {
    final content = _composer.text.trim();
    if (content.isEmpty || _sending || _messages == null) return;
    setState(() => _sending = true);
    try {
      final message = await widget.repository.sendChat(widget.team.id, content);
      if (!mounted) return;
      _composer.clear();
      if (!(_messages ?? const <TeamChatMessage>[])
          .any((item) => item.id == message.id)) {
        setState(() => _messages = [...?_messages, message]);
      }
      _scrollToEnd();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              GdAvatar(
                url: widget.team.avatarUrl,
                name: widget.team.name,
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.team.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${widget.team.memberCount} ${widget.team.memberCount == 1 ? "integrante" : "integrantes"}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Column(children: [Expanded(child: _body()), _composerBar()]),
      );

  Widget _body() {
    if (_messages == null && _error == null)
      return const GdSkeleton(compact: true);
    if (_messages == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _loadInitial,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(apiErrorMessage(_error!)),
        ),
      );
    }
    final messages = _messages!;
    return RefreshIndicator(
      onRefresh: _refreshLatest,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        itemCount: messages.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _historyControl(messages.isEmpty);
          final message = messages[index - 1];
          final previous = index > 1 ? messages[index - 2] : null;
          return Column(children: [
            if (previous == null ||
                !_sameDay(previous.createdAt, message.createdAt))
              _dateSeparator(message.createdAt),
            _messageBubble(message),
          ]);
        },
      ),
    );
  }

  Widget _historyControl(bool isEmpty) {
    if (_nextCursor != null) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadingOlder ? null : _loadOlder,
          icon: _loadingOlder
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.history_rounded),
          label: const Text('Carregar mensagens anteriores'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(
        isEmpty
            ? 'A pista está livre. Comece a conversa da equipe.'
            : 'Início da conversa da equipe',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Widget _dateSeparator(DateTime value) {
    final date = value.toLocal();
    final now = DateTime.now();
    final difference = DateTime(now.year, now.month, now.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    final label = difference == 0
        ? 'HOJE'
        : difference == 1
            ? 'ONTEM'
            : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Widget _messageBubble(TeamChatMessage message) {
    final mine = message.authorId == widget.currentUserId;
    final colors = Theme.of(context).colorScheme;
    final time = message.createdAt.toLocal();
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.fromLTRB(14, 9, 11, 7),
        decoration: BoxDecoration(
          color: mine ? colors.primary : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.authorName,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: SelectableText(
                    message.content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: mine ? colors.onPrimary : colors.onSurface,
                        ),
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: mine
                            ? colors.onPrimary.withValues(alpha: .8)
                            : colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _composerBar() {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: _composer,
                onChanged: (_) => setState(() {}),
                enabled: !_sending && _messages != null,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Mensagem para a equipe',
                  counterText: _composer.text.characters.length >= 1800
                      ? '${_composer.text.characters.length}/2000'
                      : '',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Enviar mensagem',
              onPressed:
                  _sending || _messages == null || _composer.text.trim().isEmpty
                      ? null
                      : _send,
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_upward_rounded),
            ),
          ]),
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    final first = a.toLocal();
    final second = b.toLocal();
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
