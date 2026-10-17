import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reserva las franjas nativas superior e inferior en todas las rutas de
/// Muondia, con bandas negras como Auth y sin duplicar SafeArea interiores.
class MuondiaSystemSafeFrame extends StatelessWidget {
  const MuondiaSystemSafeFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: ColoredBox(
        color: Colors.black,
        child: SafeArea(
          top: true,
          bottom: true,
          child: child,
        ),
      ),
    );
  }
}
