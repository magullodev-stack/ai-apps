import 'package:flutter/material.dart';

import '../../modes/quiz10/quiz_generation.dart';
import '../../modes/quiz10/quiz_page.dart';
import 'modalidad_card.dart';

class ModalidadesPage extends StatelessWidget {
  const ModalidadesPage({super.key, this.generator});

  final QuizGenerator? generator;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ModalidadCard(
            title: '🎲 Quiz10',
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => QuizPage(generator: generator)),
            ),
          ),
          const ModalidadCard(title: '🏆 Sala'),
          const ModalidadCard(title: '⚔️ 1vs1'),
          const ModalidadCard(title: '📚 Estudio'),
        ],
      ),
    ),
  );
}
