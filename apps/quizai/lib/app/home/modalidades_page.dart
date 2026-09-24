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
        const minTopReserve = 22.0;
        const desiredHeroHeight = 250.0;
        const desiredCardHeight = 78.0;
        const desiredGap = 8.0;
        const outerPadding = 6.0;

        const baseContentHeight =
            minTopReserve +
            desiredHeroHeight +
            (desiredCardHeight * 3) +
            (desiredGap * 3);

        final viewportHeight = constraints.maxHeight - (outerPadding * 2);
        final scale = (viewportHeight / baseContentHeight)
            .clamp(0.90, 1.0)
            .toDouble();

        final heroHeight = desiredHeroHeight * scale;
        final cardHeight = desiredCardHeight * scale;
        final gap = desiredGap * scale;

        final scaledContentHeight =
            minTopReserve + heroHeight + (cardHeight * 3) + (gap * 3);

        final needsScroll = scaledContentHeight > viewportHeight;

        Widget buildCardsColumn({required bool pinToBottom}) {
          final children = <Widget>[
            const SizedBox(
              key: Key('quizai-top-reserved-space'),
              height: minTopReserve,
            ),
          ];

          if (pinToBottom) {
            children.add(const Spacer());
          }

          children.addAll([
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
          ]);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        }

        final body = needsScroll
            ? SingleChildScrollView(
                key: const Key('quizai-home-scroll'),
                padding: const EdgeInsets.fromLTRB(
                  14,
                  outerPadding,
                  14,
                  outerPadding,
                ),
                child: buildCardsColumn(pinToBottom: false),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(
                  14,
                  outerPadding,
                  14,
                  outerPadding,
                ),
                child: SizedBox(
                  height: viewportHeight,
                  child: buildCardsColumn(pinToBottom: true),
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
            color: Colors.black.withAlpha(40),
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 94, 14),
                  child: Stack(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Quiz10',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                            height: 0.95,
                            shadows: [
                              Shadow(
                                color: Color(0xB3000000),
                                offset: Offset(0, 2),
                                blurRadius: 4,
                              ),
                              Shadow(color: Color(0x66000000), blurRadius: 10),
                            ],
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          height: 48,
                          width: 178,
                          padding: const EdgeInsets.only(left: 15, right: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(27),
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
                                radius: 17,
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
