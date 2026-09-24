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
        // Dimensiones mínimas y máximas de la portada.
        // Se utiliza el espacio disponible sin cortar tarjetas.

        const minTotalHeight = 478.0;
        const maxTotalHeight = 624.0;

        final viewportHeight = constraints.maxHeight;

        final fit =
            ((viewportHeight - minTotalHeight) /
                    (maxTotalHeight - minTotalHeight))
                .clamp(0.0, 1.0)
                .toDouble();

        // Espacio reservado para futuras funciones del usuario.
        final topReserve = 10.0 + (40.0 * fit);

        // Quiz10 mantiene mayor protagonismo.
        final heroHeight = 162.0 + (32.0 * fit);

        // Sala, 1vs1 y Estudio tienen el mismo tamaño.
        final cardHeight = 90.0 + (18.0 * fit);

        final gap = 6.0 + (4.0 * fit);

        final outerVerticalPadding = 6.0 + (2.0 * fit);

        // Solo permitir desplazamiento cuando la altura
        // física disponible sea insuficiente para los mínimos.
        final needsScroll = viewportHeight < minTotalHeight;

        Widget content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              key: const Key('quizai-top-reserved-space'),
              height: topReserve,
            ),
            _Quiz10Hero(height: heroHeight, onTap: () => _openQuiz10(context)),
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
        );

        final body = needsScroll
            ? SingleChildScrollView(
                key: const Key('quizai-home-scroll'),
                padding: EdgeInsets.fromLTRB(
                  14,
                  outerVerticalPadding,
                  14,
                  outerVerticalPadding,
                ),
                child: content,
              )
            : Padding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  outerVerticalPadding,
                  14,
                  outerVerticalPadding,
                ),
                child: SizedBox(
                  height: constraints.maxHeight - (outerVerticalPadding * 2),
                  child: content,
                ),
              );

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: body,
          ),
        );
      },
    );
  }
}

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
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withAlpha(235), width: 2.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(44),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
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
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      const Text(
                        'Quiz10',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 45,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                          height: 0.94,
                          shadows: [
                            Shadow(color: Color(0x66000000), blurRadius: 8),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 46,
                        width: 176,
                        padding: const EdgeInsets.only(left: 14, right: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(18),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Jugar ahora',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: QuizPalette.background,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: QuizPalette.primary,
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white,
                                size: 24,
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
