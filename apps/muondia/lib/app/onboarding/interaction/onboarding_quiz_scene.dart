import 'package:ai_apps_ui/ai_apps_ui.dart';
import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../production/onboarding_quiz_pipeline.dart';
import 'onboarding_quiz_header.dart';

/// La estructura del test es Flutter. Solo el universo y los símbolos
/// independientes son imágenes; nunca las tarjetas ni los contadores.
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
    final scale =
        (MediaQuery.sizeOf(context).width / 390).clamp(0.82, 1.1).toDouble();
    final spacing = 13 * scale;
    final panelRadius = BorderRadius.circular(22 * scale);

    return Scaffold(
      backgroundColor: const Color(0xFF040E29),
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
            child: LayoutBuilder(
              builder: (context, screen) {
                final compact = screen.maxHeight < 740;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        14 * scale,
                        (compact ? 12 : 28) * scale,
                        14 * scale,
                        (compact ? 9 : 77) * scale,
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
                            height: compact ? 8 * scale : spacing,
                          ),
                          Expanded(
                            child: Container(
                              key: const Key('muondia-question-card'),
                              decoration: BoxDecoration(
                                borderRadius: panelRadius,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xF211264B),
                                    Color(0xF5071634),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFF34588C),
                                  width: 0.9,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x32010C2E),
                                    blurRadius: 16,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                key: const Key('muondia-question-clip'),
                                borderRadius: panelRadius,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        16 * scale, 18 * scale,
                                        16 * scale, 17 * scale,
                                      ),
                                      child: Semantics(
                                        label: 'Progreso de preguntas',
                                        value: 'Pregunta $questionNumber de $questionCount',
                                        child: Row(
                                          key: const Key('muondia-progress-orbs'),
                                          children: [
                                            for (var i = 0; i < progress.length; i++)
                                              Expanded(
                                                child: Center(
                                                  child: SizedBox(
                                                    height: 17 * scale,
                                                    width: 17 * scale,
                                                    child: DecoratedBox(
                                                      key: Key('muondia-progress-orb-$i'),
                                                      decoration: quizOrbDecoration(progress[i]),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                      key: const Key('muondia-progress-divider'),
                                      margin: EdgeInsets.symmetric(horizontal: 17 * scale),
                                      height: 1 * scale,
                                      color: const Color(0xFF23395C),
                                    ),
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, viewport) {
                                          final short = viewport.maxHeight < 370 * scale;
                                          final minAnswerHeight = (short ? 52 : 58) * scale;
                                          final answerGap = (short ? 9 : 11) * scale;
                                          return SingleChildScrollView(
                                            key: ValueKey('quiz-question-$questionNumber'),
                                            physics: const ClampingScrollPhysics(),
                                            child: Padding(
                                              padding: EdgeInsets.fromLTRB(
                                                16 * scale,
                                                (short ? 15 : 20) * scale,
                                                16 * scale,
                                                17 * scale,
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  AiAppsContentText(
                                                    question.question,
                                                    style: MuondiaTypography.screenTitle.copyWith(
                                                      fontSize: (short ? 21 : 23) * scale,
                                                      fontWeight: FontWeight.w800,
                                                      height: 1.23,
                                                      color: const Color(0xFFF8FAFF),
                                                    ),
                                                  ),
                                                  SizedBox(height: (short ? 18 : 22) * scale),
                                                  for (var i = 0; i < question.options.length; i++)
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                        bottom: i == question.options.length - 1
                                                            ? 0 : answerGap,
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
                                                        disabled: hiddenOptions.contains(i),
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
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            key: const Key('muondia-card-aids-gap'),
                            height: compact ? 10 * scale : 16 * scale,
                          ),
                          SizedBox(
                            height: (compact ? 68 : 78) * scale,
                            child: Row(
                              key: const Key('muondia-lifelines-row'),
                              children: [
                                Expanded(
                                  child: _AidButton(
                                    key: const Key('muondia-aid-fifty'),
                                    label: '50/50',
                                    kind: 'fifty',
                                    imageAsset: 'assets/onboarding/test/modern_50_50.png',
                                    remaining: fiftyRemaining,
                                    scale: scale,
                                    onTap: onUseFifty,
                                  ),
                                ),
                                SizedBox(width: 10 * scale),
                                Expanded(
                                  child: _AidButton(
                                    key: const Key('muondia-aid-hint'),
                                    label: 'Pista IA',
                                    kind: 'hint',
                                    imageAsset: 'assets/onboarding/test/modern_bulb.png',
                                    remaining: hintRemaining,
                                    scale: scale,
                                    loading: hintLoading,
                                    onTap: onUseHint,
                                  ),
                                ),
                                SizedBox(width: 10 * scale),
                                Expanded(
                                  child: _AidButton(
                                    key: const Key('muondia-aid-pause'),
                                    label: 'Pausa 10 segundos',
                                    kind: 'pause',
                                    remaining: pauseRemaining,
                                    scale: scale,
                                    active: pauseActive,
                                    onTap: onUsePause,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Mismo rectángulo redondeado y mismo contador para los tres botones.
class _AidButton extends StatelessWidget {
  const _AidButton({
    super.key,
    required this.label,
    required this.kind,
    required this.remaining,
    required this.scale,
    required this.onTap,
    this.imageAsset,
    this.loading = false,
    this.active = false,
  });

  final String label;
  final String kind;
  final String? imageAsset;
  final int remaining;
  final double scale;
  final bool loading;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final available = remaining > 0;
    final radius = BorderRadius.circular(19 * scale);
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
              borderRadius: radius,
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: Container(
                  key: Key('muondia-$kind-frame'),
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF203E64),
                        Color(0xFF10284A),
                        Color(0xFF091A36),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF34578D),
                      width: 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22089EFF),
                        blurRadius: 7,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 7 * scale,
                      vertical: 7 * scale,
                    ),
                    child: Center(
                      child: ClipRect(
                        key: Key('muondia-$kind-icon-viewport'),
                      child: loading
                          ? SizedBox(
                              width: 27 * scale,
                              height: 27 * scale,
                              child: const CircularProgressIndicator(
                                color: Color(0xFFFFD557),
                                strokeWidth: 2.5,
                              ),
                            )
                          : kind == 'pause'
                              ? SizedBox.square(
                                  dimension: 52 * scale,
                                  child: CustomPaint(
                                    key: const Key('muondia-pause-symbol'),
                                    painter: const _PauseIconPainter(),
                                  ),
                                )
                              : SizedBox.square(
                                  dimension: (kind == 'fifty' ? 95 : 76) * scale,
                                  child: Image.asset(
                                    imageAsset!,
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
            ),
          ),
          if (available)
            Positioned(
              top: -4 * scale,
              right: -1 * scale,
              child: Container(
                key: Key('muondia-$kind-count'),
                width: 27 * scale,
                height: 27 * scale,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3058),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1E3E70), width: 0.75),
                ),
                child: Text(
                  '$remaining',
                  style: MuondiaTypography.sectionTitle.copyWith(
                    color: const Color(0xFFFAFBFF),
                    fontSize: 17 * scale,
                    fontWeight: FontWeight.w800,
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

/// El cronómetro de pausa es una línea azul-cian sin caja ni esfera PNG.
class _PauseIconPainter extends CustomPainter {
  const _PauseIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 60;
    final sy = size.height / 60;
    canvas.save();
    canvas.scale(sx, sy);
    final stroke = Paint()
      ..color = const Color(0xFF57E9FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.3
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..color = const Color(0x8861D9FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.4);
    for (final brush in [glow, stroke]) {
      canvas.drawCircle(const Offset(30, 34), 21, brush);
      canvas.drawLine(const Offset(30, 13), const Offset(30, 7), brush);
      canvas.drawLine(const Offset(24, 6), const Offset(36, 6), brush);
      canvas.drawLine(const Offset(12, 19), const Offset(9, 16), brush);
      canvas.drawLine(const Offset(48, 19), const Offset(51, 16), brush);
      canvas.drawLine(const Offset(24, 26), const Offset(24, 41), brush);
      canvas.drawLine(const Offset(36, 26), const Offset(36, 41), brush);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PauseIconPainter oldDelegate) => false;
}

/// Respuesta oscura: letra, separador, texto y superficie táctil única.
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
    final radius = BorderRadius.circular(15 * scale);
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
            border: Border.all(
              color: const Color(0xFF274D86),
              width: 1 * scale,
            ),
            gradient: const LinearGradient(
              colors: [Color(0xFF102648), Color(0xFF142C50)],
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: Key('muondia-answer-$index'),
              onTap: onTap,
              child: AnimatedContainer(
                key: Key('muondia-answer-feedback-$index'),
                duration: const Duration(milliseconds: 140),
                constraints: BoxConstraints(minHeight: minHeight),
                decoration: BoxDecoration(color: color),
                padding: EdgeInsets.symmetric(
                  horizontal: 12 * scale,
                  vertical: 9 * scale,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        key: Key('muondia-answer-letter-$index'),
                        width: 39 * scale,
                        height: 39 * scale,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7 * scale),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF234674),
                              Color(0xFF193458),
                            ],
                          ),
                        ),
                        child: Text(
                          letter,
                          style: MuondiaTypography.screenTitle.copyWith(
                            color: const Color(0xFFB4D1FF),
                            fontSize: 23 * scale,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12 * scale),
                    Container(
                      key: Key('muondia-answer-divider-$index'),
                      width: 1 * scale,
                      height: 29 * scale,
                      color: const Color(0xFF28446D),
                    ),
                    SizedBox(width: 12 * scale),
                    Expanded(
                      child: AiAppsContentText(
                        text,
                        style: MuondiaTypography.sectionTitle.copyWith(
                          fontSize: 20 * scale,
                          color: const Color(0xFFF8FAFF),
                          fontWeight: FontWeight.w700,
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
