import 'package:flutter/material.dart';
import 'package:garagem_mobile/features/messages/message_reply.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.messageId,
    required this.content,
    required this.createdAt,
    required this.mine,
    required this.deleted,
    required this.edited,
    this.authorName,
    this.reply,
    this.replyAuthorName,
    this.onLongPress,
    this.onReplyTap,
    this.highlighted = false,
    super.key,
  });

  final String messageId, content;
  final DateTime createdAt;
  final bool mine, deleted, edited;
  final String? authorName, replyAuthorName;
  final MessageReply? reply;
  final VoidCallback? onLongPress;
  final VoidCallback? onReplyTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final highlightColor = mine ? colors.secondary : colors.primary;
    final foreground = colors.onSurface;
    final background = mine
        ? Color.alphaBlend(
            colors.primary.withValues(alpha: highlighted ? .46 : .28),
            colors.surfaceContainerHigh,
          )
        : Color.alphaBlend(
            colors.primary.withValues(alpha: highlighted ? .10 : 0),
            colors.surfaceContainerHigh,
          );
    final time = createdAt.toLocal();
    final timestamp =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Semantics(
          hint: deleted ? null : 'Segure para ver as opções da mensagem',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: deleted ? null : onLongPress,
            onSecondaryTap: deleted ? null : onLongPress,
            child: AnimatedContainer(
              key: ValueKey('message-bubble-$messageId'),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * .80),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: background,
                border: Border.all(
                  color: highlighted
                      ? highlightColor
                      : mine
                          ? colors.primary.withValues(alpha: .28)
                          : colors.outlineVariant,
                  width: highlighted ? 3 : 1,
                ),
                boxShadow: highlighted
                    ? [
                        BoxShadow(
                          color: highlightColor.withValues(alpha: .48),
                          blurRadius: 18,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(mine ? 16 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 16),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (authorName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(authorName!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  if (reply != null && !deleted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Semantics(
                        button: true,
                        label: 'Ver mensagem original',
                        child: GestureDetector(
                          onTap: onReplyTap,
                          child: MessageQuote(
                            author: replyAuthorName ?? 'Mensagem',
                            content: reply!.displayContent,
                            color: foreground,
                          ),
                        ),
                      ),
                    ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      Text(content,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: foreground,
                            fontStyle: deleted ? FontStyle.italic : null,
                          )),
                      Text(
                        '${edited && !deleted ? 'editada · ' : ''}$timestamp',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          color: mine
                              ? foreground.withValues(alpha: .72)
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MessageQuote extends StatelessWidget {
  const MessageQuote(
      {required this.author,
      required this.content,
      required this.color,
      super.key});
  final String author, content;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          border: Border(
              left: BorderSide(color: color.withValues(alpha: .6), width: 3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w700)),
            Text(content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: color)),
          ],
        ),
      );
}

class MessageReplyBar extends StatelessWidget {
  const MessageReplyBar(
      {required this.author,
      required this.content,
      required this.onCancel,
      super.key});
  final String author, content;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
        child: Row(children: [
          Expanded(
              child: MessageQuote(
            author: 'Respondendo a $author',
            content: content,
            color: Theme.of(context).colorScheme.onSurface,
          )),
          IconButton(
              onPressed: onCancel,
              tooltip: 'Cancelar resposta',
              icon: const Icon(Icons.close_rounded)),
        ]),
      );
}
