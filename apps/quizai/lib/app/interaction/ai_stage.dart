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
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
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
      height: 20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth > 6
              ? constraints.maxWidth - 6
              : 0.0;
          final fillWidth = (available * progress.clamp(0.0, 1.0))
              .clamp(8.0, available > 8 ? available : 8.0);

          return DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0x33100045),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFF9D75FF).withAlpha(170),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8F5CFF).withAlpha(70),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  width: fillWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF855CFF),
                        Color(0xFFD18CFF),
                        Color(0xFFF5D6FF),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD89BFF).withAlpha(205),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.white.withAlpha(90),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
