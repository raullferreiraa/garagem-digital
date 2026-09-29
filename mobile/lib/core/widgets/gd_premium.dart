import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Restrained instrument lines: decorative, static and excluded from semantics.
class GdTechnicalBackdrop extends StatelessWidget {
  const GdTechnicalBackdrop({required this.child, super.key});
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
    final center = Offset(size.width + 12, size.height + 20);
    final radius = math.min(size.width * .65, 180.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = line.withValues(alpha: .22);
    for (final scale in [.7, 1.0, 1.3]) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius * scale),
          math.pi, math.pi / 2, false, paint);
    }
    paint.color = accent.withValues(alpha: .18);
    for (var index = 0; index < 13; index++) {
      final angle = math.pi + index * math.pi / 24;
      final vector = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
          center + vector * (radius - 6), center + vector * radius, paint);
    }
    paint.color = line.withValues(alpha: .12);
    for (var index = 0; index < 3; index++) {
      final x = size.width - 60 + index * 18;
      canvas.drawLine(Offset(x, 0), Offset(x - 32, 72), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InstrumentPainter old) =>
      accent != old.accent || line != old.line;
}

class GdPanel extends StatelessWidget {
  const GdPanel(
      {required this.child,
      this.padding = const EdgeInsets.all(20),
      this.technical = false,
      this.radius = 16,
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
              colors.surfaceContainerHigh.withValues(alpha: .75),
              colors.surfaceContainer
            ]),
      ),
      child: technical ? GdTechnicalBackdrop(child: content) : content,
    );
  }
}

class GdEyebrow extends StatelessWidget {
  const GdEyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 14, height: 2, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 1.6))),
      ]);
}

class GdIntro extends StatelessWidget {
  const GdIntro(
      {required this.eyebrow,
      required this.title,
      required this.description,
      this.action,
      super.key});
  final String eyebrow, title, description;
  final Widget? action;
  @override
  Widget build(BuildContext context) => GdPanel(
      technical: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GdEyebrow(eyebrow),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ));
}

class GdBadge extends StatelessWidget {
  const GdBadge(
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
        borderRadius: BorderRadius.circular(7),
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

class GdEmptyState extends StatelessWidget {
  const GdEmptyState(
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
  Widget build(BuildContext context) => GdPanel(
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
class GdComposerSurface extends StatelessWidget {
  const GdComposerSurface({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.surfaceContainer, colors.surface]),
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: child,
    );
  }
}

class GdActionPair extends StatelessWidget {
  const GdActionPair(
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
