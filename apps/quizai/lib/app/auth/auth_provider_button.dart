import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';

enum AuthProvider { google, apple, email }

class AuthProviderButton extends StatelessWidget {
  const AuthProviderButton({
    super.key,
    required this.provider,
    required this.onPressed,
  });

  final AuthProvider provider;
  final VoidCallback onPressed;

  String get _label => switch (provider) {
    AuthProvider.google => 'Continuar con Google',
    AuthProvider.apple => 'Continuar con Apple',
    AuthProvider.email => 'Continuar con email',
  };

  Widget _icon(double size) => switch (provider) {
    AuthProvider.google => CustomPaint(
      size: Size.square(size),
      painter: const _GoogleGIconPainter(),
    ),
    AuthProvider.apple => Icon(
      Icons.apple,
      size: size,
      color: Colors.white,
    ),
    AuthProvider.email => Icon(
      Icons.mail_outline_rounded,
      size: size,
      color: Colors.white,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              final iconSize = height * 0.53;

              return CustomPaint(
                painter: const _NeonButtonPainter(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: height * 0.46),
                  child: Row(
                    children: [
                      SizedBox(
                        width: height * 0.94,
                        child: Center(child: _icon(iconSize)),
                      ),
                      SizedBox(width: height * 0.16),
                      Expanded(
                        child: Text(
                          _label,
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontFamily: QuizTypography.family,
                            color: Colors.white,
                            fontSize: height * 0.34,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.25,
                            shadows: const [
                              Shadow(
                                color: Color(0x805F46FF),
                                blurRadius: 7,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NeonButtonPainter extends CustomPainter {
  const _NeonButtonPainter();

  static const _borderGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF00B7FF),
      Color(0xFF5A65FF),
      Color(0xFFFF20FB),
    ],
    stops: [0, 0.46, 1],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.height / 2);
    final outer = RRect.fromRectAndRadius(rect.deflate(2.5), radius);

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF19182B),
          Color(0xFF0A0912),
        ],
      ).createShader(rect);
    canvas.drawRRect(outer, fill);

    final glowWide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..shader = _borderGradient.createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    canvas.drawRRect(outer, glowWide);

    final glowTight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = _borderGradient.createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawRRect(outer, glowTight);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = _borderGradient.createShader(rect);
    canvas.drawRRect(outer, border);

    final innerRect = rect.deflate(size.height * 0.075);
    final inner = RRect.fromRectAndRadius(
      innerRect,
      Radius.circular(innerRect.height / 2),
    );
    final innerHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0x66FFFFFF);
    canvas.drawRRect(inner, innerHighlight);
  }

  @override
  bool shouldRepaint(covariant _NeonButtonPainter oldDelegate) => false;
}

class _GoogleGIconPainter extends CustomPainter {
  const _GoogleGIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.175;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    Paint arc(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      rect,
      math.pi * 1.05,
      math.pi * 0.57,
      false,
      arc(const Color(0xFFEA4335)),
    );
    canvas.drawArc(
      rect,
      math.pi * 0.62,
      math.pi * 0.43,
      false,
      arc(const Color(0xFFFBBC05)),
    );
    canvas.drawArc(
      rect,
      math.pi * 0.18,
      math.pi * 0.52,
      false,
      arc(const Color(0xFF34A853)),
    );
    canvas.drawArc(
      rect,
      -math.pi * 0.28,
      math.pi * 0.55,
      false,
      arc(const Color(0xFF4285F4)),
    );

    final blue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(size.width - stroke * 0.22, center.dy),
      blue,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleGIconPainter oldDelegate) => false;
}
