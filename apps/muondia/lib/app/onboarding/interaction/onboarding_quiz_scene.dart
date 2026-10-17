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
    required this.selected,
    required this.onAnswer,
    required this.feedbackColor,
  });
  final OnboardingQuizFinalQuestion question;
  final int questionNumber;
  final int questionCount;
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF39248E), width: 1.5),
          gradient: const RadialGradient(
            center: Alignment(0, -1.1),
            radius: 1.6,
            colors: [Color(0xFF5120CF), Color(0xFF201756), Color(0xFF15133D)],
            stops: [0, 0.48, 1],
          ),
        ),
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
                            ),
                            Expanded(
                              child: Container(
                                key: const Key('muondia-question-card'),
                                padding: EdgeInsets.all(14 * scale),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F8FF),
                                  borderRadius: BorderRadius.circular(24),
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
                                    Expanded(
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: 118 * scale,
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8 * scale,
                                              vertical: 18 * scale,
                                            ),
                                            child: AiAppsContentText(
                                              question.question,
                                              style: MuondiaTypography
                                                  .screenTitle
                                                  .copyWith(
                                                    fontSize: 25 * scale,
                                                    color: const Color(
                                                      0xFF08062C,
                                                    ),
                                                    height: 1.2,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    for (
                                      var i = 0;
                                      i < question.options.length;
                                      i++
                                    )
                                      Padding(
                                        padding: EdgeInsets.only(
                                          top: 12 * scale,
                                        ),
                                        child: _AnswerCard(
                                          index: i,
                                          text: question.options[i],
                                          scale: scale,
                                          color: feedbackColor(i),
                                          selected: selected == i,
                                          onTap: selected == null
                                              ? () => onAnswer(i)
                                              : null,
                                        ),
                                      ),
                                    SizedBox(height: 10 * scale),
                                  ],
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
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.index,
    required this.text,
    required this.scale,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final int index;
  final String text;
  final double scale;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  static const _badgeColors = [
    [Color(0xFFFFDE70), Color(0xFFFFBE22)],
    [Color(0xFFFF8FB4), Color(0xFFFF5586)],
    [Color(0xFFAC82FF), Color(0xFF8750FF)],
    [Color(0xFF77FFB0), Color(0xFF26ED83)],
  ];

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
              color: Color(0x223F4BD1),
              blurRadius: 14,
              offset: Offset(0, 7),
            ),
          ],
        ),
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
                      width: 44 * scale,
                      height: 44 * scale,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _badgeColors[index % 4],
                        ),
                      ),
                      child: Text(
                        letter,
                        style: MuondiaTypography.screenTitle.copyWith(
                          color: const Color(0xFF09071F),
                          fontSize: 27 * scale,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 18 * scale),
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
    );
  }
}
