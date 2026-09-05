import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:image_picker/image_picker.dart';

enum _PhotoSource { camera, gallery }

final class EvolutionPhotosScreen extends StatefulWidget {
  const EvolutionPhotosScreen({
    required this.evolution,
    required this.repository,
    super.key,
  });

  final Evolution evolution;
  final EvolutionsRepository repository;

  @override
  State<EvolutionPhotosScreen> createState() => _EvolutionPhotosScreenState();
}

class _EvolutionPhotosScreenState extends State<EvolutionPhotosScreen> {
  static const _maximumPhotos = 8;

  late Evolution _evolution = widget.evolution;
  bool _working = false;
  int _uploaded = 0;
  int _uploadTotal = 0;

  Future<void> _choosePhotos() async {
    final available = _maximumPhotos - _evolution.photos.length;
    if (available <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta evolução já possui 8 fotos.')),
      );
      return;
    }

    final source = await showModalBottomSheet<_PhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.of(context).pop(_PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              subtitle: Text('Você pode adicionar até $available agora.'),
              onTap: () => Navigator.of(context).pop(_PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picker = ImagePicker();
      final List<XFile> selected;
      if (source == _PhotoSource.camera) {
        final photo = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 90,
        );
        selected = photo == null ? [] : [photo];
      } else {
        selected = (await picker.pickMultiImage(
            maxWidth: 2048,
            maxHeight: 2048,
            imageQuality: 90,
          ))
            .take(available)
            .toList(growable: false);
      }
      if (selected.isEmpty || !mounted) return;

      setState(() {
        _working = true;
        _uploaded = 0;
        _uploadTotal = selected.length;
      });
      var updated = _evolution;
      for (var index = 0; index < selected.length; index++) {
        updated = await widget.repository.addPhoto(
          updated.carId,
          updated.id,
          bytes: await selected[index].readAsBytes(),
          fileName: 'evolucao-${index + 1}.jpg',
        );
        if (!mounted) return;
        setState(() {
          _evolution = updated;
          _uploaded = index + 1;
        });
      }
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selected.length == 1
                ? 'Foto adicionada à evolução.'
                : '${selected.length} fotos adicionadas à evolução.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
    }
  }

  Future<void> _removePhoto(EvolutionPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover foto?'),
        content: const Text(
          'A foto será removida desta evolução. Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _working = true;
      _uploaded = 0;
      _uploadTotal = 0;
    });
    try {
      final updated = await widget.repository.removePhoto(
        _evolution.carId,
        _evolution.id,
        photo.id,
      );
      if (!mounted) return;
      setState(() {
        _evolution = updated;
        _working = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fotos da evolução')),
      floatingActionButton: _evolution.photos.length >= _maximumPhotos
          ? null
          : FloatingActionButton.extended(
              onPressed: _working ? null : _choosePhotos,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Adicionar'),
            ),
      body: Stack(
        children: [
          if (_evolution.photos.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 72),
                    SizedBox(height: 16),
                    Text(
                      'Adicione fotos para mostrar visualmente esta etapa do projeto.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _evolution.photos.length,
              itemBuilder: (context, index) {
                final photo = _evolution.photos[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => EvolutionPhotoViewer(
                            photos: _evolution.photos,
                            initialIndex: index,
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
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
                    Positioned(
                      right: 6,
                      top: 6,
                      child: IconButton.filled(
                        onPressed: _working ? null : () => _removePhoto(photo),
                        tooltip: 'Remover foto',
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ],
                );
              },
            ),
          if (_working)
            ColoredBox(
              color: const Color(0x88000000),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _uploadTotal > 0
                          ? 'Enviando $_uploaded de $_uploadTotal...'
                          : 'Atualizando...',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class EvolutionPhotoViewer extends StatefulWidget {
  const EvolutionPhotoViewer({
    required this.photos,
    this.initialIndex = 0,
    super.key,
  });

  final List<EvolutionPhoto> photos;
  final int initialIndex;

  @override
  State<EvolutionPhotoViewer> createState() => _EvolutionPhotoViewerState();
}

class _EvolutionPhotoViewerState extends State<EvolutionPhotoViewer> {
  late var _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} de ${widget.photos.length}'),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: widget.initialIndex),
        itemCount: widget.photos.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: Image.network(
              widget.photos[index].url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
