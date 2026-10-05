import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_theme.dart';

class Quiz10LoadingMessage {
  const Quiz10LoadingMessage({
    required this.lead,
    required this.highlight,
    this.support,
  });

  final String lead;
  final String highlight;
  final String? support;
}

const _defaultLoadingMessages = <Quiz10LoadingMessage>[
  Quiz10LoadingMessage(
    lead: 'Empezamos sin elegir terreno.',
    highlight: 'Así tiene más gracia.',
    support: 'Voy a mezclarlo todo.',
  ),
  Quiz10LoadingMessage(
    lead: 'Cuando termines tu primera aventura,',
    highlight: 'pásate por tu perfil.',
    support: 'Déjame conocerte mejor.',
  ),
  Quiz10LoadingMessage(
    lead: 'Diez preguntas.',
    highlight: 'Alguna va a hacerte dudar.',
    support: 'Eso espero.',
  ),
  Quiz10LoadingMessage(
    lead: 'Casi está.',
    highlight: 'Luego no digas que no te avisé.',
  ),
];

const _defaultDelayMessage = Quiz10LoadingMessage(
  lead: 'Vale… esto está tardando más de la cuenta.',
  highlight: 'Me estás haciendo trabajar.',
  support: 'Espero que luego tengas la decencia de fallar alguna.',
);

class Quiz10PreparationScreen extends StatefulWidget {
  const Quiz10PreparationScreen({
    super.key,
    required this.ready,
    required this.onCompleted,
    this.messages = _defaultLoadingMessages,
    this.delayMessage = _defaultDelayMessage,
    this.messageDuration = const Duration(seconds: 4),
    this.delayThreshold = const Duration(seconds: 20),
  }) : assert(messages.length == 4);

  final bool ready;
  final VoidCallback onCompleted;

  /// Los cuatro beats fundacionales de la primera carga.
  final List<Quiz10LoadingMessage> messages;

  /// Beat especial que solo aparece si la preparación alcanza el umbral de demora.
  final Quiz10LoadingMessage delayMessage;

  final Duration messageDuration;
  final Duration delayThreshold;

  @override
  State<Quiz10PreparationScreen> createState() =>
      _Quiz10PreparationScreenState();
}

