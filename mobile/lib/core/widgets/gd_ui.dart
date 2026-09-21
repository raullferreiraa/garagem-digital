import 'package:flutter/material.dart';

/// Shared visual elements; no network requests besides the requested image.
class GdImage extends StatelessWidget {
  const GdImage(
      {super.key,
      this.url,
      this.semanticLabel,
      this.fit = BoxFit.cover,
      this.width,
      this.height,
      this.fallbackIcon = Icons.directions_car_outlined});
  final String? url;
  final String? semanticLabel;
  final BoxFit fit;
  final double? width;
  final double? height;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget placeholder({bool failed = false}) => ColoredBox(
          color: colors.surfaceContainerHigh,
          child: Center(
              child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
                failed ? Icons.image_not_supported_outlined : fallbackIcon,
                size: 32,
                color: colors.onSurfaceVariant),
          )),
        );
    final source = url?.trim();
    return Semantics(
      image: true,
      label: semanticLabel,
      child: SizedBox(
        width: width,
        height: height,
        child: source == null || source.isEmpty
            ? placeholder()
            : Image.network(
                source,
                width: width,
                height: height,
                fit: fit,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => placeholder(failed: true),
                frameBuilder: (context, child, frame, synchronous) {
                  if (synchronous) return child;
                  return Stack(fit: StackFit.passthrough, children: [
                    Positioned.fill(child: placeholder()),
                    AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 240),
                      child: child,
                    ),
                  ]);
                },
              ),
      ),
    );
  }
}

class GdAvatar extends StatelessWidget {
  const GdAvatar({super.key, this.url, required this.name, this.size = 40});
  final String? url;
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial =
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .3),
      child: SizedBox.square(
        dimension: size,
        child: url == null || url!.trim().isEmpty
            ? ColoredBox(
                color: colors.surfaceContainerHighest,
                child: Center(
                    child: Text(initial,
                        style: TextStyle(
                            fontFamily: 'BarlowCondensed',
                            fontSize: size * .46,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface))))
            : GdImage(
                url: url,
                width: size,
                height: size,
                fallbackIcon: Icons.person_outline,
                semanticLabel: 'Avatar de $name'),
      ),
    );
  }
}

/// One short entrance, never replayed by a refresh of the same widget.
class GdReveal extends StatefulWidget {
  const GdReveal({super.key, required this.child});
  final Widget child;
  @override
  State<GdReveal> createState() => _GdRevealState();
}

class _GdRevealState extends State<GdReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320));
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_started) {
      _controller.forward();
    }
    _started = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (_, child) {
          final value = Curves.easeOutCubic.transform(_controller.value);
          return Opacity(
              opacity: value,
              child: Transform.translate(
                  offset: Offset(0, 10 * (1 - value)), child: child));
        },
      );
}

/// A bounded pulse avoids perpetual GPU work on slow/offline connections.
class GdSkeleton extends StatelessWidget {
  const GdSkeleton({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget bar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8)));
    return Semantics(
      label: 'Carregando conteúdo',
      liveRegion: true,
      child: ExcludeSemantics(
          child: TweenAnimationBuilder<double>(
        tween: Tween(begin: .4, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 850),
        curve: Curves.easeOut,
        builder: (_, value, child) => Opacity(opacity: value, child: child),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: List.generate(
              compact ? 5 : 2,
              (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: colors.surfaceContainer,
                          borderRadius: BorderRadius.circular(16)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              bar(36, 36),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    bar(110, 10),
                                    const SizedBox(height: 8),
                                    bar(70, 8)
                                  ]))
                            ]),
                            if (!compact) ...[
                              const SizedBox(height: 16),
                              AspectRatio(
                                  aspectRatio: 16 / 10,
                                  child: bar(double.infinity, double.infinity)),
                              const SizedBox(height: 16),
                              bar(160, 18),
                              const SizedBox(height: 10),
                              bar(100, 10)
                            ],
                          ]),
                    ),
                  )),
        ),
      )),
    );
  }
}

class GdSectionTitle extends StatelessWidget {
  const GdSectionTitle(
      {super.key, required this.title, this.eyebrow, this.trailing});
  final String title;
  final String? eyebrow;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6)
                ],
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
              ])),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      );
}

class GdWordmark extends StatelessWidget {
  const GdWordmark({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Garagem Digital',
        excludeSemantics: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              width: 28,
              height: 28,
              child: CustomPaint(
                  painter:
                      _StripesPainter(Theme.of(context).colorScheme.primary))),
          const SizedBox(width: 10),
          Flexible(
              child: Text(compact ? 'GD' : 'GARAGEM DIGITAL',
                  style: TextStyle(
                      fontFamily: 'BarlowCondensed',
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 25 : 22,
                      letterSpacing: 1.4,
                      color: Theme.of(context).colorScheme.onSurface))),
        ]),
      );
}

class _StripesPainter extends CustomPainter {
  const _StripesPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var i = 0; i < 3; i++) {
      final x = i * size.width / 3;
      canvas.drawPath(
          Path()
            ..moveTo(x + 6, 3)
            ..lineTo(x + 11, 3)
            ..lineTo(x + 3, size.height - 3)
            ..lineTo(x - 2, size.height - 3)
            ..close(),
          paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StripesPainter oldDelegate) =>
      color != oldDelegate.color;
}
