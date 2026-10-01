import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garona_mobile/core/theme/app_theme.dart';
import 'package:garona_mobile/features/evolutions/evolution.dart';
import 'package:garona_mobile/features/evolutions/evolution_carousel.dart';
import 'package:garona_mobile/features/evolutions/evolution_gallery.dart';
import 'package:garona_mobile/features/evolutions/evolution_journal_card.dart';

Future<ui.Image> _photo(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final w = width.toDouble();
  final h = height.toDouble();
  canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF536372));
  canvas.drawRect(Rect.fromLTWH(w * .1, h * .45, w * .8, h * .25),
      Paint()..color = const Color(0xFFDEDFD8));
  canvas.drawRect(Rect.fromLTWH(w * .3, h * .3, w * .4, h * .2),
      Paint()..color = const Color(0xFFDEDFD8));
  for (final x in [.25, .75]) {
    canvas.drawCircle(Offset(w * x, h * .72), w * .08,
        Paint()..color = const Color(0xFF111111));
  }
  canvas.drawRect(
      Rect.fromLTWH(0, 0, w, 12), Paint()..color = const Color(0xFF0000FF));
  canvas.drawRect(Rect.fromLTWH(0, h - 12, w, 12),
      Paint()..color = const Color(0xFF00FF00));
  canvas.drawRect(Rect.fromLTWH(0, 12, 12, h - 24),
      Paint()..color = const Color(0xFFFF0000));
  canvas.drawRect(Rect.fromLTWH(w - 12, 12, 12, h - 24),
      Paint()..color = const Color(0xFFFFFF00));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

Future<void> _preview(WidgetTester tester, String name) async {
  final output = Platform.environment['GD_PREVIEW_DIR'];
  if (output == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('preview')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(output).create(recursive: true);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final font in [
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ('Manrope', 'assets/fonts/Manrope-Variable.ttf'),
      ('BarlowCondensed', 'assets/fonts/BarlowCondensed-SemiBold.ttf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });

  for (final size in [(160, 320), (400, 100)]) {
    testWidgets('prévia preserva as quatro bordas em ${size.$1}x${size.$2}',
        (tester) async {
      final bytes = await tester.runAsync(() async {
        final image = await _photo(size.$1, size.$2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(
          width: 320,
          child: RepaintBoundary(
            key: const ValueKey('preview'),
            child: EvolutionPhotoFrame(
                image: MemoryImage(bytes!),
                label: 'Foto completa',
                maxHeight: 260),
          ),
        ))),
      ));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(EvolutionPhotoFrame)).height,
          lessThanOrEqualTo(260));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('preview')));
      final pixels = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      final colors = <int, int>{};
      for (var i = 0; i < pixels!.length; i += 4) {
        final rgb = (pixels[i] << 16) | (pixels[i + 1] << 8) | pixels[i + 2];
        colors[rgb] = (colors[rgb] ?? 0) + 1;
      }
      for (final edge in [0x0000FF, 0x00FF00, 0xFF0000, 0xFFFF00]) {
        expect(colors[edge] ?? 0, greaterThan(100),
            reason: 'Borda $edge foi cortada');
      }
      await _preview(tester, 'foto-${size.$1}x${size.$2}');
      expect(tester.takeException(), isNull);
    });
  }

  for (final layout in [(390.0, 1.0), (320.0, 1.4)]) {
    testWidgets('carrossel abre galeria e gerencia registro em ${layout.$1}px',
        (tester) async {
      tester.view.physicalSize = Size(layout.$1, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final photo = await tester.runAsync(() => _photo(400, 600));
      final urls = [
        'https://example.com/evo-1.png',
        'https://example.com/evo-2.png'
      ];
      for (final url in urls) {
        PaintingBinding.instance.imageCache.putIfAbsent(
            NetworkImage(url),
            () => OneFrameImageStreamCompleter(
                Future.value(ImageInfo(image: photo!.clone()))));
      }
      photo!.dispose();
      final evolution = Evolution(
        id: 'evo',
        carId: 'car',
        title: 'Troca de radiador',
        description:
            'Troca completa do radiador e revisão do sistema de arrefecimento do Omega.',
        authorName: 'Raul',
        authorUsername: 'raul',
        createdAt: DateTime(2026, 9, 29),
        category: 'mecanica',
        mileageKm: 567886,
        photos: [
          for (var i = 0; i < urls.length; i++)
            EvolutionPhoto(
                id: 'photo-$i', url: urls[i], createdAt: DateTime(2026))
        ],
      );
      final second = Evolution(
        id: 'evo-2',
        carId: 'car',
        title: 'Troca dos pneus',
        description: 'Troca dos quatro pneus.',
        category: 'manutencao',
        authorName: 'Raul',
        authorUsername: 'raul',
        createdAt: DateTime(2026, 8, 12),
      );
      EvolutionJournalAction? action;
      var opened = false;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(layout.$2)),
            child: child!),
        home: Builder(
            builder: (context) => RepaintBoundary(
                key: const ValueKey('preview'),
                child: Scaffold(
                  appBar: AppBar(title: const Text('Evoluções')),
                  body: SingleChildScrollView(
                      child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: EvolutionCarousel(
                      evolutions: [evolution, second],
                      onOpen: (entry) {
                        opened = true;
                        Navigator.of(context).push<void>(MaterialPageRoute(
                            builder: (_) => Scaffold(
                                  appBar: AppBar(title: Text(entry.title)),
                                  body: ListView(
                                      padding: const EdgeInsets.all(20),
                                      children: [
                                        EvolutionGallery(evolution: entry)
                                      ]),
                                )));
                      },
                      onManage: (value, entry) => action = value,
                    ),
                  )),
                ))),
      ));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(EvolutionPhotoFrame).first).height,
          lessThanOrEqualTo(260));
      await tester.ensureVisible(find.byType(PageView));
      await tester.pumpAndSettle();
      await _preview(tester, 'diario-${layout.$1.toInt()}');
      await tester.tap(find.text('Ver evolução').hitTestable().first);
      await tester.pumpAndSettle();
      expect(opened, isTrue);
      await tester.ensureVisible(find.byTooltip('Próxima foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Próxima foto'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.tap(find.text('Ampliar'));
      await tester.pumpAndSettle();
      expect(find.text('2 de 2'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(find.text('1 de 2'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      final options = find.descendant(
        of: find.byKey(const ValueKey('evo')),
        matching: find.byTooltip('Opções da evolução'),
      );
      expect(find.text('1 de 2 evoluções'), findsOneWidget);
      await tester.tap(options);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gerenciar fotos'));
      await tester.pumpAndSettle();
      expect(action, EvolutionJournalAction.photos);
      expect(tester.takeException(), isNull);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
  }
}
