import 'dart:convert';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/features/cars/photo_crop_screen.dart';

void main() {
  testWidgets('recorte bloqueia zoom automático mas permite zoom manual',
      (tester) async {
    final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');
    await tester.pumpWidget(MaterialApp(home: PhotoCropScreen(image: bytes)));
    final crop = tester.widget<Crop>(find.byType(Crop));
    final builder = crop.initialRectBuilder as WithBuilderInitialRectBuilder;
    builder.build(const Rect.fromLTWH(0, 0, 360, 600),
        const Rect.fromLTWH(0, 210, 360, 180));
    expect(crop.willUpdateScale!(600 / 180), isFalse);
    expect(crop.willUpdateScale!(1), isTrue);
    expect(crop.willUpdateScale!(2), isTrue);
    expect(crop.willUpdateScale!(.9), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final image in [
    const Rect.fromLTWH(0, 100, 360, 180),
    const Rect.fromLTWH(80, 0, 180, 600),
    const Rect.fromLTWH(0, 50, 360, 360)
  ]) {
    for (final ratio in [1.0, 16 / 9, 16 / 10]) {
      test('recorte máximo sem zoom: $image, proporção $ratio', () {
        final crop = initialPhotoCropRect(image, ratio);
        expect(crop.center, image.center);
        expect(crop.width / crop.height, closeTo(ratio, .0001));
        expect(crop.left, greaterThanOrEqualTo(image.left - .0001));
        expect(crop.right, lessThanOrEqualTo(image.right + .0001));
        expect(crop.top, greaterThanOrEqualTo(image.top - .0001));
        expect(crop.bottom, lessThanOrEqualTo(image.bottom + .0001));
        expect(
            (crop.width - image.width).abs() < .0001 ||
                (crop.height - image.height).abs() < .0001,
            isTrue);
      });
    }
  }
}
