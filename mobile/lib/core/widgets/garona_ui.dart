import 'package:flutter/material.dart';
import 'package:garona_mobile/core/widgets/garona_mark.dart';
import 'package:garona_mobile/core/widgets/garona_premium.dart';

/// Shared visual elements; no network requests besides the requested image.
class GaronaImage extends StatelessWidget {
  const GaronaImage(
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
    Widget placeholder({bool failed = false}) => DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.surfaceContainerHigh, colors.surfaceContainerLow],
          )),
          child: GaronaTechnicalBackdrop(
              child: Center(
                  child: Padding(
            padding: const EdgeInsets.all(8),
            child: !failed && fallbackIcon == Icons.directions_car_outlined
                ? const GaronaCoachwork()
                : Icon(
                    failed ? Icons.image_not_supported_outlined : fallbackIcon,
                    size: 32,
                    color: colors.onSurfaceVariant),
          ))),
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

class GaronaAvatar extends StatelessWidget {
  const GaronaAvatar({super.key, this.url, required this.name, this.size = 40});
  final String? url;
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial =
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .25),
        border: Border.all(color: colors.primary.withValues(alpha: .28)),
        gradient: LinearGradient(
            colors: [colors.primaryContainer, colors.surfaceContainerLow]),
      ),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(size * .25 - 1),
          child: SizedBox.square(
            dimension: size - 4,
            child: url == null || url!.trim().isEmpty
                ? DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primaryContainer,
                        colors.surfaceContainer
                      ],
                    )),
                    child: Center(
                        child: Text(initial,
                            style: TextStyle(
                                fontFamily: 'BarlowCondensed',
                                fontSize: size * .46,
                                fontWeight: FontWeight.w600,
                                color: colors.primary))))
                : GaronaImage(
                    url: url,
                    width: size,
                    height: size,
                    fallbackIcon: Icons.person_outline,
                    semanticLabel: 'Avatar de $name'),
          )),
    );
  }
}

/// One short entrance, never replayed by a refresh of the same widget.
class GaronaReveal extends StatefulWidget {
  const GaronaReveal({super.key, required this.child});
  final Widget child;
  @override
  State<GaronaReveal> createState() => _GaronaRevealState();
}

class _GaronaRevealState extends State<GaronaReveal>
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
class GaronaSkeleton extends StatelessWidget {
  const GaronaSkeleton({super.key, this.compact = false});
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

class GaronaSectionTitle extends StatelessWidget {
  const GaronaSectionTitle(
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
                  GaronaEyebrow(eyebrow!),
                  const SizedBox(height: 8)
                ],
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
              ])),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      );
}

class GaronaWordmark extends StatelessWidget {
  const GaronaWordmark({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Garona',
        excludeSemantics: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          GaronaMark(size: compact ? 25 : 34),
          const SizedBox(width: 10),
          Flexible(
              child: Text('GARONA',
                  maxLines: 1,
                  style: TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      fontSize: compact ? 20 : 26,
                      letterSpacing: compact ? 1.8 : 2.4,
                      color: Theme.of(context).colorScheme.onSurface))),
        ]),
      );
}
