import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_theme.dart';
import '../pivot_images.dart';

/// Cabecera del test real y de su previsualización, sin estado de respuestas.
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
    final scale = MediaQuery.sizeOf(context).width.clamp(320.0, 390.0) / 390;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.6),
            radius: 1.5,
            colors: [Color(0xFF4920C5), Color(0xFF1C174F)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  22 * scale,
                  0,
                  22 * scale,
                  14 * scale,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                          onPressed: () => Navigator.of(context).maybePop(),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 28 * scale,
                          ),
                        ),
                        SizedBox(
                          width: 56 * scale,
                          height: 56 * scale,
                          child: imagePath == null
                              ? null
                              : Image.asset(
                                  imagePath,
                                  fit: BoxFit.contain,
                                  excludeFromSemantics: true,
                                ),
                        ),
                        SizedBox(width: 8 * scale),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              pivot,
                              maxLines: 1,
                              style: MuondiaTypography.screenTitle.copyWith(
                                fontSize: 28 * scale,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4 * scale),
                    LayoutBuilder(
                      builder: (context, constraints) => Row(
                        children: [
                          Text(
                            '$questionNumber/$questionCount',
                            semanticsLabel:
                                'Pregunta $questionNumber de $questionCount',
                            style: MuondiaTypography.screenTitle.copyWith(
                              fontSize: 24 * scale,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(width: 16 * scale),
                          Flexible(
                            child: SizedBox(
                              width: constraints.maxWidth * 0.5,
                              child: Semantics(
                                label: 'Progreso del cuestionario',
                                value: '${(progress * 100).round()}%',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(100),
                                  child: SizedBox(
                                    height: 14 * scale,
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
      ),
    );
  }
}
