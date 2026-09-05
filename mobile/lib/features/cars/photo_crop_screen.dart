import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

final class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({required this.image, super.key});

  final Uint8List image;

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  final _controller = CropController();
  bool _cropping = false;
  String? _errorMessage;

  void _crop() {
    setState(() {
      _cropping = true;
      _errorMessage = null;
    });
    _controller.crop();
  }

  void _onCropped(CropResult result) {
    switch (result) {
      case CropResult.success(:final croppedImage):
        if (mounted) Navigator.of(context).pop(croppedImage);
      case CropResult.error():
        if (!mounted) return;
        setState(() {
          _cropping = false;
          _errorMessage = 'Não foi possível recortar a imagem.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enquadrar foto')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Crop(
                image: widget.image,
                controller: _controller,
                onCropped: _onCropped,
                aspectRatio: 16 / 10,
                initialSize: 0.92,
                interactive: true,
                fixCropRect: true,
                baseColor: const Color(0xFF101114),
                maskColor: const Color(0x99000000),
                radius: 8,
                filterQuality: FilterQuality.high,
                progressIndicator: const CircularProgressIndicator(),
                willUpdateScale: (scale) => scale <= 8,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Arraste para enquadrar e use dois dedos para ampliar.',
                    textAlign: TextAlign.center,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _cropping ? null : _crop,
                    icon: _cropping
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.crop),
                    label: Text(
                      _cropping ? 'Preparando...' : 'Usar este enquadramento',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
