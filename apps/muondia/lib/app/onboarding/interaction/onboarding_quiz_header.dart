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
                  child: ClipRRect(
                    key: const Key('muondia-time-track'),
                    borderRadius: BorderRadius.circular(100),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      height: 13 * scale,
                      child: ColoredBox(
                        color: const Color(0xFF493A9A),
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
                                    Color(0xFFAC56FC),
                                    Color(0xFF8A3FF2),
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
              SizedBox(width: 16 * scale),
              Row(
                key: const Key('muondia-timer-inline'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: Colors.white,
                    size: 26 * scale,
                  ),
                  SizedBox(width: 5 * scale),
                  Text(
                    secondsRemaining.toString() + 's',
                    key: const Key('muondia-test-seconds'),
                    style: MuondiaTypography.screenTitle.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22 * scale,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
