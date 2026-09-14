import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';
import 'package:garagem_mobile/features/evolutions/evolution_interactions.dart';
import 'package:garagem_mobile/features/evolutions/evolution_photos_screen.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';

final class EvolutionDetailScreen extends StatefulWidget {
  const EvolutionDetailScreen({
    required this.evolution,
    required this.repository,
    required this.currentUserId,
    super.key,
  });

  final Evolution evolution;
  final EvolutionsRepository repository;
  final String currentUserId;

  @override
  State<EvolutionDetailScreen> createState() => _EvolutionDetailScreenState();
}

final class _EvolutionDetailScreenState extends State<EvolutionDetailScreen> {
  final _commentController = TextEditingController();
  late Future<EvolutionInteractions> _future;
  EvolutionInteractions? _interactions;
  bool _changingLike = false;
  bool _sendingComment = false;
  final Set<String> _deletingComments = {};

  @override
  void initState() {
    super.initState();
    _future = _fetchInteractions();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<EvolutionInteractions> _fetchInteractions() async {
    final interactions = await widget.repository.interactions(
      widget.evolution.carId,
      widget.evolution.id,
    );
    if (mounted) {
      setState(() => _interactions = interactions);
    } else {
      _interactions = interactions;
    }
    return interactions;
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

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    final current = _interactions;
    if (content.isEmpty || current == null || _sendingComment) return;

    FocusScope.of(context).unfocus();
    setState(() => _sendingComment = true);
    try {
      final comment = await widget.repository.comment(
        widget.evolution.carId,
        widget.evolution.id,
        content,
      );
      if (!mounted) return;
      _commentController.clear();
      setState(() {
        _interactions = current.copyWith(
          comments: [...current.comments, comment],
        );
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
        _interactions = _interactions?.copyWith(
          comments: _interactions!.comments
              .where((item) => item.id != comment.id)
              .toList(growable: false),
        );
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
    final fallback = comment.authorName.trim().isEmpty
        ? '?'
        : comment.authorName.trim()[0].toUpperCase();
    return CircleAvatar(
      backgroundImage: comment.authorAvatarUrl == null
          ? null
          : NetworkImage(comment.authorAvatarUrl!),
      child: comment.authorAvatarUrl == null ? Text(fallback) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final evolution = widget.evolution;
    return Scaffold(
      appBar: AppBar(title: const Text('Evolução do projeto')),
      body: FutureBuilder<EvolutionInteractions>(
        future: _future,
        builder: (context, snapshot) {
          final interactions = _interactions ?? snapshot.data;
          if (interactions == null &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              children: [
                Text(
                  evolution.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${evolution.authorName}  @${evolution.authorUsername}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.calendar_today_outlined, size: 17),
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
                              child: Image.network(
                                photo.url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const ColoredBox(
                                  color: Color(0xFF24262A),
                                  child: Icon(Icons.broken_image_outlined),
                                ),
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
                Row(
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
                    const SizedBox(width: 14),
                    Icon(
                      Icons.mode_comment_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      interactions.comments.length == 1
                          ? '1 comentário'
                          : '${interactions.comments.length} comentários',
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
                          _CommentTile(
                            comment: interactions.comments[index],
                            avatar: _avatar(interactions.comments[index]),
                            date: _formatDate(
                              interactions.comments[index].createdAt,
                            ),
                            canDelete: interactions.comments[index].authorId ==
                                widget.currentUserId,
                            deleting: _deletingComments.contains(
                              interactions.comments[index].id,
                            ),
                            onDelete: () => _deleteComment(
                              interactions.comments[index],
                            ),
                          ),
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 1000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Escreva um comentário...',
                            counterText: '',
                          ),
                          onSubmitted: (_) => _sendComment(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sendingComment ? null : _sendComment,
                        tooltip: 'Publicar comentário',
                        icon: _sendingComment
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
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
    required this.onDelete,
  });

  final EvolutionComment comment;
  final Widget avatar;
  final String date;
  final bool canDelete;
  final bool deleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                Wrap(
                  spacing: 6,
                  children: [
                    Text(
                      comment.authorName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text('@${comment.authorUsername}'),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 8),
                Text(comment.content),
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
    );
  }
}
