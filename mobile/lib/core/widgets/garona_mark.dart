import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A machined G: an open circuit with a short inward apex.
/// Kept as vector geometry so it stays sharp at every display density.
class GaronaMark extends StatelessWidget {
  const GaronaMark({super.key, this.size = 32, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: GaronaMarkPainter(
                color ?? Theme.of(context).colorScheme.primary),
          ),
        ),
      );
}

class GaronaMarkPainter extends CustomPainter {
  const GaronaMarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);
    final path = Path()
      ..moveTo(33, 10)
      ..lineTo(27, 4)
      ..lineTo(12, 4)
      ..lineTo(4, 12)
      ..lineTo(4, 28)
      ..lineTo(12, 36)
      ..lineTo(28, 36)
      ..lineTo(36, 28)
      ..lineTo(36, 18)
      ..lineTo(21, 18)
      ..lineTo(21, 24)
      ..lineTo(30, 24)
      ..lineTo(30, 26)
      ..lineTo(25, 30)
      ..lineTo(15, 30)
      ..lineTo(10, 25)
      ..lineTo(10, 15)
      ..lineTo(15, 10)
      ..lineTo(25, 10)
      ..lineTo(29, 14)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(GaronaMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Quiet coachwork study for empty project covers.
class GaronaCoachwork extends StatelessWidget {
  const GaronaCoachwork({super.key, this.height = 88});
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
              painter: _CoachworkPainter(
            Theme.of(context).colorScheme.onSurface,
            Theme.of(context).colorScheme.primary,
          )),
        ),
      );
}

class _CoachworkPainter extends CustomPainter {
  const _CoachworkPainter(this.ink, this.accent);
  final Color ink, accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = math.min(size.width / 320, size.height / 100);
    canvas.translate(
        (size.width - 320 * scale) / 2, (size.height - 100 * scale) / 2);
    canvas.scale(scale);
    final guide = Paint()
      ..color = ink.withValues(alpha: .09)
      ..strokeWidth = .7;
    canvas.drawLine(const Offset(0, 82), const Offset(320, 82), guide);
    for (var x = 12.0; x < 320; x += 16) {
      canvas.drawLine(Offset(x, 87), Offset(x, 91), guide);
    }
    final body = Path()
      ..moveTo(18, 66)
      ..lineTo(22, 53)
      ..lineTo(61, 46)
      ..lineTo(100, 20)
      ..quadraticBezierTo(108, 16, 118, 16)
      ..lineTo(184, 16)
      ..quadraticBezierTo(195, 16, 204, 23)
      ..lineTo(234, 44)
      ..lineTo(284, 51)
      ..lineTo(299, 62)
      ..lineTo(299, 73)
      ..lineTo(281, 75)
      ..cubicTo(281, 43, 237, 43, 237, 76)
      ..lineTo(87, 76)
      ..cubicTo(87, 43, 43, 43, 43, 76)
      ..lineTo(18, 73)
      ..close();
    canvas.drawPath(body, Paint()..color = ink.withValues(alpha: .025));
    canvas.drawPath(
        body,
        Paint()
          ..color = ink.withValues(alpha: .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeJoin = StrokeJoin.round);
    final window = Path()
      ..moveTo(79, 44)
      ..lineTo(107, 24)
      ..lineTo(181, 24)
      ..lineTo(211, 44)
      ..close();
    canvas.drawPath(
        window,
        Paint()
          ..color = ink.withValues(alpha: .24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8);
    canvas.drawLine(const Offset(153, 24), const Offset(153, 43),
        guide..color = ink.withValues(alpha: .3));
    for (final x in [65.0, 259.0]) {
      canvas.drawCircle(
          Offset(x, 70),
          15,
          Paint()
            ..color = ink.withValues(alpha: .5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
      canvas.drawCircle(Offset(x, 70), 7, guide..style = PaintingStyle.stroke);
    }
    canvas.drawLine(
        const Offset(107, 76),
        const Offset(213, 76),
        Paint()
          ..color = accent
          ..strokeWidth = 2);
    canvas.drawLine(
        const Offset(280, 56),
        const Offset(291, 59),
        Paint()
          ..color = accent
          ..strokeWidth = 2);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CoachworkPainter oldDelegate) =>
      ink != oldDelegate.ink || accent != oldDelegate.accent;
}
