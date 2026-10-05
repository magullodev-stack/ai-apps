import 'package:flutter/material.dart';

import '../app_theme.dart';

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
        borderRadius: BorderRadius.circular(QuizRadii.card),
        border: Border.all(
          color: QuizPalette.foreground.withAlpha(212),
          width: 1.8,
        ),
        boxShadow: QuizShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(QuizRadii.card - 2),
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      QuizSpacing.lg,
                      QuizSpacing.xs,
                      96,
                      QuizSpacing.xs,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: QuizTypography.cardTitle.copyWith(
                            color: QuizPalette.foreground,
                            shadows: const [
                              Shadow(
                                color: Color(0xAA000000),
                                offset: Offset(0, 1.5),
                                blurRadius: 3,
                              ),
                              Shadow(color: Color(0x66000000), blurRadius: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: QuizSpacing.xs),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: QuizTypography.body.copyWith(
                            color: QuizPalette.foreground,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                            shadows: const [
                              Shadow(
                                color: Color(0xAA000000),
                                offset: Offset(0, 1),
                                blurRadius: 2.5,
                              ),
                              Shadow(color: Color(0x66000000), blurRadius: 7),
                            ],
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
