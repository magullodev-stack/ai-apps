import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../pivot_images.dart';

/// Cabecera del test: el pivote domina, mientras progreso y tiempo
/// conservan contraste incluso sobre las zonas iluminadas del PNG.
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
      padding: EdgeInsets.symmetric(
        horizontal: 7 * scale,
        vertical: 5 * scale,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (imagePath != null) ...[
                SizedBox(
                  key: const Key('muondia-pivot-icon'),
                  width: 35 * scale,
                  height: 35 * scale,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
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
                    fontWeight: FontWeight.w900,
                    fontSize: 26 * scale,
                    height: 1.05,
                    shadows: const [
                      Shadow(
                        color: Color(0xCC08042A),
                        blurRadius: 7,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10 * scale),
          Row(
            children: [
              Text(
                '$questionNumber/$questionCount',
                key: const Key('muondia-question-counter'),
                semanticsLabel: 'Pregunta $questionNumber de $questionCount',
                style: MuondiaTypography.screenTitle.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 19 * scale,
                  height: 1.15,
                  shadows: const [
                    Shadow(color: Color(0xB00A0630), blurRadius: 3),
                  ],
                ),
              ),
              SizedBox(width: 11 * scale),
              Expanded(
                child: Semantics(
                  label: 'Tiempo restante del test',
                  value: '$secondsRemaining segundos',
                  child: Container(
                    key: const Key('muondia-time-track'),
                    height: 12 * scale,
                    decoration: BoxDecoration(
                      color: const Color(0xF20C0933),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: const Color(0xFFB4C8FB),
                        width: 0.8,
                      ),
                    ),
                    padding: EdgeInsets.all(1 * scale),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: timeFraction.clamp(0.0, 1.0).toDouble(),
                          heightFactor: 1,
                          child: const DecoratedBox(
                            key: Key('muondia-time-fill'),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(100)),
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF8CF5FF),
                                  Color(0xFF41B9FF),
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
              SizedBox(width: 10 * scale),
              Container(
                key: const Key('muondia-timer-capsule'),
                padding: EdgeInsets.symmetric(
                  horizontal: 8 * scale,
                  vertical: 5 * scale,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xDD0D0A36),
                  borderRadius: BorderRadius.circular(14 * scale),
                  border: Border.all(
                    color: const Color(0xAAE2D8FF),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: Colors.white,
                      size: 19 * scale,
                    ),
                    SizedBox(width: 4 * scale),
                    Text(
                      secondsRemaining.toString() + 's',
                      key: const Key('muondia-test-seconds'),
                      style: MuondiaTypography.sectionTitle.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17 * scale,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
