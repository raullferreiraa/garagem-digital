import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:garona_mobile/core/network/api_client.dart';
import 'cars_repository.dart';
import 'project_garage.dart';

class GalleryPhotoPublishScreen extends StatefulWidget {
  const GalleryPhotoPublishScreen(
      {required this.carId,
      required this.repository,
      required this.bytes,
      required this.fileName,
      super.key});
  final String carId, fileName;
  final CarsRepository repository;
  final Uint8List bytes;
  @override
  State<GalleryPhotoPublishScreen> createState() =>
      _GalleryPhotoPublishScreenState();
}

class _GalleryPhotoPublishScreenState extends State<GalleryPhotoPublishScreen> {
  final _caption = TextEditingController();
  bool _busy = false, _allowPop = false;
  String? _error;
  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.addGalleryPhoto(
          widget.carId, widget.bytes, widget.fileName,
          caption: _caption.text.trim());
      if (!mounted) return;
      setState(() {
        _allowPop = true;
        _busy = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = apiErrorMessage(error);
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: _allowPop || (!_busy && _caption.text.isEmpty),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _busy) return;
        final discard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Descartar publicação?'),
                    content: const Text(
                        'A foto e a legenda ainda não foram publicadas.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Continuar editando')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Descartar'))
                    ]));
        if (discard == true && mounted) {
          setState(() => _allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
          appBar: AppBar(title: const Text('Publicar foto')),
          body: AbsorbPointer(
              absorbing: _busy,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                AspectRatio(
                    aspectRatio: 1,
                    child: Image.memory(widget.bytes, fit: BoxFit.contain)),
                const SizedBox(height: 24),
                TextField(
                    controller: _caption,
                    onChanged: (_) => setState(() {}),
                    maxLength: 160,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: 'Legenda (opcional)',
                        hintText: 'Ex.: Primeiro passeio depois da revisão.')),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(_error!)),
                const SizedBox(height: 16),
                FilledButton.icon(
                    onPressed: _busy ? null : _publish,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(_busy ? 'Publicando…' : 'Publicar foto')),
              ]))));
}

class GalleryPhotoViewer extends StatefulWidget {
  const GalleryPhotoViewer(
      {required this.photos, required this.initialIndex, super.key});
  final List<ProjectPhoto> photos;
  final int initialIndex;
  @override
  State<GalleryPhotoViewer> createState() => _GalleryPhotoViewerState();
}

class _GalleryPhotoViewerState extends State<GalleryPhotoViewer> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _move(int delta) => _pages.animateToPage(_index + delta,
      duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text('${_index + 1} de ${widget.photos.length}')),
      body: SafeArea(
          child: Column(children: [
        Expanded(
            child: PageView.builder(
                controller: _pages,
                itemCount: widget.photos.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) => InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: Center(
                        child: Image.network(widget.photos[index].url,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Text('Foto indisponível.')))))),
        if (widget.photos[_index].caption.isNotEmpty)
          ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(widget.photos[_index].caption))),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(
              tooltip: 'Foto anterior',
              onPressed: _index > 0 ? () => _move(-1) : null,
              icon: const Icon(Icons.chevron_left)),
          IconButton(
              tooltip: 'Próxima foto',
              onPressed:
                  _index + 1 < widget.photos.length ? () => _move(1) : null,
              icon: const Icon(Icons.chevron_right))
        ]),
      ])));
}
