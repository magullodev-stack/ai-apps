import 'dart:math' as math;

import 'package:flutter/material.dart';

enum QuizAiLogoExpression {
  blink,
  wink,
  mischief,
}

/// Interactive QuizAI wordmark.
///
/// The raster asset remains the source of truth for the logo artwork. Flutter
/// only owns the lightweight eye reaction shown when the user taps the logo.
/// This lets the PNG be replaced without changing the interaction code as long
/// as its canvas and composition are preserved.
class QuizAiLogo extends StatefulWidget {
  const QuizAiLogo({
    super.key,
    this.height = 60,
    this.assetPath = 'assets/branding/quizai_logo.png',
  });

  final double height;
  final String assetPath;

  @override
  State<QuizAiLogo> createState() => _QuizAiLogoState();
}

class _QuizAiLogoState extends State<QuizAiLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _expressionIndex = 0;

  QuizAiLogoExpression get _expression =>
      QuizAiLogoExpression.values[_expressionIndex];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controller.reset();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _react() {
    if (_controller.isAnimating) {
      return;
    }

    setState(() {
      _expressionIndex =
          (_expressionIndex + 1) % QuizAiLogoExpression.values.length;
    });
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Logo de QuizAI. Toca para saludar.',
      child: GestureDetector(
        key: const Key('quizai-logo-gesture'),
        behavior: HitTestBehavior.opaque,
        onTap: _react,
        child: SizedBox(
          height: widget.height,
          child: AspectRatio(
            aspectRatio: 3,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      widget.assetPath,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _QuizAiLogoEyesPainter(
                          progress: _controller.value,
                          expression: _expression,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizAiLogoEyesPainter extends CustomPainter {
  const _QuizAiLogoEyesPainter({
    required this.progress,
    required this.expression,
  });

  final double progress;
  final QuizAiLogoExpression expression;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) {
      return;
    }

    final phase = math.sin(math.pi * progress);
    final overlayOpacity = _overlayOpacity(progress);

    _coverRasterEyes(canvas, size, overlayOpacity);

    switch (expression) {
      case QuizAiLogoExpression.blink:
        final blink = math.sin(2 * math.pi * progress).abs();
        _paintEye(
          canvas,
          size,
          center: const Offset(0.208, 0.515),
          openness: 1 - (0.82 * blink),
          opacity: overlayOpacity,
        );
        _paintEye(
          canvas,
          size,
          center: const Offset(0.291, 0.515),
          openness: 1 - (0.82 * blink),
          opacity: overlayOpacity,
        );

      case QuizAiLogoExpression.wink:
        _paintEye(
          canvas,
          size,
          center: const Offset(0.208, 0.515),
          openness: 1 - (0.92 * phase),
          opacity: overlayOpacity,
        );
        _paintEye(
          canvas,
          size,
          center: Offset(0.291, 0.515 - (0.012 * phase)),
          openness: 1 + (0.10 * phase),
          opacity: overlayOpacity,
        );

      case QuizAiLogoExpression.mischief:
        final drift = 0.009 * phase;
        _paintEye(
          canvas,
          size,
          center: Offset(0.208 + drift, 0.515 - (0.014 * phase)),
          openness: 0.90 + (0.08 * phase),
          tilt: -0.16 * phase,
          opacity: overlayOpacity,
        );
        _paintEye(
          canvas,
          size,
          center: Offset(0.291 + drift, 0.515 + (0.008 * phase)),
          openness: 1.05,
          tilt: 0.13 * phase,
          opacity: overlayOpacity,
        );
    }
  }

  double _overlayOpacity(double t) {
    if (t < 0.12) {
      return t / 0.12;
    }
    if (t > 0.88) {
      return (1 - t) / 0.12;
    }
    return 1;
  }

  void _coverRasterEyes(Canvas canvas, Size size, double opacity) {
    final left = Offset(size.width * 0.208, size.height * 0.515);
    final right = Offset(size.width * 0.291, size.height * 0.515);
    final maskPaint = Paint()
      ..color = const Color(0xFF17005C).withValues(alpha: 0.96 * opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * 0.035);

    final rx = size.width * 0.026;
    final ry = size.height * 0.085;

    canvas.drawOval(
      Rect.fromCenter(
        center: left,
        width: rx * 2,
        height: ry * 2,
      ),
      maskPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: right,
        width: rx * 2,
        height: ry * 2,
      ),
      maskPaint,
    );
  }

  void _paintEye(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double openness,
    required double opacity,
    double tilt = 0,
  }) {
    final cx = size.width * center.dx;
    final cy = size.height * center.dy;
    final halfWidth = size.width * 0.0205;
    final curveHeight = size.height * 0.075 * openness;
    final strokeWidth = size.height * 0.052;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(tilt);

    final path = Path()
      ..moveTo(-halfWidth, curveHeight * 0.34)
      ..quadraticBezierTo(
        0,
        -curveHeight,
        halfWidth,
        curveHeight * 0.34,
      );

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth * 1.9
      ..color = const Color(0xFFD943FF).withValues(alpha: 0.56 * opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 1.35);

    final eyePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFFFFF4FF).withValues(alpha: opacity);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, eyePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _QuizAiLogoEyesPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.expression != expression;
  }
}
