import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:garagem_mobile/features/cars/photo_crop_screen.dart';

/// Upload retries happen after creation, without repeating the create request.
Future<T> uploadFormPhoto<T>(
    BuildContext context, T saved, Future<T> Function() upload) async {
  while (context.mounted) {
    try {
      return await upload();
    } catch (_) {
      if (!context.mounted) return saved;
      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Cadastro salvo; foto não enviada'),
          content: const Text(
              'Seus dados já foram salvos. Tente enviar a foto novamente ou adicione-a depois pela edição.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Continuar sem foto')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Tentar novamente')),
          ],
        ),
      );
      if (retry != true) return saved;
    }
  }
  return saved;
}

class FormSaveGuard extends StatelessWidget {
  const FormSaveGuard({required this.saving, required this.child, super.key});
  final bool saving;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !saving, child: AbsorbPointer(absorbing: saving, child: child));
}

class FormPhoto extends StatefulWidget {
  const FormPhoto(
      {required this.label,
      required this.bytes,
      required this.onChanged,
      this.enabled = true,
      this.compact = false,
      this.aspectRatio = 16 / 10,
      super.key});
  final String label;
  final Uint8List? bytes;
  final ValueChanged<Uint8List?> onChanged;
  final bool enabled;
  final bool compact;
  final double aspectRatio;

  @override
  State<FormPhoto> createState() => _FormPhotoState();
}

class _FormPhotoState extends State<FormPhoto> {
  bool _picking = false;

  Future<void> _pick() async {
    if (_picking || !widget.enabled) return;
    setState(() => _picking = true);
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Usar a câmera'),
              onTap: () => Navigator.pop(context, ImageSource.camera)),
        ])),
      );
      if (source == null || !mounted) return;
      final file = await ImagePicker().pickImage(
          source: source, maxWidth: 2400, maxHeight: 2400, imageQuality: 90);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final cropped = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
            builder: (_) => PhotoCropScreen(
                image: bytes,
                aspectRatio: widget.aspectRatio,
                title: widget.label)),
      );
      if (mounted && widget.enabled && cropped != null)
        widget.onChanged(cropped);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Não foi possível abrir a foto. Tente outra imagem.')));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.bytes != null)
            Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                    width: widget.aspectRatio == 1
                        ? 80
                        : widget.compact
                            ? 192
                            : 256,
                    child: AspectRatio(
                        aspectRatio: widget.aspectRatio,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(widget.bytes!,
                              fit: BoxFit.cover,
                              semanticLabel: 'Prévia: ${widget.label}'),
                        )))),
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.enabled && !_picking ? _pick : null,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_picking
                      ? 'Preparando foto…'
                      : widget.bytes == null
                          ? '${widget.label} (opcional)'
                          : 'Trocar ${widget.label.toLowerCase()}'),
                ),
                if (widget.bytes != null)
                  TextButton(
                    onPressed:
                        widget.enabled ? () => widget.onChanged(null) : null,
                    child: const Text('Remover seleção'),
                  ),
              ]),
        ]),
      );
}
