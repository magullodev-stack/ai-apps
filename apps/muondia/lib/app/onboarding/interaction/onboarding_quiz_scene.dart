import 'package:ai_apps_ui/ai_apps_ui.dart';
import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../production/onboarding_quiz_pipeline.dart';
import 'onboarding_quiz_backdrop.dart';
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
    final scale = MediaQuery.sizeOf(context).width.clamp(320.0, 480.0) / 390;
    return Scaffold(
      backgroundColor: const Color(0xFF181442),
      body: DecoratedBox(
        key: const Key('muondia-quiz-stage'),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF160D53), Color(0xFF2E10A3), Color(0xFF150E45)],
            stops: [0.0, .51, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: const OnboardingQuizBackdrop(),
          child: SafeArea(
            child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  key: ValueKey('quiz-question-$questionNumber'),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
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
                            Expanded(
                              child: Container(
                                key: const Key('muondia-question-card'),
                                padding: EdgeInsets.all(14 * scale),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAFBFF),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: Colors.white),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x554A1FFF),
                                      blurRadius: 22,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        8 * scale, 12 * scale, 8 * scale, 18 * scale,
                                      ),
                                      child: AiAppsContentText(
                                        question.question,
                                        style: MuondiaTypography.screenTitle.copyWith(
                                          fontSize: 25 * scale,
                                          color: const Color(0xFF08062C),
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    for (
                                      var i = 0;
                                      i < question.options.length;
                                      i++
                                    )
                                      Padding(
                                        padding: EdgeInsets.only(top: 12 * scale),
                                        child: _AnswerCard(
                                          key: ValueKey('muondia-quiz-answer-$questionNumber-$i'),
                                          index: i,
                                          text: question.options[i],
                                          scale: scale,
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
                                    SizedBox(height: 10 * scale),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 18 * scale),
                            Row(
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
                            SizedBox(height: 6 * scale),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        ),
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
    final enabled = onTap != null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: enabled ? const Color(0xFF211751) : const Color(0xFF231C43),
          borderRadius: BorderRadius.circular(38 * scale),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 64 * scale,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 10 * scale),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(38 * scale),
                border: Border.all(
                  color: enabled ? const Color(0xFF7B3CFF) : const Color(0xFF4A3D79),
                  width: 2.5 * scale,
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
                      color: label == 'Pista IA'
                          ? const Color(0xFFFFC63D)
                          : Colors.white,
                      size: 27 * scale,
                    ),
                  SizedBox(width: 8 * scale),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: MuondiaTypography.sectionTitle.copyWith(
                          color: enabled ? Colors.white : const Color(0xFFB4ABC8),
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
        Positioned(
          right: 0,
          top: -8 * scale,
          child: Container(
            key: Key(label == '50%' ? 'muondia-fifty-count' : 'muondia-hint-count'),
            width: 30 * scale,
            height: 30 * scale,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: remaining > 0
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFE58E), Color(0xFFFFB81D)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF89759C), Color(0xFF6F5B89)],
                    ),
              border: Border.all(
                color: remaining > 0
                    ? const Color(0xFFFFF0B0)
                    : const Color(0xFFB9A5D2),
                width: 1.3,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x440B0635),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x253F4BD1),
              blurRadius: 14,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: AnimatedOpacity(
          key: Key('muondia-answer-opacity-$index'),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          opacity: disabled ? 0.40 : 1.0,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: Key('muondia-answer-$index'),
              onTap: onTap,
              child: AnimatedContainer(
                key: Key('muondia-answer-feedback-$index'),
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                decoration: BoxDecoration(color: color),
                constraints: BoxConstraints(minHeight: 64 * scale),
                padding: EdgeInsets.symmetric(
                  horizontal: 12 * scale,
                  vertical: 8 * scale,
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        key: Key('muondia-answer-letter-$index'),
                        width: 42 * scale,
                        height: 44 * scale,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12 * scale),
                          border: Border.all(color: const Color(0xFFE1E2F5)),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFF4F5FF),
                              Color(0xFFE4E6FA),
                            ],
                          ),
                        ),
                        child: Text(
                          letter,
                          style: MuondiaTypography.screenTitle.copyWith(
                            color: const Color(0xFF0A0A31),
                            fontSize: 27 * scale,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12 * scale),
                    Container(
                      key: Key('muondia-answer-divider-$index'),
                      width: 1.5 * scale,
                      height: 32 * scale,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC4C3EB),
                        borderRadius: BorderRadius.circular(1),
                      ),
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
