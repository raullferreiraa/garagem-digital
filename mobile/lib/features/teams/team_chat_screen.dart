import 'dart:async';

import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/widgets/gd_premium.dart';
import 'package:flutter/services.dart';
import 'package:garagem_mobile/core/widgets/chat_message_bubble.dart';
import 'package:garagem_mobile/features/messages/message_reply.dart';
import 'package:garagem_mobile/features/messages/message_draft_storage.dart';
import 'package:garagem_mobile/features/messages/message_history_screen.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/core/widgets/message_management.dart';
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
  final _draftStorage = const MessageDraftStorage();
  Timer? _draftTimer;
  bool _draftEdited = false;
  final _scroll = ScrollController(keepScrollOffset: false);
  final _composerFocus = FocusNode();
  final _messageKeys = <String, GlobalKey>{};
  MessageReply? _replyTo;
  List<TeamChatMessage>? _messages;
  String? _nextCursor;
  Object? _error;
  bool _loadingOlder = false;
  bool _locatingMessage = false;
  String? _highlightedMessageId;
  bool _sending = false;
  bool _refreshing = false;
  bool _managingMessage = false;
  bool _hasNewMessages = false;
  int _request = 0;
  Timer? _refreshTimer;
  Timer? _highlightTimer;
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_clearNewMessagesAtEnd);
    _composer.addListener(_onDraftChanged);
    _restoreDraft();
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
    _highlightTimer?.cancel();
    _draftTimer?.cancel();
    _queueDraftSave();
    _composer.dispose();
    _composerFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    try {
      final draft = await _draftStorage.read(
          widget.currentUserId, 'team', widget.team.id);
      if (mounted && !_draftEdited && draft != null) _composer.text = draft;
    } catch (_) {
      // A conversa continua disponível se o armazenamento local falhar.
    }
  }

  void _onDraftChanged() {
    _draftEdited = true;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 350), _queueDraftSave);
  }

  void _queueDraftSave() {
    final text = _composer.text;
    unawaited(_draftStorage
        .save(widget.currentUserId, 'team', widget.team.id, text)
        .catchError((Object _) {}));
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
        _hasNewMessages = false;
      });
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
      final latest = {for (final item in page.items) item.id: item};
      final changed = _messages!.any((item) {
        final updated = latest[item.id];
        return updated != null &&
            (updated.content != item.content ||
                updated.editedAt != item.editedAt ||
                updated.deletedAt != item.deletedAt ||
                updated.reply != item.reply);
      });
      if (additions.isEmpty && !changed) return;
      final nearEnd = !_scroll.hasClients || _scroll.offset < 120;
      setState(() {
        _messages = [
          for (final item in _messages!) latest[item.id] ?? item,
          ...additions,
        ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        if (additions.isNotEmpty) _hasNewMessages = !nearEnd;
      });
      if (additions.isNotEmpty && nearEnd) _scrollToEnd();
    } catch (_) {
      // A atualização silenciosa tenta novamente no próximo ciclo.
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _loadOlder() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingOlder) return;
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
      final message = await widget.repository
          .sendChat(widget.team.id, content, replyToId: _replyTo?.id);
      if (!mounted) return;
      _composer.clear();
      _draftTimer?.cancel();
      _queueDraftSave();
      _replyTo = null;
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

  Future<void> _manageMessage(TeamChatMessage message) async {
    if (_managingMessage || message.deletedAt != null) return;
    final action = await chooseMessageAction(context,
        mine: message.authorId == widget.currentUserId);
    if (!mounted || action == null) return;
    if (action == MessageAction.copy) {
      await Clipboard.setData(ClipboardData(text: message.content));
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Texto copiado.')),
        );
      return;
    }
    if (action == MessageAction.reply) {
      setState(() => _replyTo = MessageReply(
            id: message.id,
            authorId: message.authorId,
            authorName: message.authorName,
            content: message.content,
          ));
      _composerFocus.requestFocus();
      return;
    }
    final content = action == MessageAction.edit
        ? await promptMessageEdit(context, message.content)
        : null;
    if (!mounted) return;
    if (action == MessageAction.edit && content == null) return;
    if (action == MessageAction.delete &&
        !await confirmMessageDelete(context)) {
      return;
    }
    if (!mounted) return;
    setState(() => _managingMessage = true);
    try {
      final updated = action == MessageAction.edit
          ? await widget.repository
              .editChatMessage(widget.team.id, message.id, content!)
          : null;
      if (action == MessageAction.delete) {
        await widget.repository.deleteChatMessage(widget.team.id, message.id);
      }
      if (!mounted) return;
      setState(() {
        _messages = [
          for (final item in _messages!)
            if (item.id == message.id) updated ?? item.asDeleted() else item,
        ];
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
        unawaited(_refreshLatest());
      }
    } finally {
      if (mounted) setState(() => _managingMessage = false);
    }
  }

  void _scrollToEnd() {
    if (_hasNewMessages) setState(() => _hasNewMessages = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _clearNewMessagesAtEnd() {
    if (_hasNewMessages && _scroll.hasClients && _scroll.offset < 120) {
      setState(() => _hasNewMessages = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              tooltip: 'Buscar na conversa',
              onPressed: _searchHistory,
              icon: const Icon(Icons.search_rounded),
            )
          ],
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
        body: Column(children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(child: _body()),
              if (_hasNewMessages)
                Positioned(
                  bottom: 12,
                  right: 16,
                  child: FilledButton.tonalIcon(
                    onPressed: _scrollToEnd,
                    icon: const Icon(Icons.arrow_downward_rounded),
                    label: const Text('Novas mensagens'),
                  ),
                ),
              if (_locatingMessage)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(),
                ),
            ]),
          ),
          _composerBar(),
        ]),
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
        reverse: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        itemCount: messages.length + 1,
        itemBuilder: (context, index) {
          if (index == messages.length)
            return _historyControl(messages.isEmpty);
          final position = messages.length - 1 - index;
          final message = messages[position];
          final previous = position > 0 ? messages[position - 1] : null;
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

  String _replyAuthor(MessageReply reply) =>
      reply.authorId == widget.currentUserId
          ? 'Você'
          : reply.authorName ?? 'Integrante';

  HistoryMessage _historyMessage(TeamChatMessage message) => HistoryMessage(
        MessageReply(
            id: message.id,
            authorId: message.authorId,
            authorName: message.authorName,
            content: message.content,
            deleted: message.deletedAt != null),
        message.createdAt,
        edited: message.editedAt != null,
      );

  Future<void> _searchHistory() async {
    final messageId =
        await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => MessageHistoryScreen(
        author: _replyAuthor,
        load: (query, cursor) async {
          final page = await widget.repository
              .chat(widget.team.id, query: query, cursor: cursor);
          return HistoryPage(
              page.items.map(_historyMessage).toList(), page.nextCursor);
        },
      ),
    ));
    if (messageId != null) await _jumpToMessage(messageId);
  }

  Future<void> _jumpToMessage(String id) async {
    if (_locatingMessage || _messages == null) return;
    setState(() => _locatingMessage = true);
    try {
      final visitedCursors = <String>{};
      while (!_messages!.any((message) => message.id == id) &&
          _nextCursor != null) {
        if (!visitedCursors.add(_nextCursor!)) break;
        final page =
            await widget.repository.chat(widget.team.id, cursor: _nextCursor);
        if (!mounted) return;
        final known = _messages!.map((item) => item.id).toSet();
        setState(() {
          _messages = [
            ...page.items.where((item) => known.add(item.id)),
            ..._messages!,
          ];
          _nextCursor = page.nextCursor;
        });
      }
      if (!mounted) return;
      if (!_messages!.any((message) => message.id == id)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Esta mensagem não está mais disponível.')));
        return;
      }
      setState(() => _highlightedMessageId = id);
      await _revealMessage(id);
      if (mounted) setState(() => _locatingMessage = false);
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted && _highlightedMessageId == id) {
          setState(() => _highlightedMessageId = null);
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _locatingMessage = false);
    }
  }

  Future<void> _revealMessage(String id) async {
    await WidgetsBinding.instance.endOfFrame;
    for (var attempt = 0; attempt < 40; attempt++) {
      final target = _messageKeys[id]?.currentContext;
      if (target != null) {
        await Scrollable.ensureVisible(
          target,
          alignment: .5,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      if (!_scroll.hasClients) return;
      final next = attempt == 0
          ? _scroll.position.maxScrollExtent
          : (_scroll.offset - _scroll.position.viewportDimension * .75)
              .clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.jumpTo(next);
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  MessageReply? _visibleReply(MessageReply? reply) {
    if (reply == null || reply.deleted) return reply;
    for (final message in _messages ?? const <TeamChatMessage>[]) {
      if (message.id == reply.id && message.deletedAt != null)
        return MessageReply(
          id: message.id,
          authorId: message.authorId,
          authorName: message.authorName,
          content: message.content,
          deleted: message.deletedAt != null,
        );
    }
    return reply;
  }

  Widget _messageBubble(TeamChatMessage message) => KeyedSubtree(
      key: _messageKeys.putIfAbsent(message.id, GlobalKey.new),
      child: ChatMessageBubble(
        messageId: message.id,
        content: message.displayContent,
        createdAt: message.createdAt,
        mine: message.authorId == widget.currentUserId,
        deleted: message.deletedAt != null,
        edited: message.editedAt != null,
        authorName: message.authorId == widget.currentUserId
            ? null
            : message.authorName,
        reply: _visibleReply(message.reply),
        replyAuthorName:
            message.reply == null ? null : _replyAuthor(message.reply!),
        onLongPress: () => _manageMessage(message),
        onReplyTap: message.reply == null
            ? null
            : () => _jumpToMessage(message.reply!.id),
        highlighted: _highlightedMessageId == message.id,
      ));

  Widget _composerBar() {
    return GdComposerSurface(
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_replyTo != null)
            MessageReplyBar(
              author: _replyAuthor(_replyTo!),
              content: _visibleReply(_replyTo)!.displayContent,
              onCancel: () => setState(() => _replyTo = null),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _composer,
                  focusNode: _composerFocus,
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Enviar mensagem',
                onPressed: _sending ||
                        _messages == null ||
                        _composer.text.trim().isEmpty
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
        ]),
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
