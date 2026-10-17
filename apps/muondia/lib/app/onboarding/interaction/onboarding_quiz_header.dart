import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../pivot_images.dart';

/// Cabecera compacta del test: identidad temática y tiempo global.
class OnboardingQuizHeader extends StatelessWidget {
  const OnboardingQuizHeader({
    super.key,
    required this.pivot,
    required this.questionNumber,
    required this.questionCount,
    required this.secondsRemaining,
    required this.timeFraction,
  });

  final String pivot;
  final int questionNumber;
  final int questionCount;
  final int secondsRemaining;
  final double timeFraction;

  @override
  Widget build(BuildContext context) {
    final imagePath = onboardingPivotImageFor(pivot);
    final scale = (MediaQuery.sizeOf(context).width / 390.0)
        .clamp(0.82, 1.1)
        .toDouble();
    return Padding(
      padding: EdgeInsets.fromLTRB(8 * scale, 6 * scale, 8 * scale, 14 * scale),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (imagePath != null) ...[
                SizedBox(
                  key: const Key('muondia-pivot-icon'),
                  width: 40 * scale,
                  height: 40 * scale,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
                SizedBox(width: 10 * scale),
              ],
              Expanded(
                child: Text(
                  pivot,
                  key: const Key('muondia-pivot-title'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MuondiaTypography.screenTitle.copyWith(
                    color: Colors.white,
                    fontSize: 21 * scale,
                    height: 1.05,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * scale),
          Row(
            children: [
              Text(
                '$questionNumber/$questionCount',
                key: const Key('muondia-question-counter'),
                semanticsLabel: 'Pregunta $questionNumber de $questionCount',
                style: MuondiaTypography.screenTitle.copyWith(
                  color: Colors.white,
                  fontSize: 20 * scale,
                  height: 1.15,
                ),
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Semantics(
                  label: 'Tiempo restante del test',
                  value: '$secondsRemaining segundos',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: SizedBox(
                      height: 11 * scale,
                      child: ColoredBox(
                        color: const Color(0xFF40358E),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: timeFraction.clamp(0.0, 1.0).toDouble(),
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
              SizedBox(width: 10 * scale),
              Icon(
                Icons.timer_outlined,
                color: Colors.white,
                size: 21 * scale,
              ),
              SizedBox(width: 3 * scale),
              Text(
                secondsRemaining.toString() + 's',
                key: const Key('muondia-test-seconds'),
                style: MuondiaTypography.screenTitle.copyWith(
                  color: Colors.white,
                  fontSize: 19 * scale,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
