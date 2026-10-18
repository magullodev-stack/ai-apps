import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../pivot_images.dart';

/// Solo se marca una pregunta al obtener un resultado definitivo.
enum QuizOutcome { pending, correct, incorrect }

/// La referencia usa anillo magenta; cuando quedan cinco segundos alerta rojo.
Color quizTimerColor(int seconds) => seconds > 5
    ? const Color(0xFFCC64ED)
    : const Color(0xFFFF5277);

/// Las esferas de progreso pertenecen al panel, no a la cabecera.
BoxDecoration quizOrbDecoration(QuizOutcome result) {
  final colors = switch (result) {
    QuizOutcome.correct => const [
        Color(0xFF12F38E),
        Color(0xFF00E77C),
        Color(0xFF00C96D),
      ],
    QuizOutcome.incorrect => const [
        Color(0xFFFF6476),
        Color(0xFFFF4B64),
        Color(0xFFE92F51),
      ],
    QuizOutcome.pending => const [
        Color(0xFF081936),
        Color(0xFF172E51),
        Color(0xFF0B1D3D),
      ],
  };
  return BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(
      center: const Alignment(-0.25, -0.3),
      radius: 0.85,
      colors: colors,
    ),
    border: Border.all(
      color: result == QuizOutcome.pending
          ? const Color(0xFF305586)
          : Colors.transparent,
      width: 1.2,
    ),
    boxShadow: result == QuizOutcome.pending
        ? const []
        : [
            BoxShadow(
              color: result == QuizOutcome.correct
                  ? const Color(0x3500EA7F)
                  : const Color(0x40FF4D70),
              blurRadius: 6,
            ),
          ],
  );
}

class OnboardingQuizHeader extends StatelessWidget {
  const OnboardingQuizHeader({
    super.key,
    required this.pivot,
    required this.questionNumber,
    required this.questionCount,
    required this.secondsRemaining,
    required this.timeFraction,
    required this.progress,
    required this.hearts,
  });

  final String pivot;
  final int questionNumber;
  final int questionCount;
  final int secondsRemaining;
  final double timeFraction;
  final List<QuizOutcome> progress;
  final int hearts;

  @override
  Widget build(BuildContext context) {
    final imagePath = onboardingPivotImageFor(pivot);
    final scale =
        (MediaQuery.sizeOf(context).width / 390).clamp(0.82, 1.1).toDouble();

    return SizedBox(
      key: const Key('muondia-quiz-status'),
      height: 109 * scale,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              label: 'Corazones disponibles',
              value: hearts.toString(),
              child: Row(
                key: const Key('muondia-hearts'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i != 0) SizedBox(width: 3 * scale),
                    SizedBox(
                      key: Key('muondia-heart-$i'),
                      width: 27 * scale,
                      height: 27 * scale,
                      child: CustomPaint(
                        painter: _HeartPainter(filled: i < hearts),
                      ),
                    ),
                  ],
                  // Conserva un nodo legible en las pruebas sin dibujar
                  // una cifra que no existe en el diseño.
                  SizedBox(
                    key: const Key('muondia-hearts-count'),
                    width: 0,
                    height: 0,
                    child: Text('$hearts', style: const TextStyle(fontSize: 1)),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  key: const Key('muondia-pivot-icon'),
                  width: 56 * scale,
                  height: 56 * scale,
                  child: pivot.toLowerCase() == 'física'
                      ? const CustomPaint(painter: _AtomPainter())
                      : imagePath != null
                          ? Image.asset(
                              imagePath,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            )
                          : const Icon(
                              Icons.auto_awesome_outlined,
                              color: Color(0xFFB9D5FF),
                            ),
                ),
                SizedBox(height: 5 * scale),
                SizedBox(
                  width: 126 * scale,
                  child: Text(
                    pivot,
                    key: const Key('muondia-pivot-title'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MuondiaTypography.sectionTitle.copyWith(
                      color: const Color(0xFFEAF3FF),
                      fontWeight: FontWeight.w600,
                      fontSize: 19 * scale,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              label: 'Tiempo restante del test',
              value: '$secondsRemaining segundos',
              child: SizedBox(
                key: const Key('muondia-timer-ring'),
                width: 64 * scale,
                height: 64 * scale,
                child: CustomPaint(
                  painter: _CountdownPainter(timeFraction, secondsRemaining),
                  child: Center(
                    child: Text(
                      secondsRemaining.toString() + 's',
                      key: const Key('muondia-test-seconds'),
                      style: MuondiaTypography.screenTitle.copyWith(
                        color: const Color(0xFFF7F9FF),
                        fontWeight: FontWeight.w800,
                        fontSize: 18 * scale,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AtomPainter extends CustomPainter {
  const _AtomPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..color = const Color(0xFFD0E0FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..isAntiAlias = true;
    for (final degrees in [0.0, 60.0, -60.0]) {
      canvas.save();
      canvas.rotate(degrees * math.pi / 180);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 52 * size.width / 56,
          height: 21 * size.height / 56,
        ),
        stroke,
      );
      canvas.restore();
    }
    canvas.drawCircle(
      Offset.zero,
      4.5 * size.width / 56,
      Paint()..color = const Color(0xFF19DDF4),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AtomPainter oldDelegate) => false;
}

class _HeartPainter extends CustomPainter {
  const _HeartPainter({required this.filled});

  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * .5, h * .88)
      ..cubicTo(w * .40, h * .77, w * .08, h * .55, w * .08, h * .33)
      ..cubicTo(w * .08, h * .09, w * .39, h * .07, w * .5, h * .27)
      ..cubicTo(w * .65, h * .07, w * .92, h * .09, w * .92, h * .33)
      ..cubicTo(w * .92, h * .55, w * .60, h * .77, w * .5, h * .88)
      ..close();
    if (filled) {
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x7747E7FF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4FEBFF), Color(0xFF13BDEC)],
          ).createShader(Offset.zero & size),
      );
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF304A7C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeartPainter oldDelegate) =>
      oldDelegate.filled != filled;
}

class _CountdownPainter extends CustomPainter {
  const _CountdownPainter(this.fraction, this.seconds);

  final double fraction;
  final int seconds;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = (Offset.zero & size).deflate(6);
    final track = Paint()
      ..color = const Color(0xFF273D71)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.4
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..color = quizTimerColor(seconds)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(bounds, 0, math.pi * 2, false, track);
    if (fraction > 0) {
      canvas.drawArc(
        bounds,
        -math.pi / 2,
        math.pi * 2 * fraction.clamp(0.0, 1.0),
        false,
        active,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CountdownPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.seconds != seconds;
}
