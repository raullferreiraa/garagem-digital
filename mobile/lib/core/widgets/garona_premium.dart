import 'package:flutter/material.dart';

/// Restrained instrument lines: decorative, static and excluded from semantics.
class GaronaTechnicalBackdrop extends StatelessWidget {
  const GaronaTechnicalBackdrop({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(children: [
      Positioned.fill(
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: CustomPaint(
                painter: _InstrumentPainter(colors.primary, colors.outline)),
          ),
        ),
      ),
      child,
    ]);
  }
}

class _InstrumentPainter extends CustomPainter {
  const _InstrumentPainter(this.accent, this.line);
  final Color accent, line;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final glow = Rect.fromLTWH(
        size.width * .35, size.height * .5, size.width * .9, size.height);
    canvas.drawOval(
        glow,
        Paint()
          ..shader = RadialGradient(
            colors: [
              accent.withValues(alpha: .065),
              accent.withValues(alpha: 0)
            ],
          ).createShader(glow));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = line.withValues(alpha: .14);
    for (var i = 0; i < 3; i++) {
      final y = size.height - 12 - i * 7.0;
      canvas.drawPath(
          Path()
            ..moveTo(size.width * .5, y)
            ..quadraticBezierTo(
                size.width * .8, y - 28, size.width + 20, y - 10),
          paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InstrumentPainter old) =>
      accent != old.accent || line != old.line;
}

class GaronaPanel extends StatelessWidget {
  const GaronaPanel(
      {required this.child,
      this.padding = const EdgeInsets.all(20),
      this.technical = false,
      this.radius = 24,
      super.key});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool technical;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Padding(padding: padding, child: child);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colors.outlineVariant),
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.surfaceContainerHigh.withValues(alpha: .78),
              colors.surfaceContainer
            ]),
      ),
      child: technical ? GaronaTechnicalBackdrop(child: content) : content,
    );
  }
}

class GaronaEyebrow extends StatelessWidget {
  const GaronaEyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
        const GaronaLightSignature(width: 24),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1.8))),
      ]);
}

class GaronaIntro extends StatelessWidget {
  const GaronaIntro(
      {required this.eyebrow,
      required this.title,
      required this.description,
      this.action,
      super.key});
  final String eyebrow, title, description;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GaronaEyebrow(eyebrow),
        const SizedBox(height: 14),
        Text(title, style: theme.textTheme.headlineLarge),
        const SizedBox(height: 10),
        Text(description,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        if (action != null) ...[const SizedBox(height: 18), action!],
        const SizedBox(height: 22),
        Row(children: [
          Container(width: 32, height: 2, color: theme.colorScheme.primary),
          Expanded(
              child: Container(
                  height: 1, color: theme.colorScheme.outlineVariant)),
        ]),
      ]),
    );
  }
}

class GaronaBadge extends StatelessWidget {
  const GaronaBadge(
      {required this.label,
      this.icon,
      this.accent = false,
      this.onImage = false,
      super.key});
  final String label;
  final IconData? icon;
  final bool accent;
  final bool onImage;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: onImage
            ? colors.surface.withValues(alpha: .96)
            : accent
                ? colors.primary.withValues(alpha: .10)
                : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: accent
                ? colors.primary.withValues(alpha: .28)
                : colors.outlineVariant),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon,
              size: 14,
              color: accent ? colors.primary : colors.onSurfaceVariant),
          const SizedBox(width: 5)
        ],
        Flexible(
            child: Text(label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: accent
                        ? colors.primary
                        : onImage
                            ? colors.onSurface
                            : colors.onSurfaceVariant))),
      ]),
    );
  }
}

class GaronaEmptyState extends StatelessWidget {
  const GaronaEmptyState(
      {required this.icon,
      required this.title,
      this.description,
      this.action,
      super.key});
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;
  @override
  Widget build(BuildContext context) => GaronaPanel(
      technical: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .18)),
              ),
              child: Icon(icon,
                  size: 28, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(description!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ));
}

/// Shared dock for comments and chats. The caller owns keyboard and safe areas.
class GaronaComposerSurface extends StatelessWidget {
  const GaronaComposerSurface({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.surfaceContainer, colors.surface]),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      child: child,
    );
  }
}

class GaronaActionPair extends StatelessWidget {
  const GaronaActionPair(
      {required this.primary, required this.secondary, super.key});
  final Widget primary, secondary;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(14) > 17) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [primary, const SizedBox(height: 10), secondary]);
        }
        return Row(children: [
          Expanded(child: primary),
          const SizedBox(width: 10),
          Expanded(child: secondary)
        ]);
      });
}

/// Static rear-lamp rhythm used as the brand's small decorative signature.
class GaronaLightSignature extends StatelessWidget {
  const GaronaLightSignature({this.width = 36, super.key});
  final double width;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
          child: SizedBox(
        width: width,
        height: 5,
        child: Row(children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(
                child: Container(
                    decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 1 - i * .18),
                        borderRadius: BorderRadius.circular(4)))),
            if (i < 2) const SizedBox(width: 3),
          ],
        ]),
      ));
}
