import 'package:flutter/material.dart';

enum MessageAction { copy, reply, edit, delete }

Future<MessageAction?> chooseMessageAction(BuildContext context,
        {required bool mine}) =>
    showModalBottomSheet<MessageAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Responder'),
              onTap: () => Navigator.of(context).pop(MessageAction.reply),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copiar texto'),
              onTap: () => Navigator.of(context).pop(MessageAction.copy),
            ),
            if (mine)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar mensagem'),
                onTap: () => Navigator.of(context).pop(MessageAction.edit),
              ),
            if (mine)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Apagar para todos'),
                onTap: () => Navigator.of(context).pop(MessageAction.delete),
              ),
          ],
        ),
      ),
    );

Future<String?> promptMessageEdit(BuildContext context, String original) =>
    showDialog<String>(
      context: context,
      builder: (context) => _MessageEditDialog(original: original),
    );

final class _MessageEditDialog extends StatefulWidget {
  const _MessageEditDialog({required this.original});

  final String original;

  @override
  State<_MessageEditDialog> createState() => _MessageEditDialogState();
}

final class _MessageEditDialogState extends State<_MessageEditDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.original);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Editar mensagem'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          maxLength: 2000,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'Mensagem'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _controller.text.trim().isEmpty ||
                    _controller.text.trim() == widget.original
                ? null
                : () => Navigator.of(context).pop(_controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      );
}

Future<bool> confirmMessageDelete(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apagar mensagem?'),
        content: const Text(
          'O texto será removido para todos. A conversa mostrará que a mensagem foi apagada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    ) ??
    false;
