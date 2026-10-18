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
                    23 * scale,
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
                                final compact = viewport.maxHeight < 510 * scale;
                                final minAnswerHeight =
                                    (compact ? 58 : 68) * scale;
                                final answerGap = (compact ? 9 : 12) * scale;
                                return SingleChildScrollView(
                                  key: ValueKey('quiz-question-$questionNumber'),
                                  physics: const ClampingScrollPhysics(),
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      20 * scale,
                                      (compact ? 16 : 24) * scale,
                                      20 * scale,
                                      (compact ? 19 : 24) * scale,
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
                                              fontSize: (compact ? 21 : 23) * scale,
                                              color: const Color(0xFF08062C),
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: (compact ? 12 : 20) * scale),
                                        for (var i = 0;
                                            i < question.options.length;
                                            i++)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              bottom: i ==
                                                      question.options.length - 1
                                                  ? 0
                                                  : answerGap,
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
                    height: 76 * scale,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      // La luz está en el borde, no en un relleno cian.
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: [0, 0.52, 1],
                        colors: [
                          Color(0xFF150750),
                          Color(0xFF0B0635),
                          Color(0xFF1D0750),
                        ],
                      ),
                      borderRadius: radius,
                    ),
                    child: loading
                        ? SizedBox(
                            width: 28 * scale,
                            height: 28 * scale,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Padding(
                            padding: EdgeInsets.all(1 * scale),
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


/// Contorno violeta-magenta inspirado en la referencia visual.
/// La penumbra, el halo próximo, el núcleo y los reflejos se dibujan
/// por separado. El cian pertenece al PNG del reloj, nunca al borde.
class _AidNeonOutline extends CustomPainter {
  const _AidNeonOutline({required this.active});

  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // El aro queda dentro del botón; únicamente la luz difusa se extiende.
    final rect = (Offset.zero & size).deflate(3.5);
    final radius = rect.height / 2;
    final capsule = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final rimShader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: const [0, 0.27, 0.72, 1],
      colors: active
          ? const [
              Color(0xFFF38AFF),
              Color(0xFFC43AFF),
              Color(0xFFAB2AFF),
              Color(0xFFF177FF),
            ]
          : const [
              Color(0xFFE575FF),
              Color(0xFFAC2CF5),
              Color(0xFF9920EF),
              Color(0xFFE966F6),
            ],
    ).createShader(rect);

    // Luz interior violeta muy tenue; no blanquea el icono.
    final inner = capsule.deflate(2.0);
    canvas.save();
    canvas.clipRRect(inner);
    canvas.drawRRect(
      inner,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.9, -0.9),
          radius: 0.83,
          colors: [Color(0x447F36D6), Color(0x006F20CE)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(1.0, 1.0),
          radius: 0.86,
          colors: [Color(0x40551CBA), Color(0x00551CBA)],
        ).createShader(rect),
    );
    canvas.restore();

    // Penumbra amplia fundida con el fondo cósmico.
    canvas.drawRRect(
      capsule,
      Paint()
        ..isAntiAlias = true
        ..color = const Color(0xA58A18EE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.2),
    );

    // Halo inmediato y saturado.
    canvas.drawRRect(
      capsule,
      Paint()
        ..isAntiAlias = true
        ..shader = rimShader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.3),
    );

    // Núcleo luminoso más ancho y definido que el anterior.
    canvas.drawRRect(
      capsule,
      Paint()
        ..isAntiAlias = true
        ..shader = rimShader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );
    canvas.drawRRect(
      capsule.deflate(2.05),
      Paint()
        ..isAntiAlias = true
        ..color = const Color(0x446E20E3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Destellos cortos rosados, no arcos cian ni líneas blancas.
    final upperLeft = Path()
      ..moveTo(rect.left, rect.top + radius)
      ..arcToPoint(
        Offset(rect.left + radius, rect.top),
        radius: Radius.circular(radius),
        clockwise: true,
      )
      ..lineTo(rect.left + radius + 9, rect.top);
    _paintHighlight(canvas, upperLeft, const Color(0xFFF192FF));

    final lowerRight = Path()
      ..moveTo(rect.right - radius - 9, rect.bottom)
      ..lineTo(rect.right - radius, rect.bottom)
      ..arcToPoint(
        Offset(rect.right, rect.bottom - radius),
        radius: Radius.circular(radius),
        clockwise: false,
      );
    _paintHighlight(canvas, lowerRight, const Color(0xFFF17AFF));
  }

  void _paintHighlight(Canvas canvas, Path path, Color color) {
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..color = color.withAlpha(160)
        ..strokeWidth = 3.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..color = color.withAlpha(155)
        ..strokeWidth = 1.05
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
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
