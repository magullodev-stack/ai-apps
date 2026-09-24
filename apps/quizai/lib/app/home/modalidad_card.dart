import 'package:flutter/material.dart';

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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(210), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
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
                IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0x99000000),
                          Color(0x4D000000),
                          Color(0x0D000000),
                          Color(0x00000000),
                        ],
                        stops: [0.0, 0.34, 0.58, 0.82],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 112, 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 31,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.7,
                          height: 0.98,
                          shadows: [
                            Shadow(
                              color: Color(0xCC000000),
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                            Shadow(color: Color(0x88000000), blurRadius: 10),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFF7F7FF),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          shadows: [
                            Shadow(
                              color: Color(0xCC000000),
                              offset: Offset(0, 1),
                              blurRadius: 4,
                            ),
                            Shadow(color: Color(0x88000000), blurRadius: 9),
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
