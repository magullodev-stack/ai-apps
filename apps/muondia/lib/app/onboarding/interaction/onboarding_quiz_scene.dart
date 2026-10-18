import 'package:ai_apps_ui/ai_apps_ui.dart';
import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../production/onboarding_quiz_pipeline.dart';
import 'onboarding_quiz_header.dart';

/// Toda la superficie interactiva se compone con widgets Flutter.
/// El único PNG decorativo del test es el fondo cósmico.
class OnboardingQuizScene extends StatelessWidget {
  const OnboardingQuizScene({
    super.key,
    required this.question,
    required this.questionNumber,
    required this.questionCount,
    required this.secondsRemaining,
    required this.timeFraction,
    required this.progress,
    required this.hearts,
    required this.pauseRemaining,
    required this.pauseActive,
    required this.onUsePause,
    required this.fiftyRemaining,
    required this.hintRemaining,
    required this.hintLoading,
    required this.hiddenOptions,
    required this.onUseFifty,
    required this.onUseHint,
    required this.selected,
    required this.onAnswer,
    required this.feedbackColor,
  });

  final OnboardingQuizFinalQuestion question;
  final int questionNumber;
  final int questionCount;
  final int secondsRemaining;
  final double timeFraction;
  final List<QuizOutcome> progress;
  final int hearts;
  final int pauseRemaining;
  final bool pauseActive;
  final VoidCallback? onUsePause;
  final int fiftyRemaining;
  final int hintRemaining;
  final bool hintLoading;
  final Set<int> hiddenOptions;
  final VoidCallback? onUseFifty;
  final VoidCallback? onUseHint;
  final int? selected;
  final ValueChanged<int> onAnswer;
  final Color Function(int) feedbackColor;

