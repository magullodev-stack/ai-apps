import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Escena visual del recorrido interactivo inicial de Muondia.
///
/// Solo conoce sus assets y sus movimientos. No gobierna mensajes, tiempos,
/// onboarding ni la generación del test.
class OnboardingQuizLoadingScene extends StatefulWidget {
  const OnboardingQuizLoadingScene({super.key});

  @override
  State<OnboardingQuizLoadingScene> createState() => _OnboardingQuizLoadingSceneState();
}

class _OnboardingQuizLoadingSceneState extends State<OnboardingQuizLoadingScene>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Transform.scale(
            scale: 1.12,
            child: _sceneLayer(
              'assets/onboarding/loading/onboarding_loading_background_1080x1920.png',
            ),
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final t = Curves.easeInOutSine.transform(_pulseController.value);
            return Opacity(
              opacity: 0.82 + (0.18 * t),
              child: Transform.scale(
                scale: 0.997 + (0.006 * t),
                child: child,
              ),
            );
          },
          child: _sceneLayer(
            'assets/onboarding/loading/onboarding_loading_trails_stars_1080x1920.png',
          ),
        ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            final t = Curves.easeInOutSine.transform(_floatController.value);
            return Transform.translate(
              offset: Offset(-2.5 + (5 * t), 4 - (8 * t)),
              child: child,
            );
          },
          child: _sceneLayer(
            'assets/onboarding/loading/onboarding_loading_robot_1080x1920.png',
          ),
        ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            final t = Curves.easeInOutSine.transform(_floatController.value);
            return Transform.translate(
              offset: Offset(3 - (6 * t), -3 + (6 * t)),
              child: Transform.rotate(
                angle: -0.012 + (0.024 * t),
                child: Transform.scale(
                  scale: 1 + (0.006 * math.sin(t * math.pi)),
                  child: child,
                ),
              ),
            );
          },
          child: _sceneLayer(
            'assets/onboarding/loading/onboarding_loading_dice_1080x1920.png',
          ),
        ),
        ),
      ],
    );
  }

  Widget _sceneLayer(String asset) {
    return IgnorePointer(
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      ),
    );
  }
}