class _Quiz10PreparationScreenState extends State<Quiz10PreparationScreen>
    with TickerProviderStateMixin {
  Timer? _messageTimer;
  Timer? _delayTimer;
  Timer? _progressTimer;

  late final AnimationController _floatController;
  late final AnimationController _pulseController;
  late final AnimationController _completionController;

  final math.Random _progressRandom = math.Random();
  final Stopwatch _experienceWatch = Stopwatch();

  int _messageIndex = 0;
  bool _foundationComplete = false;
  bool _delayMessageActive = false;
  bool _delayMessageFinished = false;

  double _progress = 0.01;
  double _completionStart = 0;
  bool _completionNotified = false;

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

    _completionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )
      ..addListener(_tickCompletion)
      ..addStatusListener(_handleCompletionStatus);

    _experienceWatch.start();
    _scheduleProgressTick();
    _scheduleNextFoundationBeat();

    if (widget.ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryCompleteProgress();
      });
    }
  }

  @override
  void didUpdateWidget(covariant Quiz10PreparationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.ready && widget.ready) {
      _tryCompleteProgress();
    }
  }

  void _scheduleNextFoundationBeat() {
    _messageTimer?.cancel();
    _messageTimer = Timer(widget.messageDuration, () {
      if (!mounted || _completionNotified) return;

      if (_messageIndex < widget.messages.length - 1) {
        setState(() => _messageIndex++);
        _scheduleNextFoundationBeat();
        return;
      }

      _foundationComplete = true;
      _tryCompleteProgress();

      if (!_completionController.isAnimating && !_completionNotified) {
        _scheduleDelayBeat();
      }
    });
  }

  void _scheduleDelayBeat() {
    _delayTimer?.cancel();

    final remaining =
        widget.delayThreshold - _experienceWatch.elapsed;

    if (remaining <= Duration.zero) {
      _activateDelayBeat();
      return;
    }

    _delayTimer = Timer(remaining, () {
      if (!mounted || _completionNotified) return;
      if (!widget.ready) {
        _activateDelayBeat();
      } else {
        _tryCompleteProgress();
      }
    });
  }

  void _activateDelayBeat() {
    if (_delayMessageActive ||
        _delayMessageFinished ||
        _completionController.isAnimating ||
        _completionNotified) {
      return;
    }

    setState(() => _delayMessageActive = true);

    _messageTimer?.cancel();
    _messageTimer = Timer(widget.messageDuration, () {
      if (!mounted || _completionNotified) return;

      _delayMessageFinished = true;
      _tryCompleteProgress();
    });
  }

  void _scheduleProgressTick() {
    if (_completionController.isAnimating || _completionNotified) return;

    final delay = Duration(
      milliseconds: 260 + _progressRandom.nextInt(440),
    );

    _progressTimer = Timer(delay, () {
      if (!mounted ||
          _completionController.isAnimating ||
          _completionNotified) {
        return;
      }

      final seconds = _experienceWatch.elapsedMilliseconds / 1000.0;

      double target;
      if (seconds <= 10) {
        // Aproximadamente 80 % a los 10 s.
        target = 0.80 * (seconds / 10.0);
      } else if (seconds <= 16) {
        // Del 80 % al 90 % durante los dos últimos beats fundacionales.
        target = 0.80 + (0.10 * ((seconds - 10) / 6.0));
      } else {
        // Después avanza casi imperceptiblemente y nunca completa por sí sola.
        target = 0.90 + math.min(0.04, (seconds - 16) * 0.002);
      }

      final jitter = _progressRandom.nextDouble() * 0.007;
      final next = math.min(
        0.94,
        math.max(_progress, target + jitter),
      );

      if ((next - _progress).abs() > 0.0005) {
        setState(() => _progress = next);
      }

      _scheduleProgressTick();
    });
  }

  void _tryCompleteProgress() {
    if (!widget.ready ||
        !_foundationComplete ||
        _completionNotified ||
        _completionController.isAnimating) {
      return;
    }

    final elapsed = _experienceWatch.elapsed;

    // Si el test no estuvo listo antes de los 20 s, el beat de demora
    // forma parte de la experiencia y no se corta a mitad.
    if (elapsed >= widget.delayThreshold &&
        !_delayMessageFinished) {
      _activateDelayBeat();
      return;
    }

    if (_delayMessageActive && !_delayMessageFinished) {
      return;
    }

    _completeProgress();
  }

  void _completeProgress() {
    if (_completionNotified || _completionController.isAnimating) return;

    _messageTimer?.cancel();
    _delayTimer?.cancel();
    _progressTimer?.cancel();
    _experienceWatch.stop();

    _completionStart = _progress;
    _completionController.forward(from: 0);
  }

  void _tickCompletion() {
    if (!mounted) return;

    final eased = Curves.easeInCubic.transform(_completionController.value);
    setState(() {
      _progress = _completionStart + ((1 - _completionStart) * eased);
    });
  }

  void _handleCompletionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _completionNotified) return;

    _completionNotified = true;
    _progress = 1;
    widget.onCompleted();
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _delayTimer?.cancel();
    _progressTimer?.cancel();
    _experienceWatch.stop();
    _floatController.dispose();
    _pulseController.dispose();
    _completionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _delayMessageActive
        ? widget.delayMessage
        : widget.messages[_messageIndex];

    final messageKey = _delayMessageActive
        ? 'delay'
        : 'foundation-$_messageIndex';

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
            _sceneLayer(
              'assets/quiz10/loading/quiz10_loading_background_1080x1920.png',
            ),
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
                                    begin: const Offset(0, 0.05),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: _LoadingCopy(
                            key: ValueKey(messageKey),
                            message: message,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(flex: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: _Quiz10LoadingBar(
                        progress: _progress,
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

class _LoadingCopy extends StatelessWidget {
  const _LoadingCopy({
    super.key,
    required this.message,
  });

  final Quiz10LoadingMessage message;

  @override
  Widget build(BuildContext context) {
    final support = message.support?.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.lead,
          textAlign: TextAlign.center,
          style: QuizTypography.screenTitle.copyWith(
            color: QuizPalette.foreground,
            fontSize: 26,
            height: 1.12,
            fontWeight: FontWeight.w800,
            shadows: _textShadows,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          message.highlight,
          textAlign: TextAlign.center,
          style: QuizTypography.screenTitle.copyWith(
            color: const Color(0xFFD6A7FF),
            fontSize: 35,
            height: 1.02,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            shadows: _textShadows,
          ),
        ),
        if (support != null && support.isNotEmpty) ...[
          const SizedBox(height: 13),
          Text(
            support,
            textAlign: TextAlign.center,
            style: QuizTypography.body.copyWith(
              color: QuizPalette.foreground.withAlpha(225),
              fontSize: 19,
              height: 1.28,
              fontWeight: FontWeight.w700,
              shadows: _textShadows,
            ),
          ),
        ],
      ],
    );
  }

  static const _textShadows = [
    Shadow(
      color: Color(0x66000000),
      blurRadius: 14,
      offset: Offset(0, 3),
    ),
  ];
}

class _Quiz10LoadingBar extends StatelessWidget {
  const _Quiz10LoadingBar({
    required this.progress,
  });

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = math.max(0.0, constraints.maxWidth - 6);
          final fillWidth = math.max(
            8.0,
            available * progress.clamp(0.0, 1.0),
          );

          return DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0x33100045),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFF9D75FF).withAlpha(170),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8F5CFF).withAlpha(70),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  width: fillWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF855CFF),
                        Color(0xFFD18CFF),
                        Color(0xFFF5D6FF),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD89BFF).withAlpha(205),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.white.withAlpha(90),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
