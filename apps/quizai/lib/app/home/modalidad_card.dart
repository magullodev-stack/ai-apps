import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Presentación reutilizable de las modalidades secundarias de QuizAI.
///
/// La disponibilidad sigue dependiendo de la acción recibida.
class ModalidadCard extends StatelessWidget {
  const ModalidadCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 114,
      margin: const EdgeInsets.only(bottom: 12),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withAlpha(210), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            enabled: onTap != null,
            onTap: onTap,

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),

            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(115),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: QuizPalette.ink, size: 28),
            ),

            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: QuizPalette.ink,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),

            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: QuizPalette.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (onTap == null)
                  const Text(
                    'No disponible',
                    style: TextStyle(color: Color(0xFF604F72), fontSize: 11),
                  ),
              ],
            ),

            trailing: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(155),
                border: Border.all(color: Colors.white),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: QuizPalette.ink,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
