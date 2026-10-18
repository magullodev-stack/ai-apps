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
    final spacing = 16 * scale;
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
                    8 * scale,
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
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x443A2AD0),
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
                                // Crece el alto útil de las respuestas, nunca
                                // se estiran las curvas ni el texto.
                                final minAnswerHeight =
                                    (viewport.maxHeight / 6.2)
                                        .clamp(64 * scale, 94 * scale)
                                        .toDouble();
                                return SingleChildScrollView(
                                  key: ValueKey('quiz-question-$questionNumber'),
                                  physics: const ClampingScrollPhysics(),
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      20 * scale,
                                      26 * scale,
                                      20 * scale,
                                      20 * scale,
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
                                        SizedBox(height: 30 * scale),
                                        for (var i = 0;
                                            i < question.options.length;
                                            i++)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              bottom: i ==
                                                      question.options.length - 1
                                                  ? 0
                                                  : 10 * scale,
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
                              label: '50%',
                              icon: Icons.visibility_off_outlined,
                              remaining: fiftyRemaining,
                              scale: scale,
                              onTap: onUseFifty,
                            ),
                          ),
                          SizedBox(width: 16 * scale),
                          Expanded(
                            child: _AidButton(
                              key: const Key('muondia-aid-hint'),
                              label: 'Pista IA',
                              icon: Icons.lightbulb,
                              remaining: hintRemaining,
                              scale: scale,
                              loading: hintLoading,
                              onTap: onUseHint,
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
    required this.icon,
    required this.remaining,
    required this.scale,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final int remaining;
  final double scale;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final available = remaining > 0;
    final enabled = onTap != null;
    final isFifty = label == '50%';
    final radius = BorderRadius.circular(36 * scale);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedOpacity(
          key: Key(isFifty ? 'muondia-fifty-opacity' : 'muondia-hint-opacity'),
          opacity: available ? 1 : 0.40,
          duration: const Duration(milliseconds: 220),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: radius,
              child: Container(
                height: 62 * scale,
                padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                decoration: BoxDecoration(
                  color: const Color(0xB31D154E),
                  borderRadius: radius,
                  border: Border.all(
                    color: const Color(0xFF7937F1),
                    width: 2 * scale,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (loading)
                      SizedBox(
                        width: 22 * scale,
                        height: 22 * scale,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        icon,
                        color: isFifty
                            ? Colors.white
                            : const Color(0xFFFFC63D),
                        size: 24 * scale,
                      ),
                    SizedBox(width: 8 * scale),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: MuondiaTypography.sectionTitle.copyWith(
                            color: Colors.white,
                            fontSize: 20 * scale,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (available)
          Positioned(
            right: 0,
            top: -8 * scale,
            child: Container(
              key: Key(isFifty ? 'muondia-fifty-count' : 'muondia-hint-count'),
              width: 30 * scale,
              height: 30 * scale,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFE58E), Color(0xFFFFB81D)],
                ),
                border: Border.all(
                  color: const Color(0xFFFFF0B0),
                  width: 1.2,
                ),
              ),
              child: Text(
                '$remaining',
                style: MuondiaTypography.screenTitle.copyWith(
                  color: const Color(0xFF201047),
                  fontSize: 20 * scale,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
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
