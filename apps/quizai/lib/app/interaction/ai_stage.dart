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
      height: 36,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const inset = 5.0;
          const fillHeight = 18.0;
          final available = (constraints.maxWidth - (inset * 2))
              .clamp(0.0, double.infinity)
              .toDouble();
          final normalized = progress.clamp(0.0, 1.0).toDouble();
          final fillWidth = available <= 14
              ? available
              : (available * normalized)
                    .clamp(14.0, available)
                    .toDouble();
          final tipLeft = inset + fillWidth - 11;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              // 1. Halo exterior: una nube de luz independiente del track.
              Positioned(
                left: 6,
                right: 6,
                top: 5,
                bottom: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA457FF).withAlpha(150),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: const Color(0xFFF0B6FF).withAlpha(85),
                        blurRadius: 38,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Track luminoso: cápsula visible incluso en la parte vacía.
              Positioned(
                left: 1,
                right: 1,
                top: 7,
                bottom: 7,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF351172),
                        Color(0xFF2A0B66),
                        Color(0xFF321071),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFFD5B1FF),
                      width: 2.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB36CFF).withAlpha(185),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.white.withAlpha(55),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Fill luminoso: masa de luz con borde propio.
              Positioned(
                left: inset,
                top: (36 - fillHeight) / 2,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  width: fillWidth,
                  height: fillHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF9D55FF),
                        Color(0xFFD985FF),
                        Color(0xFFF3B7FF),
                        Color(0xFFFFF2FF),
                      ],
                      stops: [0.0, 0.52, 0.82, 1.0],
                    ),
                    border: Border.all(
                      color: const Color(0xFFFFE7FF),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFCB73FF).withAlpha(245),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: const Color(0xFFF4C8FF).withAlpha(180),
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.white.withAlpha(170),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Bloom en la punta: destello independiente que sigue al fill.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                left: tipLeft,
                top: 7,
                child: IgnorePointer(
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white,
                          const Color(0xFFFFD8FF).withAlpha(225),
                          const Color(0xFFD57BFF).withAlpha(125),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.28, 0.58, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withAlpha(210),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: const Color(0xFFE29BFF).withAlpha(220),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
