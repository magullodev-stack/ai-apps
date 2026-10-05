import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../interaction/ai_stage.dart';

const _defaultFirstQuizMessages = <QuizAiStageMessage>[
  QuizAiStageMessage(
    lead: 'Empezamos sin elegir terreno.',
    highlight: 'Así tiene más gracia.',
    support: 'Voy a mezclarlo todo.',
  ),
  QuizAiStageMessage(
    lead: 'Cuando termines tu primera aventura,',
    highlight: 'pásate por tu perfil.',
    support: 'Déjame conocerte mejor.',
  ),
  QuizAiStageMessage(
    lead: 'Diez preguntas.',
    highlight: 'Alguna va a hacerte dudar.',
    support: 'Eso espero.',
  ),
  QuizAiStageMessage(
    lead: 'Casi está.',
    highlight: 'Luego no digas que no te avisé.',
  ),
];

const _defaultFirstQuizDelayMessage = QuizAiStageMessage(
  lead: 'Vale… esto está tardando más de la cuenta.',
  highlight: 'Me estás haciendo trabajar.',
  support: 'Espero que luego tengas la decencia de fallar alguna.',
);

/// Coreografía fundacional de QuizAI antes del primer Quiz10.
///
/// QuizAI gobierna los beats y su tiempo. La modalidad solo informa de cuándo
/// el test está realmente listo y proporciona la escena visual que desea usar.
class QuizAiFirstQuizSequence extends StatefulWidget {
  const QuizAiFirstQuizSequence({
    super.key,
    required this.ready,
    required this.onCompleted,
    required this.scene,
    this.messages = _defaultFirstQuizMessages,
    this.delayMessage = _defaultFirstQuizDelayMessage,
    this.messageDuration = const Duration(seconds: 4),
    this.delayThreshold = const Duration(seconds: 20),
  }) : assert(messages.length == 4);

  final bool ready;
  final VoidCallback onCompleted;
  final Widget scene;
  final List<QuizAiStageMessage> messages;
  final QuizAiStageMessage delayMessage;
  final Duration messageDuration;
  final Duration delayThreshold;

  @override
  State<QuizAiFirstQuizSequence> createState() =>
      _QuizAiFirstQuizSequenceState();
}

class _QuizAiFirstQuizSequenceState extends State<QuizAiFirstQuizSequence>
    with SingleTickerProviderStateMixin {
  Timer? _messageTimer;
  Timer? _delayTimer;
  Timer? _progressTimer;

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
  void didUpdateWidget(covariant QuizAiFirstQuizSequence oldWidget) {
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

    final remaining = widget.delayThreshold - _experienceWatch.elapsed;

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
        target = 0.80 * (seconds / 10.0);
      } else if (seconds <= 16) {
        target = 0.80 + (0.10 * ((seconds - 10) / 6.0));
      } else {
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

    if (_experienceWatch.elapsed >= widget.delayThreshold &&
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

    return QuizAiStage(
      scene: widget.scene,
      message: message,
      messageKey: messageKey,
      progress: _progress,
    );
  }
}
