import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_theme.dart';

class Quiz10PreparationScreen extends StatefulWidget {
  const Quiz10PreparationScreen({
    super.key,
    this.messages = const [
      'Voy a empezar sin preguntarte por tus temas favoritos. Así tiene más gracia.',
      'Cuando termines tu primera aventura, pásate por tu perfil y déjame conocerte mejor.',
      'Estoy preparando diez preguntas. A ver cuánto tardas en encontrar una que te haga dudar.',
      'Casi está. Luego no digas que no te avisé.',
    ],
    this.messageInterval = const Duration(milliseconds: 3200),
  });

  final List<String> messages;
  final Duration messageInterval;

  @override
  State<Quiz10PreparationScreen> createState() =>
      _Quiz10PreparationScreenState();
}

class _Quiz10PreparationScreenState extends State<Quiz10PreparationScreen>
    with TickerProviderStateMixin {
  Timer? _messageTimer;
  late final AnimationController _floatController;
  late final AnimationController _pulseController;

  int _messageIndex = 0;

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

    if (widget.messages.length > 1) {
      _messageTimer = Timer.periodic(widget.messageInterval, (_) {
        if (!mounted) return;
        setState(() {
          _messageIndex = (_messageIndex + 1) % widget.messages.length;
        });
      });
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _floatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.messages.isEmpty
        ? 'Preparando tu Quiz10…'
        : widget.messages[_messageIndex];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF14044B),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: QuizPalette.backgroundDark,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _sceneLayer('assets/quiz10/loading/quiz10_loading_background_1080x1920.png'),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final t = _ease(_pulseController.value);
                return Opacity(
                  opacity: 0.82 + (0.18 * t),
                  child: Transform.scale(
                    scale: 0.997 + (0.006 * t),
                    child: child,
                  ),
                );
              },
              child: _sceneLayer(
                'assets/quiz10/loading/quiz10_loading_trails_stars_1080x1920.png',
              ),
            ),
            AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                final t = _ease(_floatController.value);
                return Transform.translate(
                  offset: Offset(-2.5 + (5 * t), 4 - (8 * t)),
                  child: child,
                );
              },
              child: _sceneLayer(
                'assets/quiz10/loading/quiz10_loading_robot_1080x1920.png',
              ),
            ),
            AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                final t = _ease(_floatController.value);
                return Transform.translate(
                  offset: Offset(3 - (6 * t), -3 + (6 * t)),
                  child: Transform.scale(
                    scale: 1 + (0.006 * math.sin(t * math.pi)),
                    child: child,
                  ),
                );
              },
              child: _sceneLayer(
                'assets/quiz10/loading/quiz10_loading_dice_1080x1920.png',
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                child: Column(
                  children: [
                    const Spacer(flex: 11),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Semantics(
                        liveRegion: true,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 420),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.06),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: Text(
                            message,
                            key: ValueKey(_messageIndex),
                            textAlign: TextAlign.center,
                            style: QuizTypography.screenTitle.copyWith(
                              color: QuizPalette.foreground,
                              fontSize: 29,
                              height: 1.16,
                              fontWeight: FontWeight.w900,
                              shadows: const [
                                Shadow(
                                  color: Color(0x66000000),
                                  blurRadius: 14,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(flex: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 9,
                          backgroundColor:
                              QuizPalette.foreground.withAlpha(34),
                          color: QuizPalette.primaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

  double _ease(double value) => Curves.easeInOutSine.transform(value);
}