  @override
  Widget build(BuildContext context) {
    final scale = (MediaQuery.sizeOf(context).width / 390.0)
        .clamp(0.82, 1.1)
        .toDouble();
    final spacing = 12 * scale;
    final panelRadius = BorderRadius.circular(28 * scale);

    return Scaffold(
      backgroundColor: const Color(0xFF181442),
      body: Stack(
        key: const Key('muondia-quiz-stage'),
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/onboarding/test/quiz_background.png',
            key: const Key('muondia-quiz-background-image'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.high,
            excludeFromSemantics: true,
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    spacing,
                    17 * scale,
                    spacing,
                    spacing,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OnboardingQuizHeader(
                        pivot: question.pivot,
                        questionNumber: questionNumber,
                        questionCount: questionCount,
                        secondsRemaining: secondsRemaining,
                        timeFraction: timeFraction,
                        progress: progress,
                        hearts: hearts,
                      ),
                      SizedBox(
                        key: const Key('muondia-header-card-gap'),
                        height: spacing,
                      ),
                      Expanded(
                        child: Container(
                          key: const Key('muondia-question-card'),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFBFF),
                            borderRadius: panelRadius,
                            border: Border.all(
                              color: const Color(0xFFEDE9FF), width: 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xCC8428FD),
                                blurRadius: 24,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: Color(0x553A2AD0),
                                blurRadius: 16,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            key: const Key('muondia-question-clip'),
                            borderRadius: panelRadius,
                            clipBehavior: Clip.antiAlias,
                            child: LayoutBuilder(
                              builder: (context, viewport) {
                                // No ampliar cada respuesta según la altura total del panel:
                                // la última quedaba cortada. Preguntas largas
                                // siguen teniendo scroll interior.
                                final minAnswerHeight = 68 * scale;
                                return SingleChildScrollView(
                                  key: ValueKey('quiz-question-$questionNumber'),
                                  physics: const ClampingScrollPhysics(),
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      20 * scale,
                                      24 * scale,
                                      20 * scale,
                                      24 * scale,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 2 * scale,
                                          ),
                                          child: AiAppsContentText(
                                            question.question,
                                            style: MuondiaTypography.screenTitle
                                                .copyWith(
                                              fontSize: 23 * scale,
                                              color: const Color(0xFF08062C),
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 20 * scale),
                                        for (var i = 0;
                                            i < question.options.length;
                                            i++)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              bottom: i ==
                                                      question.options.length - 1
                                                  ? 0
                                                  : 12 * scale,
                                            ),
                                            child: _AnswerCard(
                                              key: ValueKey(
                                                'muondia-quiz-answer-$questionNumber-$i',
                                              ),
                                              index: i,
                                              text: question.options[i],
                                              scale: scale,
                                              minHeight: minAnswerHeight,
                                              color: feedbackColor(i),
                                              selected: selected == i,
                                              disabled:
                                                  hiddenOptions.contains(i),
                                              onTap: selected == null &&
                                                      !hintLoading &&
                                                      !hiddenOptions.contains(i)
                                                  ? () => onAnswer(i)
                                                  : null,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        key: const Key('muondia-card-aids-gap'),
                        height: spacing,
                      ),
                      Row(
                        key: const Key('muondia-lifelines-row'),
                        children: [
                          Expanded(
                            child: _AidButton(
                              key: const Key('muondia-aid-fifty'),
                              label: '50/50',
                              asset: 'assets/onboarding/test/50%.png',
                              remaining: fiftyRemaining,
                              scale: scale,
                              onTap: onUseFifty,
                            ),
                          ),
                          SizedBox(width: 9 * scale),
                          Expanded(
                            child: _AidButton(
                              key: const Key('muondia-aid-hint'),
                              label: 'Pista IA',
                              asset: 'assets/onboarding/test/Pista.png',
                              remaining: hintRemaining,
                              scale: scale,
                              loading: hintLoading,
                              onTap: onUseHint,
                            ),
                          ),
                          SizedBox(width: 9 * scale),
                          Expanded(
                            child: _AidButton(
                              key: const Key('muondia-aid-pause'),
                              label: 'Pausa 10 segundos',
                              asset: 'assets/onboarding/test/Pausa.png',
                              remaining: pauseRemaining,
                              scale: scale,
                              active: pauseActive,
                              onTap: onUsePause,
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _AidButton extends StatelessWidget {
  const _AidButton({
    super.key,
    required this.label,
    required this.asset,
    required this.remaining,
    required this.scale,
    required this.onTap,
    this.loading = false,
    this.active = false,
  });

  final String label;
  final String asset;
  final int remaining;
  final double scale;
  final bool loading;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final available = remaining > 0;
    final isFifty = label == '50/50';
    final isHint = label == 'Pista IA';
    final kind = isFifty ? 'fifty' : isHint ? 'hint' : 'pause';
    final radius = BorderRadius.circular(42 * scale);

    return Semantics(
      label: label,
      button: true,
      enabled: onTap != null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedOpacity(
            key: Key('muondia-$kind-opacity'),
            opacity: available || active ? 1 : 0.42,
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: CustomPaint(
                  foregroundPainter: _AidNeonOutline(active: active),
                  child: Container(
                    height: 70 * scale,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xD80B0442),
                    borderRadius: radius,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x664D05D8),
                        blurRadius: 9,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                  child: loading
                      ? SizedBox(
                          width: 28 * scale,
                          height: 28 * scale,
                          child: const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3),
                        )
                      : Padding(
                          padding: EdgeInsets.all(7 * scale),
                          child: Image.asset(
                            asset,
                            key: Key('muondia-$kind-image'),
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            excludeFromSemantics: true,
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
          if (available)
            Positioned(
              right: 1 * scale,
              top: -9 * scale,
              child: Container(
                key: Key('muondia-$kind-count'),
                width: 29 * scale,
                height: 29 * scale,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFF94), Color(0xFFFFC51A)],
                  ),
                  border: Border.all(color: const Color(0xFFFFF7B7), width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66F8AB1C), blurRadius: 6),
                  ],
                ),
                child: Text(
                  '$remaining',
                  style: MuondiaTypography.screenTitle.copyWith(
                    color: const Color(0xFF140C36),
                    fontSize: 20 * scale,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


class _AidNeonOutline extends CustomPainter {
  const _AidNeonOutline({required this.active});
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = (Offset.zero & size).deflate(1.2);
    final radius = rect.height / 2;
    final outline = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    canvas.drawRRect(
      outline,
      Paint()
        ..color = const Color(0x556F2CDD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawRRect(
      outline,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: active
              ? const [Color(0xFF60FFF3), Color(0xFFA84AF8), Color(0xFF50DDFF)]
              : const [Color(0xFF6ECAFF), Color(0xFF963EF1), Color(0xFFF063FF)],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.35,
    );
    final topLeft = Path()
      ..moveTo(rect.left + radius + 20, rect.top)
      ..lineTo(rect.left + radius, rect.top)
      ..quadraticBezierTo(rect.left, rect.top, rect.left, rect.top + radius);
    canvas.drawPath(
      topLeft,
      Paint()
        ..color = const Color(0xD7A0F5FF)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.8,
    );
    final bottomRight = Path()
      ..moveTo(rect.right - radius - 16, rect.bottom)
      ..lineTo(rect.right - radius, rect.bottom)
      ..quadraticBezierTo(rect.right, rect.bottom, rect.right, rect.bottom - radius);
    canvas.drawPath(
      bottomRight,
      Paint()
        ..color = const Color(0xBFFF89FB)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.7,
    );
  }

  @override
  bool shouldRepaint(covariant _AidNeonOutline oldDelegate) =>
      oldDelegate.active != active;
}

/// Superficie, letra, texto y área táctil comparten la misma geometría.
class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    super.key,
    required this.index,
    required this.text,
    required this.scale,
    required this.minHeight,
    required this.color,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final int index;
  final String text;
  final double scale;
  final double minHeight;
  final Color color;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final letter = String.fromCharCode(65 + index);
    final radius = BorderRadius.circular(24 * scale);

    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      child: AnimatedOpacity(
        key: Key('muondia-answer-opacity-$index'),
        duration: const Duration(milliseconds: 220),
        opacity: disabled ? 0.40 : 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: const [
              BoxShadow(
                color: Color(0x283B43BC),
                blurRadius: 13,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: Key('muondia-answer-$index'),
              onTap: onTap,
              child: AnimatedContainer(
                key: Key('muondia-answer-feedback-$index'),
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(color: color),
                constraints: BoxConstraints(minHeight: minHeight),
                padding: EdgeInsets.symmetric(
                  horizontal: 12 * scale,
                  vertical: 10 * scale,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        key: Key('muondia-answer-letter-$index'),
                        width: 42 * scale,
                        height: 44 * scale,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12 * scale),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFF2F3FF),
                              Color(0xFFE3E6FA),
                            ],
                          ),
                        ),
                        child: Text(
                          letter,
                          style: MuondiaTypography.screenTitle.copyWith(
                            color: const Color(0xFF0A0A31),
                            fontSize: 25 * scale,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10 * scale),
                    Container(
                      key: Key('muondia-answer-divider-$index'),
                      width: 1.5 * scale,
                      height: 32 * scale,
                      color: const Color(0xFFC9C8EA),
                    ),
                    SizedBox(width: 12 * scale),
                    Expanded(
                      child: AiAppsContentText(
                        text,
                        style: MuondiaTypography.sectionTitle.copyWith(
                          fontSize: 20 * scale,
                          color: const Color(0xFF08062C),
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
