import 'package:flutter/material.dart';

import '../../modes/quiz10/quiz_generation.dart';
import '../../modes/quiz10/quiz_page.dart';
import '../app_theme.dart';
import 'modalidad_card.dart';

class ModalidadesPage extends StatelessWidget {
  const ModalidadesPage({super.key, this.generator});

  final QuizGenerator? generator;

  void _openQuiz10(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => QuizPage(generator: generator)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          key: const Key('quizai-home-scroll'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _StatisticsRow(),

              const SizedBox(height: 16),

              _Quiz10Hero(onTap: () => _openQuiz10(context)),

              const SizedBox(height: 16),

              const ModalidadCard(
                title: '🏆 Sala',
                subtitle: 'Juega con amigos',
                icon: Icons.groups_rounded,
                colors: [QuizPalette.salaStart, QuizPalette.salaEnd],
              ),

              const ModalidadCard(
                title: '⚔️ 1vs1',
                subtitle: 'Reta a otro jugador',
                icon: Icons.bolt_rounded,
                colors: [QuizPalette.versusStart, QuizPalette.versusEnd],
              ),

              const ModalidadCard(
                title: '📚 Estudio',
                subtitle: 'Aprende a tu ritmo',
                icon: Icons.school_rounded,
                colors: [QuizPalette.estudioStart, QuizPalette.estudioEnd],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// ESTADÍSTICAS
// ------------------------------------------------------------

/// Los indicadores permanecen sin datos hasta que exista
/// un sistema de estadísticas reales del jugador.
class _StatisticsRow extends StatelessWidget {
  const _StatisticsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _StatisticCard(label: 'Puntos', icon: Icons.diamond_outlined),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _StatisticCard(
            label: 'Racha',
            icon: Icons.local_fire_department_outlined,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _StatisticCard(
            label: 'Ranking',
            icon: Icons.emoji_events_outlined,
          ),
        ),
      ],
    );
  }
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(28),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Colors.white.withAlpha(65)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFFFD76C), size: 25),
          const SizedBox(width: 5),

          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '—',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: QuizPalette.foregroundMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// TARJETA PROTAGONISTA DE QUIZ10
// ------------------------------------------------------------

class _Quiz10Hero extends StatelessWidget {
  const _Quiz10Hero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('quizai-hero'),

      decoration: BoxDecoration(
        gradient: QuizPalette.heroGradient,

        borderRadius: BorderRadius.circular(30),

        border: Border.all(color: Colors.white.withAlpha(235), width: 3),

        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB889FF).withAlpha(110),
            blurRadius: 18,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withAlpha(45),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),

        child: Material(
          color: Colors.transparent,

          child: InkWell(
            onTap: onTap,

            child: Stack(
              children: [
                const Positioned(
                  right: -15,
                  top: 30,
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: 175,
                    color: Color(0x335F24CC),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 8,
                        ),

                        decoration: BoxDecoration(
                          color: const Color(0xFF382078),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withAlpha(70)),
                        ),

                        child: const Text(
                          '✨ Modalidad disponible',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        '🎲 Quiz10',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 43,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                          height: 1.1,
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        '10 preguntas, un gran reto',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 30),

                      Container(
                        height: 56,

                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                        ),

                        padding: const EdgeInsets.only(left: 22, right: 5),

                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Jugar ahora',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: QuizPalette.background,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),

                            Container(
                              width: 46,
                              height: 46,

                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: QuizPalette.primary,
                              ),

                              child: const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ],
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
    );
  }
}
