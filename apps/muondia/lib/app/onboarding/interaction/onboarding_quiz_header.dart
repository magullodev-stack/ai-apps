import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../pivot_images.dart';

/// Cabecera integrada en el escenario del test, sin fondo independiente.
class OnboardingQuizHeader extends StatelessWidget {
  const OnboardingQuizHeader({
    super.key,
    required this.pivot,
    required this.questionNumber,
    required this.questionCount,
  });
  final String pivot;
  final int questionNumber;
  final int questionCount;

  @override
  Widget build(BuildContext context) {
    final imagePath = onboardingPivotImageFor(pivot);
    final progress = questionNumber / questionCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              SizedBox(
                width: 58,
                height: 58,
                child: imagePath == null
                    ? null
                    : Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    pivot,
                    maxLines: 1,
                    style: MuondiaTypography.screenTitle.copyWith(
                      color: Colors.white,
                      fontSize: 28,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '$questionNumber/$questionCount',
                semanticsLabel: 'Pregunta $questionNumber de $questionCount',
                style: MuondiaTypography.screenTitle.copyWith(
                  color: Colors.white,
                  fontSize: 26,
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Semantics(
                  label: 'Progreso del cuestionario',
                  value: '${(progress * 100).round()}%',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: SizedBox(
                      height: 14,
                      child: ColoredBox(
                        color: const Color(0xFF40358E),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: progress,
                            heightFactor: 1,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(100),
                                ),
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF8528FF),
                                    Color(0xFF702CFA),
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
            ],
          ),
        ],
      ),
    );
  }
}
