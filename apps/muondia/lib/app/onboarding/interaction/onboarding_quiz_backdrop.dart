import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fondo exclusivo del test: iluminación, órbitas y grano sin un panel exterior.
class OnboardingQuizBackdrop extends CustomPainter {
  const OnboardingQuizBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    void glow(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withAlpha(0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    glow(Offset(w * .40, -h * .06), w * .96, const Color(0xA84F22F5));
    glow(Offset(w * 1.04, h * .24), w * .60, const Color(0x804B14DD));
    glow(Offset(-w * .10, h * .76), w * .72, const Color(0x883C16E5));
    glow(Offset(w * .72, h * 1.10), w * .96, const Color(0x664415F0));

    final orb = Rect.fromCenter(
      center: Offset(w * 1.06, h * .045),
      width: w * .84,
      height: h * .28,
    );
    canvas.drawOval(
      orb,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.18, -.20),
          radius: 1.1,
          colors: [
            Color(0x7B742FFF),
            Color(0x38492BD4),
            Color(0x0034229F),
          ],
        ).createShader(orb),
    );

    void orbit(Path path, {double width = 1.0, Color color = const Color(0x444F35FF)}) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width,
      );
    }

    orbit(
      Path()
        ..moveTo(w * .34, -h * .01)
        ..cubicTo(w * .62, h * .12, w * .71, h * .13, w * 1.08, h * .055),
      width: 1.2,
      color: const Color(0x557A59FF),
    );
    orbit(
      Path()
        ..moveTo(-w * .26, h * .68)
        ..cubicTo(w * .34, h * .75, w * .43, h * .90, w * 1.14, h * .81),
      width: 1.6,
      color: const Color(0x446842FF),
    );
    orbit(
      Path()
        ..moveTo(-w * .16, h * .90)
        ..cubicTo(w * .35, h * .74, w * .60, h * 1.08, w * 1.18, h * .91),
      color: const Color(0x556E48FF),
    );

    final random = math.Random(1406);
    final points = Paint();
    for (var i = 0; i < 540; i++) {
      points.color = Color.fromARGB(7 + random.nextInt(23), 207, 190, 255);
      canvas.drawCircle(
        Offset(random.nextDouble() * w, random.nextDouble() * h),
        .25 + random.nextDouble() * .60,
        points,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant OnboardingQuizBackdrop oldDelegate) => false;
}
