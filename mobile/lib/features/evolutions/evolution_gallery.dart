import 'package:flutter/material.dart';
import 'package:garona_mobile/features/evolutions/evolution.dart';
import 'package:garona_mobile/features/evolutions/evolution_photos_screen.dart';

/// Keeps the complete photo visible, including portraits and panoramas.
class EvolutionPhotoFrame extends StatefulWidget {
  const EvolutionPhotoFrame({
    required this.image,
    required this.label,
    this.maxHeight = 420,
    this.onTap,
    super.key,
  }) : assert(maxHeight > 0);

  final ImageProvider image;
  final String label;
  final double maxHeight;
  final VoidCallback? onTap;

  @override
  State<EvolutionPhotoFrame> createState() => _EvolutionPhotoFrameState();
}

class _EvolutionPhotoFrameState extends State<EvolutionPhotoFrame> {
  ImageStream? _stream;
  late final _listener = ImageStreamListener(_loaded, onError: (_, __) {});
  double _ratio = 4 / 3;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(EvolutionPhotoFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) {
      _ratio = 4 / 3;
      _resolve();
    }
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _loaded(ImageInfo info, bool synchronous) {
    final ratio = info.image.width / info.image.height;
    info.dispose();
    if (!mounted || _ratio == ratio) return;
    setState(() => _ratio = ratio);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: widget.label,
        image: true,
        button: widget.onTap != null,
        child: InkWell(
          onTap: widget.onTap,
          child: LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              width: constraints.maxWidth,
              height: (constraints.maxWidth / _ratio.clamp(0.8, 2.0))
                  .clamp(0.0, widget.maxHeight),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Image(
                  image: widget.image,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.image_not_supported_outlined, size: 32),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class EvolutionGallery extends StatefulWidget {
  const EvolutionGallery({
    required this.evolution,
    this.maxPhotoHeight = 420,
    super.key,
  });
  final Evolution evolution;
  final double maxPhotoHeight;

  @override
  State<EvolutionGallery> createState() => _EvolutionGalleryState();
}

class _EvolutionGalleryState extends State<EvolutionGallery> {
  int _index = 0;

  void _open(int index) => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => EvolutionPhotoViewer(
            photos: widget.evolution.photos,
            initialIndex: index,
          ),
        ),
      );

  @override
  void didUpdateWidget(EvolutionGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.evolution.photos.length) _index = 0;
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.evolution.photos;
    if (photos.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: EvolutionPhotoFrame(
            key: ValueKey(photos[_index].id),
            image: NetworkImage(photos[_index].url),
            maxHeight: widget.maxPhotoHeight,
            label:
                'Foto ${_index + 1} de ${photos.length}: ${widget.evolution.title}',
            onTap: () => _open(_index),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (photos.length > 1) ...[
              IconButton(
                tooltip: 'Foto anterior',
                visualDensity: VisualDensity.compact,
                onPressed: _index == 0 ? null : () => setState(() => _index--),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text('${_index + 1} / ${photos.length}',
                  style: Theme.of(context).textTheme.labelMedium),
              IconButton(
                tooltip: 'Próxima foto',
                visualDensity: VisualDensity.compact,
                onPressed: _index == photos.length - 1
                    ? null
                    : () => setState(() => _index++),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ] else
              Icon(Icons.photo_outlined,
                  size: 16, color: colors.onSurfaceVariant),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _open(_index),
              icon: const Icon(Icons.zoom_out_map_rounded, size: 16),
              label: const Text('Ampliar'),
            ),
          ],
        ),
      ],
    );
  }
}
