import 'production/onboarding_dimensions.dart';

/// Asociación canónica entre el pivote activo de una pregunta de bienvenida
/// y su ilustración original, sin decidir todavía cómo se presenta en la UI.
/// Los nombres proceden del mismo catálogo que alimenta el generador.
/// Las rutas respetan la P mayúscula de assets/Pivotes/ en Android.
final Map<String, String> onboardingPivotImagePaths =
    Map<String, String>.unmodifiable({
  for (final pivot in onboardingQuizPivots)
    pivot.name: 'assets/Pivotes/${pivot.code} - ${pivot.name}.png',
});

/// Si el pivote no está registrado, no inventa una ilustración.
String? onboardingPivotImageFor(String pivotName) =>
    onboardingPivotImagePaths[pivotName];
