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
        border: Border.all(color: Colors.white.withAlpha(212), width: 1.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(34),
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 104, 8),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 184),
                      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(26),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withAlpha(44),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 33,
                              fontWeight: FontWeight.w900,
                              height: 0.98,
                              letterSpacing: -0.8,
                              shadows: [
                                Shadow(
                                  color: Color(0xAA000000),
                                  offset: Offset(0, 2),
                                  blurRadius: 5,
                                ),
                                Shadow(
                                  color: Color(0x66000000),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                              shadows: [
                                Shadow(
                                  color: Color(0xAA000000),
                                  offset: Offset(0, 1),
                                  blurRadius: 4,
                                ),
                                Shadow(
                                  color: Color(0x66000000),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
