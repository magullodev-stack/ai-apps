import 'package:ai_apps_ui/ai_apps_ui.dart';
import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../production/onboarding_quiz_pipeline.dart';
import 'onboarding_quiz_header.dart';

/// Composición propia de Muondia; la página conserva las reglas del test.
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
    final gutter = 16 * scale;

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
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  gutter, 8 * scale, gutter, gutter,
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
                      height: gutter,
                    ),
                    Expanded(
                      child: Stack(
                        key: const Key('muondia-question-card'),
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/onboarding/test/Caja Test.png',
                            key: const Key('muondia-question-panel-image'),
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.high,
                            excludeFromSemantics: true,
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              18 * scale, 40 * scale,
                              18 * scale, 35 * scale,
                            ),
                            child: LayoutBuilder(
                              builder: (context, viewport) =>
                                  SingleChildScrollView(
                                key: ValueKey('quiz-question-$questionNumber'),
                                physics: const ClampingScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: viewport.maxHeight,
                                  ),
                                  child: IntrinsicHeight(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            4 * scale, 4 * scale,
                                            4 * scale, 14 * scale,
                                          ),
                                          child: AiAppsContentText(
                                            question.question,
                                            style: MuondiaTypography
                                                .screenTitle.copyWith(
                                              fontSize: 23 * scale,
                                              color: const Color(0xFF08062C),
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        for (var i = 0;
                                            i < question.options.length; i++)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              top: 6 * scale,
                                            ),
                                            child: _AnswerCard(
                                              key: ValueKey(
                                                'muondia-quiz-answer-$questionNumber-$i',
                                              ),
                                              index: i,
                                              text: question.options[i],
                                              scale: scale,
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
                                        SizedBox(height: 4 * scale),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      key: const Key('muondia-card-aids-gap'),
                      height: gutter,
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedOpacity(
          key: Key(isFifty ? 'muondia-fifty-opacity' : 'muondia-hint-opacity'),
          opacity: available ? 1.0 : 0.40,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: enabled ? onTap : null,
              child: SizedBox(
                height: 64 * scale,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/onboarding/test/Caja comodines.png',
                      key: Key(isFifty
                          ? 'muondia-fifty-image' : 'muondia-hint-image'),
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                      excludeFromSemantics: true,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (loading)
                            SizedBox(
                              width: 22 * scale,
                              height: 22 * scale,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          else
                            Icon(
                              icon,
                              color: isFifty
                                  ? Colors.white
                                  : const Color(0xFFFFC63D),
                              size: 25 * scale,
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
            child: SizedBox(
              key: Key(isFifty ? 'muondia-fifty-count' : 'muondia-hint-count'),
              width: 30 * scale,
              height: 30 * scale,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/onboarding/test/Esfera.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    excludeFromSemantics: true,
                  ),
                  Center(
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
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// El 50 % no retira ninguna fila: solo atenúa dos alternativas y su toque.
class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    super.key,
    required this.index,
    required this.text,
    required this.scale,
    required this.color,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final int index;
  final String text;
  final double scale;
  final Color color;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final letter = String.fromCharCode(65 + index);
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      child: AnimatedOpacity(
        key: Key('muondia-answer-opacity-$index'),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        opacity: disabled ? 0.40 : 1.0,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: Key('muondia-answer-$index'),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: 76 * scale),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/onboarding/test/Caja Respuesta.png',
                      key: Key('muondia-answer-image-$index'),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      excludeFromSemantics: true,
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedContainer(
                      key: Key('muondia-answer-feedback-$index'),
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(24 * scale),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 22 * scale,
                      vertical: 18 * scale,
                    ),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: SizedBox(
                            key: Key('muondia-answer-letter-$index'),
                            width: 42 * scale,
                            child: Center(
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
                        ),
                        SizedBox(width: 19 * scale),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
