import 'package:flutter/material.dart';

import '../../modes/estudio/estudio_page.dart';
import '../../modes/quiz10/interaction/quiz_page.dart';
import '../app_theme.dart';
import '../generation_dependencies.dart';

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
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: QuizLayout.maxWidth),
        child: SingleChildScrollView(
          key: const Key('quizai-home-scroll'),
          padding: const EdgeInsets.fromLTRB(
            QuizLayout.horizontalPadding,
            QuizSpacing.sm,
            QuizLayout.horizontalPadding,
            QuizSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HomeHeader(onOpenSettings: onOpenSettings),
              const SizedBox(height: QuizSpacing.md),
              _Quiz10Slot(onTap: () => _openQuiz10(context)),
              const SizedBox(height: QuizSpacing.xl),
              const _SalasHeader(),
              const SizedBox(height: QuizSpacing.md),
              const _SalasSlots(),
              const SizedBox(height: QuizSpacing.xl),
              _DocumentSlot(onTap: () => _openEstudio(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: Row(
        children: [
          Expanded(
            child: Container(
              key: const Key('quizai-home-logo-slot'),
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/home/QuizAI_Home_LOGO.png',
                height: 60,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          const SizedBox(width: QuizSpacing.md),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: QuizPalette.foreground.withAlpha(24),
              border: Border.all(color: QuizPalette.foreground.withAlpha(72)),
            ),
            child: IconButton(
              tooltip: 'Ajustes',
              onPressed: onOpenSettings,
              icon: const Icon(
                Icons.settings_rounded,
                color: QuizPalette.foreground,
                size: 29,
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
    return Semantics(
      button: true,
      label: 'Jugar Quiz10',
      child: Material(
        key: const Key('quizai-home-quiz10'),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(QuizRadii.hero),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            height: 224,
            padding: const EdgeInsets.all(QuizSpacing.xl),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE8265D), Color(0xFFFF6339)],
              ),
              borderRadius: BorderRadius.circular(QuizRadii.hero),
              border: Border.all(
                color: QuizPalette.foreground.withAlpha(220),
                width: 1.6,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  'Quiz10',
                  style: QuizTypography.brand.copyWith(fontSize: 45),
                ),
                const SizedBox(height: QuizSpacing.xs),
                Text(
                  'Cultura general diaria',
                  style: QuizTypography.body.copyWith(
                    color: QuizPalette.foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                const _HomeActionLabel(
                  text: 'Jugar ahora',
                  icon: Icons.chevron_right_rounded,
                ),
              ],
            ),
          ),
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
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Salas',
                style: QuizTypography.screenTitle.copyWith(
                  color: QuizPalette.foreground,
                  fontSize: 34,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '3 retos diarios · rankings · comunidad',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: QuizTypography.body.copyWith(
                  color: QuizPalette.foregroundMuted,
                  fontSize: 15,
                ),
              ),
            ],
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

class _SalasSlots extends StatelessWidget {
  const _SalasSlots();

  @override
  Widget build(BuildContext context) {
    return const Row(
      key: Key('quizai-home-salas'),
      children: [
        Expanded(child: _SalaSlot(id: 'historia', title: 'Historia')),
        SizedBox(width: QuizSpacing.sm),
        Expanded(child: _SalaSlot(id: 'biologia', title: 'Biología')),
        SizedBox(width: QuizSpacing.sm),
        Expanded(
          child: _SalaSlot(id: 'cultura-general', title: 'Cultura\ngeneral'),
        ),
      ],
    );
  }
}

class _SalaSlot extends StatelessWidget {
  const _SalaSlot({required this.id, required this.title});

  final String id;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('quizai-home-sala-$id'),
      height: 142,
      padding: const EdgeInsets.all(QuizSpacing.md),
      decoration: BoxDecoration(
        color: QuizPalette.foreground.withAlpha(12),
        borderRadius: BorderRadius.circular(QuizRadii.card),
        border: Border.all(color: QuizPalette.foreground.withAlpha(80)),
      ),
      alignment: Alignment.bottomLeft,
      child: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: QuizTypography.cardTitle.copyWith(
          color: QuizPalette.foreground,
          fontSize: 20,
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
    return Semantics(
      button: true,
      label: 'Abrir documento de estudio',
      child: AspectRatio(
        aspectRatio: 883 / 380,
        child: Material(
          key: const Key('quizai-home-document'),
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(QuizRadii.hero),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('quizai-document-button'),
            onTap: onTap,
            child: Image.asset(
              'assets/home/QuizAI_Home_Subir_Archivo.png',
              fit: BoxFit.contain,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeActionLabel extends StatelessWidget {
  const _HomeActionLabel({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48, maxWidth: 210),
      padding: const EdgeInsets.fromLTRB(18, 7, 7, 7),
      decoration: BoxDecoration(
        color: QuizPalette.surfaceElevated,
        borderRadius: BorderRadius.circular(QuizRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: QuizTypography.label.copyWith(
                color: QuizPalette.backgroundDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: QuizSpacing.sm),
          CircleAvatar(
            radius: 17,
            backgroundColor: QuizPalette.primary,
            child: Icon(icon, color: QuizPalette.foreground, size: 23),
          ),
        ],
      ),
    );
  }
}
