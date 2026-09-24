import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Tarjeta de una modalidad secundaria de QuizAI.
///
/// La imagen es decorativa. El título, el subtítulo y el estado
/// de disponibilidad son componentes reales de Flutter.
class ModalidadCard extends StatelessWidget {
  const ModalidadCard({
    super.key,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.height,
    this.onTap,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imagePath;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('quizai-card-$id'),
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Colors.white.withAlpha(210), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  imagePath,
                  key: Key('quizai-image-$id'),
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  excludeFromSemantics: true,
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 92, 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: QuizPalette.ink,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: QuizPalette.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (onTap == null)
                        const Text(
                          'No disponible',
                          maxLines: 1,
                          style: TextStyle(
                            color: Color(0xFF604F72),
                            fontSize: 10,
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
