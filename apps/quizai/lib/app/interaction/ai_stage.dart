import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';

class QuizAiStageMessage {
  const QuizAiStageMessage({
    required this.lead,
    required this.highlight,
    this.support,
  });

  final String lead;
  final String highlight;
  final String? support;
}

/// Escenario visual de interacción de QuizAI.
///
/// No conoce modalidades, onboarding ni generación. Recibe una escena,
/// una intervención y un progreso, y únicamente los representa.
class QuizAiStage extends StatelessWidget {
  const QuizAiStage({
    super.key,
    required this.scene,
    required this.message,
    required this.messageKey,
    required this.progress,
  });

  final Widget scene;
  final QuizAiStageMessage message;
  final Object messageKey;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF14044B),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: QuizPalette.backgroundDark,
        body: Stack(
          fit: StackFit.expand,
          children: [
            scene,
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 52),
                child: Column(
                  children: [
                    const Spacer(flex: 11),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Semantics(
                        liveRegion: true,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 420),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.05),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: _StageCopy(
                            key: ValueKey(messageKey),
                            message: message,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(flex: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: _StageProgress(progress: progress),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageCopy extends StatelessWidget {
  const _StageCopy({
    super.key,
    required this.message,
  });

  final QuizAiStageMessage message;

  @override
  Widget build(BuildContext context) {
    final support = message.support?.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.lead,
          textAlign: TextAlign.center,
          style: QuizTypography.screenTitle.copyWith(
            color: QuizPalette.foreground,
            fontSize: 26,
            height: 1.12,
            fontWeight: FontWeight.w800,
            shadows: _textShadows,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          message.highlight,
          textAlign: TextAlign.center,
          style: QuizTypography.screenTitle.copyWith(
            color: const Color(0xFFD6A7FF),
            fontSize: 35,
            height: 1.02,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            shadows: _textShadows,
          ),
        ),
        if (support != null && support.isNotEmpty) ...[
          const SizedBox(height: 13),
          Text(
            support,
            textAlign: TextAlign.center,
            style: QuizTypography.body.copyWith(
              color: QuizPalette.foreground.withAlpha(225),
              fontSize: 19,
              height: 1.28,
              fontWeight: FontWeight.w700,
              shadows: _textShadows,
            ),
          ),
        ],
      ],
    );
  }

  static const _textShadows = [
    Shadow(
      color: Color(0x66000000),
      blurRadius: 14,
      offset: Offset(0, 3),
    ),
  ];
}

class _StageProgress extends StatelessWidget {
  const _StageProgress({
    required this.progress,
  });

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          end: progress.clamp(0.0, 1.0).toDouble(),
        ),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return CustomPaint(
            painter: _StageProgressPainter(value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _StageProgressPainter extends CustomPainter {
  const _StageProgressPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final centerY = size.height / 2;
    const trackHeight = 27.0;
    const fillHeight = 23.0;
    const outerInset = 2.0;
    const fillInset = 5.0;

    final trackRect = Rect.fromLTWH(
      outerInset,
      centerY - (trackHeight / 2),
      size.width - (outerInset * 2),
      trackHeight,
    );
    final track = RRect.fromRectAndRadius(
      trackRect,
      const Radius.circular(999),
    );

    // Halo exterior continuo, sin elementos móviles superpuestos.
    final haloPaint = Paint()
      ..color = const Color(0xFFB66CFF).withAlpha(145)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 12);
    canvas.drawRRect(track, haloPaint);

    final softHaloPaint = Paint()
      ..color = const Color(0xFFE5B5FF).withAlpha(70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 22);
    canvas.drawRRect(track, softHaloPaint);

    // Track oscuro pero luminoso.
    final trackPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF3A147E),
          Color(0xFF26085E),
          Color(0xFF321070),
        ],
      ).createShader(trackRect);
    canvas.drawRRect(track, trackPaint);

    final trackBorderPaint = Paint()
      ..color = const Color(0xFFD8B5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawRRect(track, trackBorderPaint);

    final available = size.width - (fillInset * 2);
    if (available <= 0) return;

    final fillWidth = (available * progress)
        .clamp(12.0, available)
        .toDouble();
    final fillRect = Rect.fromLTWH(
      fillInset,
      centerY - (fillHeight / 2),
      fillWidth,
      fillHeight,
    );
    final fill = RRect.fromRectAndRadius(
      fillRect,
      const Radius.circular(999),
    );

    // Glow del propio relleno: mantiene la forma de cápsula.
    final fillGlowPaint = Paint()
      ..color = const Color(0xFFCB73FF).withAlpha(205)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 11);
    canvas.drawRRect(fill, fillGlowPaint);

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF9750FF),
          Color(0xFFD987FF),
          Color(0xFFF2B7FF),
          Color(0xFFFFE9FF),
        ],
        stops: [0.0, 0.56, 0.84, 1.0],
      ).createShader(fillRect);
    canvas.drawRRect(fill, fillPaint);

    // La punta gana luz gradualmente, sin una bola ni una costura visible.
    final tipWidth = fillWidth < 40 ? fillWidth : 40.0;
    final tipRect = Rect.fromLTWH(
      fillRect.right - tipWidth,
      fillRect.top,
      tipWidth,
      fillRect.height,
    );

    canvas.save();
    canvas.clipRRect(fill);
    final tipPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white.withAlpha(70),
          Colors.white.withAlpha(225),
        ],
        stops: const [0.0, 0.68, 1.0],
      ).createShader(tipRect);
    canvas.drawRect(tipRect, tipPaint);
    canvas.restore();

  }

  @override
  bool shouldRepaint(covariant _StageProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
