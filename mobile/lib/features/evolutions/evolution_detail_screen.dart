import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/sharing/gd_share.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';
import 'package:garagem_mobile/features/evolutions/evolution_interactions.dart';
import 'package:garagem_mobile/features/evolutions/evolution_photos_screen.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/sharing/share_content.dart';

final class EvolutionDetailScreen extends StatefulWidget {
  const EvolutionDetailScreen({
    required this.evolution,
    required this.repository,
    required this.currentUserId,
    this.highlightCommentId,
    this.onProfileTap,
    super.key,
  });

  final Evolution evolution;
  final EvolutionsRepository repository;
  final String currentUserId;
  final String? highlightCommentId;
  final ValueChanged<String>? onProfileTap;

  @override
  State<EvolutionDetailScreen> createState() => _EvolutionDetailScreenState();
}

final class _EvolutionDetailScreenState extends State<EvolutionDetailScreen> {
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _commentKeys = {};
  late Future<EvolutionInteractions> _future;
  EvolutionInteractions? _interactions;
  EvolutionComment? _replyingTo;
  bool _changingLike = false;
  bool _sendingComment = false;
  bool _highlightScheduled = false;
  final Set<String> _changingCommentLikes = {};
  final Set<String> _deletingComments = {};

  @override
  void initState() {
    super.initState();
    _future = _fetchInteractions();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<EvolutionInteractions> _fetchInteractions() async {
    final interactions = await widget.repository.interactions(
      widget.evolution.carId,
      widget.evolution.id,
    );
    if (mounted) {
      setState(() => _interactions = interactions);
      _scheduleHighlightedComment();
    } else {
      _interactions = interactions;
    }
    return interactions;
  }

  GlobalKey _commentKey(String commentId) {
    return _commentKeys.putIfAbsent(commentId, GlobalKey.new);
  }

  void _scheduleHighlightedComment() {
    final commentId = widget.highlightCommentId;
    if (commentId == null || _highlightScheduled) return;
    _highlightScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      var targetContext = _commentKey(commentId).currentContext;
      if (targetContext == null && _scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
        targetContext = _commentKey(commentId).currentContext;
      }
      if (!mounted || targetContext == null) return;
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.32,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _reload() async {
    final future = _fetchInteractions();
    setState(() => _future = future);
    await future;
  }

  Future<void> _toggleLike() async {
    final previous = _interactions;
    if (previous == null || _changingLike) return;

    final shouldLike = !previous.likedByMe;
    final optimistic = previous.copyWith(
      likedByMe: shouldLike,
      totalLikes: shouldLike
          ? previous.totalLikes + 1
          : (previous.totalLikes > 0 ? previous.totalLikes - 1 : 0),
    );
    setState(() {
      _changingLike = true;
      _interactions = optimistic;
    });

    try {
      if (shouldLike) {
        await widget.repository.like(
          widget.evolution.carId,
          widget.evolution.id,
        );
      } else {
        await widget.repository.unlike(
          widget.evolution.carId,
          widget.evolution.id,
        );
      }
      final confirmed = await widget.repository.interactions(
        widget.evolution.carId,
        widget.evolution.id,
      );
      if (!mounted) return;
      setState(() {
        _interactions = confirmed;
        _changingLike = false;
      });
    } catch (error) {
      try {
        final confirmed = await widget.repository.interactions(
          widget.evolution.carId,
          widget.evolution.id,
        );
        if (!mounted) return;
        final completed = confirmed.likedByMe == shouldLike;
        setState(() {
          _interactions = completed ? confirmed : previous;
          _changingLike = false;
        });
        if (completed) return;
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _interactions = previous;
          _changingLike = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    }
  }

  EvolutionComment? _findComment(
    List<EvolutionComment> comments,
    String commentId,
  ) {
    for (final comment in comments) {
      if (comment.id == commentId) return comment;
      for (final reply in comment.replies) {
        if (reply.id == commentId) return reply;
      }
    }
    return null;
  }

  List<EvolutionComment> _replaceCommentIn(
    List<EvolutionComment> comments,
    EvolutionComment updated,
  ) {
    return [
      for (final comment in comments)
        if (comment.id == updated.id)
          updated
        else
          comment.copyWith(
            replies: [
              for (final reply in comment.replies)
                if (reply.id == updated.id) updated else reply,
            ],
          ),
    ];
  }

  Future<void> _toggleCommentLike(EvolutionComment comment) async {
    final previous = _interactions;
    if (previous == null || _changingCommentLikes.contains(comment.id)) return;

    final shouldLike = !comment.likedByMe;
    final optimistic = comment.copyWith(
      likedByMe: shouldLike,
      totalLikes: shouldLike
          ? comment.totalLikes + 1
          : (comment.totalLikes > 0 ? comment.totalLikes - 1 : 0),
    );
    setState(() {
      _changingCommentLikes.add(comment.id);
      _interactions = previous.copyWith(
        comments: _replaceCommentIn(previous.comments, optimistic),
      );
    });

    try {
      if (shouldLike) {
        await widget.repository.likeComment(
          widget.evolution.carId,
          widget.evolution.id,
          comment.id,
        );
      } else {
        await widget.repository.unlikeComment(
          widget.evolution.carId,
          widget.evolution.id,
          comment.id,
        );
      }
      final confirmed = await widget.repository.interactions(
        widget.evolution.carId,
        widget.evolution.id,
      );
      if (!mounted) return;
      setState(() {
        _interactions = confirmed;
        _changingCommentLikes.remove(comment.id);
      });
    } catch (error) {
      try {
        final confirmed = await widget.repository.interactions(
          widget.evolution.carId,
          widget.evolution.id,
        );
        if (!mounted) return;
        final saved = _findComment(confirmed.comments, comment.id);
        final completed = saved?.likedByMe == shouldLike;
        setState(() {
          _interactions = completed ? confirmed : previous;
          _changingCommentLikes.remove(comment.id);
        });
        if (completed) return;
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _interactions = previous;
          _changingCommentLikes.remove(comment.id);
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    }
  }

  void _startReply(EvolutionComment comment) {
    setState(() => _replyingTo = comment);
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    final current = _interactions;
    if (content.isEmpty || current == null || _sendingComment) return;

    FocusScope.of(context).unfocus();
    setState(() => _sendingComment = true);
    try {
      final replyingTo = _replyingTo;
      final comment = replyingTo == null
          ? await widget.repository.comment(
              widget.evolution.carId,
              widget.evolution.id,
              content,
            )
          : await widget.repository.reply(
              widget.evolution.carId,
              widget.evolution.id,
              replyingTo.id,
              content,
            );
      if (!mounted) return;
      _commentController.clear();
      setState(() {
        _interactions = current.copyWith(
          comments: replyingTo == null
              ? [...current.comments, comment]
              : [
                  for (final root in current.comments)
                    if (root.id == replyingTo.id)
                      root.copyWith(replies: [...root.replies, comment])
                    else
                      root,
                ],
        );
        _replyingTo = null;
        _sendingComment = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _sendingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
    }
  }

  Future<void> _confirmDeleteComment(EvolutionComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir comentário?'),
        content: const Text(
          'O comentário será removido da conversa. Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _deleteComment(comment);
    }
  }

  Future<void> _deleteComment(EvolutionComment comment) async {
    if (_deletingComments.contains(comment.id)) return;
    setState(() => _deletingComments.add(comment.id));
    try {
      await widget.repository.deleteComment(
        widget.evolution.carId,
        widget.evolution.id,
        comment.id,
      );
      if (!mounted) return;
      setState(() {
        _deletingComments.remove(comment.id);
        final current = _interactions!;
        _interactions = current.copyWith(
          comments: [
            for (final root in current.comments)
              if (root.id != comment.id)
                root.copyWith(
                  replies: root.replies
                      .where((reply) => reply.id != comment.id)
                      .toList(growable: false),
                ),
          ],
        );
        if (_replyingTo?.id == comment.id) _replyingTo = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _deletingComments.remove(comment.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} às $hour:$minute';
  }

  Widget _avatar(EvolutionComment comment) {
    return GdAvatar(
      url: comment.authorAvatarUrl,
      name: comment.authorName,
    );
  }

  Widget _buildComment(EvolutionComment comment, {bool isReply = false}) {
    return _CommentTile(
      comment: comment,
      avatar: _avatar(comment),
      date: _formatDate(comment.createdAt),
      canDelete: comment.authorId == widget.currentUserId,
      deleting: _deletingComments.contains(comment.id),
      changingLike: _changingCommentLikes.contains(comment.id),
      highlighted: widget.highlightCommentId == comment.id,
      key: _commentKey(comment.id),
      onAuthorTap: widget.onProfileTap == null
          ? null
          : () => widget.onProfileTap!(comment.authorId),
      onLike: () => _toggleCommentLike(comment),
      onReply: isReply ? null : () => _startReply(comment),
      onDelete: () => _confirmDeleteComment(comment),
    );
  }

  Widget _buildCommentThread(EvolutionComment comment) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        _buildComment(comment),
        for (final reply in comment.replies)
          Padding(
            padding: const EdgeInsets.fromLTRB(34, 0, 0, 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: colors.primary.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
              ),
              child: _buildComment(reply, isReply: true),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final evolution = widget.evolution;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evolução do projeto'),
        actions: [
          GdShareAction(
            payload: ShareContent.evolution(evolution),
            tooltip: 'Compartilhar evolução',
          ),
        ],
      ),
      body: FutureBuilder<EvolutionInteractions>(
        future: _future,
        builder: (context, snapshot) {
          final interactions = _interactions ?? snapshot.data;
          if (interactions == null &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const GdSkeleton();
          }
          if (interactions == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(apiErrorMessage(snapshot.error!)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              children: [
                GdSectionTitle(
                  eyebrow: 'Diário de bordo',
                  title: evolution.title,
                ),
                const SizedBox(height: 6),
                Text(
                  '@${evolution.authorUsername}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar:
                          const Icon(Icons.calendar_today_outlined, size: 17),
                      label: Text(_formatDate(evolution.timelineDate)),
                    ),
                    if (evolution.category != null)
                      Chip(
                        label: Text(
                          evolutionCategoryLabels[evolution.category] ??
                              evolution.category!,
                        ),
                      ),
                    if (evolution.mileageKm != null)
                      Chip(
                        avatar: const Icon(Icons.speed_outlined, size: 18),
                        label: Text('${evolution.mileageKm} km'),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  evolution.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (evolution.photos.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 190,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: evolution.photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final photo = evolution.photos[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => EvolutionPhotoViewer(
                                photos: evolution.photos,
                                initialIndex: index,
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AspectRatio(
                              aspectRatio: 4 / 3,
                              child: GdImage(
                                url: photo.url,
                                semanticLabel:
                                    'Foto da evolução ${evolution.title}',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                const Divider(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _changingLike ? null : _toggleLike,
                      icon: Icon(
                        interactions.likedByMe
                            ? Icons.favorite
                            : Icons.favorite_border,
                      ),
                      label: Text(
                        interactions.totalLikes == 1
                            ? '1 curtida'
                            : '${interactions.totalLikes} curtidas',
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mode_comment_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            interactions.totalComments == 1
                                ? '1 comentário'
                                : '${interactions.totalComments} comentários',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Conversa',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (interactions.comments.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'Ainda não há comentários. Seja a primeira pessoa a conversar sobre esta evolução.',
                      ),
                    ),
                  )
                else
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var index = 0;
                            index < interactions.comments.length;
                            index++) ...[
                          _buildCommentThread(interactions.comments[index]),
                          if (index < interactions.comments.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      bottomSheet: _interactions == null
          ? null
          : SafeArea(
              top: false,
              child: Material(
                elevation: 12,
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    10,
                    12,
                    MediaQuery.viewInsetsOf(context).bottom + 10,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyingTo != null)
                        Row(
                          children: [
                            const Icon(Icons.reply_rounded, size: 18),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'Respondendo a @${_replyingTo!.authorUsername}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            IconButton(
                              onPressed: _cancelReply,
                              tooltip: 'Cancelar resposta',
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              focusNode: _commentFocusNode,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 1000,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: _replyingTo == null
                                    ? 'Escreva um comentário...'
                                    : 'Escreva uma resposta...',
                                counterText: '',
                              ),
                              onSubmitted: (_) => _sendComment(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _sendingComment ? null : _sendComment,
                            tooltip: _replyingTo == null
                                ? 'Publicar comentário'
                                : 'Publicar resposta',
                            icon: _sendingComment
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

final class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.avatar,
    required this.date,
    required this.canDelete,
    required this.deleting,
    required this.changingLike,
    required this.highlighted,
    required this.onLike,
    required this.onDelete,
    this.onReply,
    this.onAuthorTap,
    super.key,
  });

  final EvolutionComment comment;
  final Widget avatar;
  final String date;
  final bool canDelete;
  final bool deleting;
  final bool changingLike;
  final bool highlighted;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final VoidCallback? onReply;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: highlighted
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: onAuthorTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 3,
                        ),
                        child: Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '@${comment.authorUsername}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (onAuthorTap != null)
                              const Icon(Icons.open_in_new, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(comment.content),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: changingLike ? null : onLike,
                        icon: changingLike
                            ? const SizedBox.square(
                                dimension: 15,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                comment.likedByMe
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 17,
                              ),
                        label: Text(
                          comment.totalLikes == 0
                              ? 'Curtir'
                              : '${comment.totalLikes}',
                        ),
                      ),
                      if (onReply != null)
                        TextButton.icon(
                          onPressed: onReply,
                          icon: const Icon(Icons.reply_rounded, size: 18),
                          label: const Text('Responder'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (canDelete)
              IconButton(
                onPressed: deleting ? null : onDelete,
                tooltip: 'Excluir comentário',
                icon: deleting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
              ),
          ],
        ),
      ),
    );
  }
}
