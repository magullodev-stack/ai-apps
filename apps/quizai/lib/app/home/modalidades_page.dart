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
        const baseTopReserve = 56.0;
        const baseHeroHeight = 190.0;
        const baseCardHeight = 90.0;
        const baseGap = 10.0;
        const outerVerticalPadding = 10.0;

        const baseTotalHeight =
            baseTopReserve +
            baseHeroHeight +
            (baseCardHeight * 3) +
            (baseGap * 4);

        final availableHeight =
            constraints.maxHeight - (outerVerticalPadding * 2);
        final scale = (availableHeight / baseTotalHeight)
            .clamp(0.92, 1.08)
            .toDouble();

        final topReserve = baseTopReserve * scale;
        final heroHeight = baseHeroHeight * scale;
        final cardHeight = baseCardHeight * scale;
        final gap = baseGap * scale;

        final minimumHeight = baseTotalHeight * 0.92;
        final needsScroll = availableHeight < minimumHeight;

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
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: content,
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
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
                          fontSize: 39,
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
                        height: 42,
                        width: 162,
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
                                  fontSize: 15,
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
