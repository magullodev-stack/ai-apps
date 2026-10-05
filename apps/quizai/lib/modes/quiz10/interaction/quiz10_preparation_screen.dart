import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_theme.dart';

class Quiz10PreparationScreen extends StatefulWidget {
  const Quiz10PreparationScreen({
    super.key,
    required this.title,
    required this.headline,
    required this.steps,
    required this.footerMessage,
    required this.illustration,
    required this.onBack,
    this.footerIcon = Icons.lightbulb_rounded,
    this.stepInterval = const Duration(milliseconds: 2200),
  });

  final String title;
  final String headline;
  final List<String> steps;
  final String footerMessage;
  final Widget illustration;
  final VoidCallback onBack;
  final IconData footerIcon;
  final Duration stepInterval;

  @override
  State<Quiz10PreparationScreen> createState() => _Quiz10PreparationScreenState();
}

class _Quiz10PreparationScreenState extends State<Quiz10PreparationScreen> {
  Timer? _stepTimer;
  int _activeStep = 0;

  @override
  void initState() {
    super.initState();

    if (widget.steps.length > 1) {
      _stepTimer = Timer.periodic(widget.stepInterval, (_) {
        if (!mounted) return;

        if (_activeStep >= widget.steps.length - 1) {
          _stepTimer?.cancel();
          return;
        }

        setState(() => _activeStep++);
      });
    }
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: QuizPalette.backgroundDark,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF5724D2),
                QuizPalette.background,
                QuizPalette.backgroundDark,
              ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    QuizLayout.horizontalPadding,
                    QuizSpacing.sm,
                    QuizLayout.horizontalPadding,
                    QuizSpacing.xl,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          constraints.maxHeight -
                          QuizSpacing.sm -
                          QuizSpacing.xl,
                      maxWidth: QuizLayout.maxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PreparationHeader(
                          title: widget.title,
                          onBack: widget.onBack,
                        ),
                        const SizedBox(height: QuizSpacing.xl),
                        _PreparationHero(illustration: widget.illustration),
                        const SizedBox(height: QuizSpacing.xl),
                        Text(
                          widget.headline,
                          textAlign: TextAlign.center,
                          style: QuizTypography.screenTitle.copyWith(
                            color: QuizPalette.foreground,
                            fontSize: 27,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: QuizSpacing.xl),
                        for (
                          var index = 0;
                          index < widget.steps.length;
                          index++
                        )
                          _PreparationStepRow(
                            label: widget.steps[index],
                            state: index < _activeStep
                                ? _PreparationStepState.complete
                                : index == _activeStep
                                ? _PreparationStepState.active
                                : _PreparationStepState.pending,
                          ),
                        const SizedBox(height: QuizSpacing.xxl),
                        _PreparationMessage(
                          icon: widget.footerIcon,
                          message: widget.footerMessage,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PreparationHeader extends StatelessWidget {
  const _PreparationHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Volver',
          onPressed: onBack,
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: QuizPalette.foreground,
          ),
        ),
        const SizedBox(width: QuizSpacing.xs),
        Text(
          title,
          style: QuizTypography.sectionTitle.copyWith(
            color: QuizPalette.foreground,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _PreparationHero extends StatelessWidget {
  const _PreparationHero({required this.illustration});

  final Widget illustration;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 216,
            height: 216,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  QuizPalette.primaryLight.withAlpha(100),
                  QuizPalette.primary.withAlpha(35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Positioned(
            top: 18,
            right: 56,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 31,
              color: const Color(0xFFE56DFF).withAlpha(220),
            ),
          ),
          Positioned(
            bottom: 39,
            left: 56,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: QuizPalette.info.withAlpha(185),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.92, end: 1),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              width: 150,
              height: 150,
              padding: const EdgeInsets.all(QuizSpacing.xl),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(42),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFB174FF),
                    Color(0xFF7A3AF2),
                    Color(0xFF4F20BC),
                  ],
                ),
                border: Border.all(
                  color: QuizPalette.foreground.withAlpha(125),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: QuizPalette.primaryLight.withAlpha(95),
                    blurRadius: 36,
                    spreadRadius: 2,
                  ),
                  const BoxShadow(
                    color: Color(0x52000000),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Center(child: illustration),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PreparationStepState { complete, active, pending }

class _PreparationStepRow extends StatelessWidget {
  const _PreparationStepRow({required this.label, required this.state});

  final String label;
  final _PreparationStepState state;

  @override
  Widget build(BuildContext context) {
    final complete = state == _PreparationStepState.complete;
    final active = state == _PreparationStepState.active;

    return Semantics(
      liveRegion: active,
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: QuizSpacing.lg,
          vertical: 7,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: QuizDurations.fast,
              curve: QuizDurations.curve,
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: complete
                    ? QuizPalette.success
                    : active
                    ? QuizPalette.foreground.withAlpha(18)
                    : Colors.transparent,
                border: Border.all(
                  color: complete
                      ? QuizPalette.success
                      : active
                      ? QuizPalette.primaryLight
                      : QuizPalette.foreground.withAlpha(115),
                  width: 2,
                ),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: QuizDurations.fast,
                  child: complete
                      ? const Icon(
                          Icons.check_rounded,
                          key: ValueKey('complete'),
                          size: 17,
                          color: QuizPalette.foreground,
                        )
                      : active
                      ? const SizedBox(
                          key: ValueKey('active'),
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: QuizPalette.primaryLight,
                          ),
                        )
                      : const SizedBox(
                          key: ValueKey('pending'),
                          width: 1,
                          height: 1,
                        ),
                ),
              ),
            ),
            const SizedBox(width: QuizSpacing.md),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: QuizDurations.fast,
                curve: QuizDurations.curve,
                style: QuizTypography.body.copyWith(
                  color: active || complete
                      ? QuizPalette.foreground
                      : QuizPalette.foregroundMuted.withAlpha(190),
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
                child: Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreparationMessage extends StatelessWidget {
  const _PreparationMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(QuizSpacing.lg),
      decoration: BoxDecoration(
        color: QuizPalette.backgroundDark.withAlpha(145),
        borderRadius: BorderRadius.circular(QuizRadii.medium),
        border: Border.all(color: QuizPalette.primaryLight.withAlpha(105)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: QuizPalette.warning.withAlpha(28),
              borderRadius: BorderRadius.circular(QuizRadii.small),
            ),
            child: Icon(icon, color: QuizPalette.warning, size: 27),
          ),
          const SizedBox(width: QuizSpacing.md),
          Expanded(
            child: Text(
              message,
              style: QuizTypography.body.copyWith(
                color: QuizPalette.foreground,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
