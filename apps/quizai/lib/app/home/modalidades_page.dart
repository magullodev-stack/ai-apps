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
    return LayoutBuilder(
      builder: (context, constraints) {
        const baseHeroHeight = 202.0;
        const baseCardHeight = 88.0;
        const baseGap = 8.0;

        const verticalPadding = 16.0;

        const totalBaseHeight =
            baseHeroHeight + (baseCardHeight * 3) + (baseGap * 3);

        final availableHeight = constraints.maxHeight - verticalPadding;

        // Mantener Quiz10 proporcionalmente más grande.
        // En pantallas pequeñas se reduce todo el conjunto.
        // Si la pantalla es demasiado baja, se conserva un
        // tamaño mínimo legible y el desplazamiento queda
        // disponible únicamente como alternativa.
        final scale = (availableHeight / totalBaseHeight)
            .clamp(0.84, 1.0)
            .toDouble();

        final heroHeight = baseHeroHeight * scale;
        final cardHeight = baseCardHeight * scale;
        final gap = baseGap * scale;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              key: const Key('quizai-home-scroll'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Quiz10Hero(
                    height: heroHeight,
                    onTap: () => _openQuiz10(context),
                  ),

                  SizedBox(height: gap),

                  ModalidadCard(
                    id: 'sala',
                    title: 'Sala',
                    subtitle: 'Juega con amigos',
                    imagePath: 'assets/modalidades/sala.png',
                    height: cardHeight,
                  ),

                  SizedBox(height: gap),

                  ModalidadCard(
                    id: '1vs1',
                    title: '1vs1',
                    subtitle: 'Reta a otro jugador',
                    imagePath: 'assets/modalidades/1vs1.png',
                    height: cardHeight,
                  ),

                  SizedBox(height: gap),

                  ModalidadCard(
                    id: 'estudio',
                    title: 'Estudio',
                    subtitle: 'Aprende a tu ritmo',
                    imagePath: 'assets/modalidades/estudio.png',
                    height: cardHeight,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Tarjeta protagonista.
///
/// El fondo es el PNG rojo de Quiz10.
/// El texto y el botón siguen siendo componentes Flutter.
/// Toda la tarjeta conserva el acceso a la partida existente.
class _Quiz10Hero extends StatelessWidget {
  const _Quiz10Hero({required this.height, required this.onTap});

  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('quizai-hero'),
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withAlpha(235), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/modalidades/quiz10.png',
                  key: const Key('quizai-image-quiz10'),
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  excludeFromSemantics: true,
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8D123B).withAlpha(200),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Disponible',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Quiz10',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          height: 1.05,
                          shadows: [
                            Shadow(color: Color(0x55000000), blurRadius: 5),
                          ],
                        ),
                      ),

                      const SizedBox(height: 4),

                      const Text(
                        '10 preguntas,\nun gran reto',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          shadows: [
                            Shadow(color: Color(0x55000000), blurRadius: 5),
                          ],
                        ),
                      ),

                      const Spacer(),

                      Container(
                        height: 40,
                        width: 154,
                        padding: const EdgeInsets.only(left: 13, right: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Jugar ahora',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: QuizPalette.background,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: QuizPalette.primary,
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white,
                                size: 25,
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
