import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../modes/estudio/estudio_page.dart';
import '../../modes/quiz10/interaction/quiz_page.dart';
import '../app_theme.dart';
import '../generation_dependencies.dart';

abstract final class _HomeLayout {
  static const logoWidth = 140.0;
  static const logoHeight = 36.0;
  static const headerHeight = 44.0;
  static const headerFadeHeight = 24.0;
  static const heroHeight = 206.0;
  static const documentHeight = heroHeight;
  static const bottomNavHeight = 70.0;
  static const bottomNavOuterPadding = QuizSpacing.sm;
  static const bottomExtraClearance = 28.0;
}

class _HomeCardFrame extends StatelessWidget {
  const _HomeCardFrame({
    super.key,
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x665F2EFF),
                    blurRadius: 4,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: child,
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0x99D8B7FF),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estructura de la pantalla principal de QuizAI.
///
/// La composición fija la jerarquía de producto. El arte definitivo de cada
/// bloque y el logotipo se incorporan como recursos independientes.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  Future<void> _openQuiz10(BuildContext context) async {
    final dependencies = QuizAiGenerationDependencies();
    try {
      await Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) =>
              QuizPage(loadQuestions: dependencies.quiz10Pipeline.generate),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } finally {
      dependencies.close();
    }
  }

  Future<void> _openEstudio(BuildContext context) async {
    final dependencies = QuizAiGenerationDependencies();
    try {
      await Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => EstudioPage(
            generator: dependencies.catalogGenerator,
            questionGenerator: dependencies.questionGenerator,
            documentQuizGenerator: dependencies.documentQuizGenerator,
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } finally {
      dependencies.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.paddingOf(context);
    final topInset = mediaPadding.top;
    final bottomInset = mediaPadding.bottom;
    final headerExtent =
        topInset + _HomeLayout.headerHeight + _HomeLayout.headerFadeHeight;
    final bottomClearance =
        _HomeLayout.bottomNavHeight +
        _HomeLayout.bottomNavOuterPadding +
        bottomInset +
        _HomeLayout.bottomExtraClearance;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: QuizLayout.maxWidth),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SingleChildScrollView(
              key: const Key('quizai-home-scroll'),
              padding: EdgeInsets.fromLTRB(
                QuizLayout.horizontalPadding,
                headerExtent,
                QuizLayout.horizontalPadding,
                bottomClearance,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Quiz10Slot(onTap: () => _openQuiz10(context)),
                  const SizedBox(height: 10),
                  const _SalasModule(),
                  const SizedBox(height: 10),
                  _DocumentSlot(onTap: () => _openEstudio(context)),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _HomeHeader(
                topInset: topInset,
                onOpenSettings: onOpenSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.topInset,
    required this.onOpenSettings,
  });

  final double topInset;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: topInset + _HomeLayout.headerHeight + _HomeLayout.headerFadeHeight,
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.48, 0.78, 1],
                    colors: [
                      Color(0xF238149B),
                      Color(0xD638149B),
                      Color(0x7038149B),
                      Color(0x0038149B),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: topInset,
              left: QuizLayout.horizontalPadding,
              right: QuizLayout.horizontalPadding,
            ),
            child: SizedBox(
              height: _HomeLayout.headerHeight,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      key: const Key('quizai-home-logo-slot'),
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: _HomeLayout.logoWidth,
                        height: _HomeLayout.logoHeight,
                        child: Image.asset(
                          'assets/home/QuizAI_Home_LOGO.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: QuizSpacing.sm),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0x994B2C9C),
                        border: Border.all(
                          color: QuizPalette.foreground.withAlpha(82),
                        ),
                      ),
                      child: IconButton(
                        tooltip: 'Ajustes',
                        padding: EdgeInsets.zero,
                        onPressed: onOpenSettings,
                        icon: const Icon(
                          Icons.settings_rounded,
                          color: QuizPalette.foreground,
                          size: 23,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Quiz10Slot extends StatelessWidget {
  const _Quiz10Slot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _HomeCardFrame(
      key: const Key('quizai-home-quiz10'),
      height: _HomeLayout.heroHeight,
      child: Semantics(
        button: true,
        label: 'Jugar Quiz10',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Ink.image(
              image: const AssetImage(
                'assets/home/QuizAI_Home_Partida_rápida.png',
              ),
              fit: BoxFit.cover,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SalasModule extends StatelessWidget {
  const _SalasModule();

  @override
  Widget build(BuildContext context) {
    return const _HomeCardFrame(
      height: _HomeLayout.heroHeight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 8, 8, 6),
        child: Column(
          children: [
            _SalasHeader(),
            Expanded(child: _SalasSlots()),
          ],
        ),
      ),
    );
  }
}

class _SalasHeader extends StatelessWidget {
  const _SalasHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('quizai-home-salas-header'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Image.asset(
            'assets/home/QuizAI_Home_Icono_Salas.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Salas',
            style: QuizTypography.screenTitle.copyWith(
              color: QuizPalette.foreground,
              fontSize: 33,
            ),
          ),
        ),
        const SizedBox(width: QuizSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(QuizRadii.pill),
            border: Border.all(color: QuizPalette.foreground.withAlpha(66)),
            color: QuizPalette.foreground.withAlpha(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ver todas',
                style: QuizTypography.label.copyWith(
                  color: QuizPalette.foreground,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: QuizSpacing.xs),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: QuizPalette.foreground,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SalasSlots extends StatefulWidget {
  const _SalasSlots();

  @override
  State<_SalasSlots> createState() => _SalasSlotsState();
}

class _SalasSlotsState extends State<_SalasSlots>
    with SingleTickerProviderStateMixin {
  static const _salas = <_SalaData>[
    _SalaData(id: 'historia', title: 'Historia'),
    _SalaData(id: 'biologia', title: 'Biología'),
    _SalaData(id: 'cultura-general', title: 'Cultura\ngeneral'),
    _SalaData(id: 'ciencia', title: 'Ciencia'),
    _SalaData(id: 'geografia', title: 'Geografía'),
  ];

  static const _itemTravel = 82.0;
  static const _minimumFlingVelocity = 140.0;
  static const _maximumLogicalVelocity = 16.0;
  static const _friction = 0.075;

  late final AnimationController _motionController;
  double _position = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController.unbounded(
      vsync: this,
      value: _position,
    )..addListener(() {
        if (!mounted || _dragging) return;
        setState(() {
          _position = _motionController.value;
        });
      });
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  double _relativePosition(int index) {
    final count = _salas.length.toDouble();
    var relative = (index - _position) % count;
    if (relative > count / 2) relative -= count;
    if (relative < -count / 2) relative += count;
    return relative;
  }

  double _targetForIndex(int index) {
    final count = _salas.length.toDouble();
    var target = index.toDouble();
    while (target - _position > count / 2) {
      target -= count;
    }
    while (target - _position < -count / 2) {
      target += count;
    }
    return target;
  }

  void _syncControllerToPosition() {
    if ((_motionController.value - _position).abs() > 0.0001) {
      _motionController.value = _position;
    }
  }

  void _animateTo(double target, {Duration? duration}) {
    _motionController.stop();
    _syncControllerToPosition();

    final distance = (target - _position).abs();
    final snapDuration =
        duration ??
        Duration(
          milliseconds: (120 + (distance * 70)).round().clamp(120, 260).toInt(),
        );

    _motionController
        .animateTo(
          target,
          duration: snapDuration,
          curve: Curves.easeOutCubic,
        )
        .whenCompleteOrCancel(_normalizePosition);
  }

  void _normalizePosition() {
    if (!mounted || _dragging || _motionController.isAnimating) return;

    final count = _salas.length.toDouble();
    var normalized = _position % count;
    if (normalized < 0) normalized += count;

    if ((_position - normalized).abs() > 0.0001) {
      _position = normalized;
      _motionController.value = normalized;
    }
  }

  void _snapToNearest() {
    if (!mounted || _dragging) return;
    _animateTo(_position.roundToDouble());
  }

  void _onDragStart(DragStartDetails details) {
    _dragging = true;
    _motionController.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    if (delta == 0) return;

    setState(() {
      _position -= delta / _itemTravel;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    _dragging = false;

    final pixelVelocity = details.primaryVelocity ?? 0;

    // A finger that has already stopped before being lifted should not create
    // momentum. Only the velocity that still exists at release starts a fling.
    if (pixelVelocity.abs() < _minimumFlingVelocity) {
      _snapToNearest();
      return;
    }

    final logicalVelocity = (-pixelVelocity / _itemTravel)
        .clamp(-_maximumLogicalVelocity, _maximumLogicalVelocity)
        .toDouble();

    _syncControllerToPosition();

    final simulation = FrictionSimulation(
      _friction,
      _position,
      logicalVelocity,
      tolerance: const Tolerance(
        distance: 0.001,
        velocity: 0.08,
      ),
    );

    _motionController.animateWith(simulation).whenCompleteOrCancel(() {
      if (!mounted || _dragging) return;
      _snapToNearest();
    });
  }

  void _onDragCancel() {
    _dragging = false;
    _motionController.stop();
    _snapToNearest();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('quizai-home-salas'),
      height: 138,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final centerX = constraints.maxWidth / 2;
          final paintOrder = List<int>.generate(_salas.length, (index) => index)
            ..sort((a, b) {
              final aDistance = _relativePosition(a).abs();
              final bDistance = _relativePosition(b).abs();
              return bDistance.compareTo(aDistance);
            });

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            onHorizontalDragCancel: _onDragCancel,
            child: ClipRect(
              child: Stack(
                children: [
                  for (final index in paintOrder)
                    _buildCarouselItem(index, centerX),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCarouselItem(int index, double centerX) {
    final sala = _salas[index];
    final relative = _relativePosition(index);
    final distance = relative.abs().clamp(0.0, 2.0);

    final offset = distance <= 1
        ? relative * 82
        : relative.sign * (82 + ((distance - 1) * 62));

    final scale = distance <= 1
        ? 1 - (distance * 0.16)
        : 0.84 - ((distance - 1) * 0.18);

    const top = 10.0;
    final opacity = distance <= 1 ? 1.0 : 0.82;
    final isCentered = distance < 0.35;

    return Positioned(
      key: ValueKey('quizai-home-sala-${sala.id}'),
      left: centerX - 64 + offset,
      top: top,
      width: 128,
      height: 126,
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: _SalaSlot(
            id: sala.id,
            title: sala.title,
            selected: isCentered,
            onTap: () => _animateTo(_targetForIndex(index)),
          ),
        ),
      ),
    );
  }
}

class _SalaData {
  const _SalaData({required this.id, required this.title});

  final String id;
  final String title;
}

class _SalaSlot extends StatelessWidget {
  const _SalaSlot({
    required this.id,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Sala $title',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(QuizRadii.card),
          child: Ink(
            padding: const EdgeInsets.all(QuizSpacing.md),
            decoration: BoxDecoration(
              color: QuizPalette.foreground.withAlpha(selected ? 22 : 12),
              borderRadius: BorderRadius.circular(QuizRadii.card),
              border: Border.all(
                color: QuizPalette.foreground.withAlpha(selected ? 155 : 72),
                width: selected ? 1.4 : 1.0,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: QuizPalette.primaryLight.withAlpha(70),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: QuizTypography.cardTitle.copyWith(
                  color: QuizPalette.foreground,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentSlot extends StatelessWidget {
  const _DocumentSlot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _HomeCardFrame(
      key: const Key('quizai-home-document'),
      height: _HomeLayout.documentHeight,
      child: Semantics(
        button: true,
        label: 'Estudio con archivos',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('quizai-document-button'),
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/home/QuizAI_Home_Subir_Archivo.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  right: 120,
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Text(
                              '🎓',
                              style: TextStyle(
                                fontSize: 30,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Estudio',
                          maxLines: 1,
                          style: QuizTypography.screenTitle.copyWith(
                            color: QuizPalette.foreground,
                            fontSize: 33,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 18,
                  right: 185,
                  child: Text.rich(
                    TextSpan(
                      style: QuizTypography.body.copyWith(
                        fontSize: 18,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Tus archivos,\n',
                          style: TextStyle(
                            color: QuizPalette.foreground,
                          ),
                        ),
                        TextSpan(
                          text: 'tus quizzes',
                          style: TextStyle(
                            color: QuizPalette.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
