import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../pivot_images.dart';

/// Resultado DEFINITIVO de una pregunta. Un fallo con corazón todavía
/// disponible no cambia la esfera hasta acertar o agotar los reintentos.
enum QuizOutcome { pending, correct, incorrect }

/// Umbrales del anillo: 60–21 verde, 20–6 amarillo y 5–0 rojo.
Color quizTimerColor(int seconds) =>
    seconds >= 21
        ? const Color(0xFF00E8A1)
        : seconds >= 6
            ? const Color(0xFFFFD439)
            : const Color(0xFFFF355C);

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
    final scale = (MediaQuery.sizeOf(context).width / 390.0)
        .clamp(0.82, 1.1).toDouble();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 3 * scale, vertical: 5 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (imagePath != null) ...[
                SizedBox(
                  key: const Key('muondia-pivot-icon'),
                  width: 44 * scale,
                  height: 44 * scale,
                  child: Image.asset(imagePath, fit: BoxFit.contain,
                      filterQuality: FilterQuality.high),
                ),
                SizedBox(width: 10 * scale),
              ],
              Expanded(
                child: Text(
                  pivot,
                  key: const Key('muondia-pivot-title'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MuondiaTypography.screenTitle.copyWith(
                    color: Colors.white,
                    fontSize: 28 * scale,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(color: Color(0xE5160A55), blurRadius: 9,
                          offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 13 * scale),
          Row(
            key: const Key('muondia-quiz-status'),
            children: [
              Expanded(
                child: Semantics(
                  label: 'Progreso de preguntas',
                  value: 'Pregunta $questionNumber de $questionCount',
                  child: Row(
                    key: const Key('muondia-progress-orbs'),
                    children: [
                      for (var i = 0; i < progress.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 1 * scale),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: DecoratedBox(
                                key: Key('muondia-progress-orb-$i'),
                                decoration: _orbDecoration(progress[i]),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 9 * scale),
                height: 33 * scale,
                width: 1.3 * scale,
                color: const Color(0xB5B9A8FF),
              ),
              Semantics(
                label: 'Corazones disponibles',
                value: hearts.toString(),
                child: Row(
                  key: const Key('muondia-hearts'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/onboarding/test/Reintento.png',
                      width: 32 * scale,
                      height: 32 * scale,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(width: 2 * scale),
                    Text(
                      '$hearts',
                      key: const Key('muondia-hearts-count'),
                      style: MuondiaTypography.sectionTitle.copyWith(
                        color: Colors.white, fontSize: 23 * scale,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 9 * scale),
              Semantics(
                label: 'Tiempo restante del test',
                value: '$secondsRemaining segundos',
                child: SizedBox(
                  key: const Key('muondia-timer-ring'),
                  width: 65 * scale,
                  height: 65 * scale,
                  child: CustomPaint(
                    painter: _CountdownPainter(timeFraction, secondsRemaining),
                    child: Center(
                      child: Text(
                        secondsRemaining.toString() + 's',
                        key: const Key('muondia-test-seconds'),
                        style: MuondiaTypography.screenTitle.copyWith(
                          color: Colors.white,
                          fontSize: 22 * scale,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _orbDecoration(QuizOutcome result) {
    final colors = switch (result) {
      QuizOutcome.correct => const [Color(0xFFE2FFE9), Color(0xFF2AFF97),
          Color(0xFF00C882)],
      QuizOutcome.incorrect => const [Color(0xFFFFE1E1), Color(0xFFFF476C),
          Color(0xFFD80C45)],
      QuizOutcome.pending => const [Color(0xAA7F55DF), Color(0xAA340E93),
          Color(0x88301065)],
    };
    return BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 0.87,
        colors: colors,
      ),
      border: Border.all(
        color: result == QuizOutcome.pending
            ? const Color(0xFFA75AFF) : const Color(0xFFA5FFF5),
        width: 1.4,
      ),
      boxShadow: [
        BoxShadow(
          color: result == QuizOutcome.correct
              ? const Color(0x6600FF99)
              : result == QuizOutcome.incorrect
                  ? const Color(0x66F21254)
                  : const Color(0x663E08B8),
          blurRadius: 6,
        ),
      ],
    );
  }
}

class _CountdownPainter extends CustomPainter {
  const _CountdownPainter(this.fraction, this.seconds);

  final double fraction;
  final int seconds;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final arc = bounds.deflate(5);
    final track = Paint()
      ..color = const Color(0xAA6B4EB2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    final color = quizTimerColor(seconds);
    final active = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;
    canvas.drawArc(arc, 0, 2 * math.pi, false, track);
    if (fraction > 0) {
      canvas.drawArc(
        arc,
        -math.pi / 2,
        2 * math.pi * fraction.clamp(0.0, 1.0),
        false,
        active,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CountdownPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.seconds != seconds;
}
