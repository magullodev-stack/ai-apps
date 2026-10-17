import 'production/onboarding_dimensions.dart';

/// Los PNG del test se registran con rutas literales para que el
/// Explorador de experiencias pueda identificarlos como recursos utilizados.
/// La lista de pivotes sigue definiéndose solo en onboarding_dimensions.dart;
/// esta tabla asocia cada código con el nombre real de su archivo PNG.
const Map<String, String> _pivotImageByCode = {
  'P01': 'assets/Pivotes/P01 - Arquitectura.png',
  'P02': 'assets/Pivotes/P02 - Arte.png',
  'P03': 'assets/Pivotes/P03 - Astronomía.png',
  'P04': 'assets/Pivotes/P04 - Biología.png',
  'P05': 'assets/Pivotes/P05 - Derecho.png',
  'P06': 'assets/Pivotes/P06 - Economía.png',
  'P07': 'assets/Pivotes/P07 - Filosofía.png',
  'P08': 'assets/Pivotes/P08 - Física.png',
  'P09': 'assets/Pivotes/P09 - Gastronomía.png',
  'P10': 'assets/Pivotes/P10 - Geografía.png',
  'P11': 'assets/Pivotes/P11 - Geología.png',
  'P12': 'assets/Pivotes/P12 - Historia.png',
  'P13': 'assets/Pivotes/P13 - Informática.png',
  'P14': 'assets/Pivotes/P14 - Lingüística.png',
  'P15': 'assets/Pivotes/P15 - Literatura.png',
  'P16': 'assets/Pivotes/P16 - Matemáticas.png',
  'P17': 'assets/Pivotes/P17 - Medicina.png',
  'P18': 'assets/Pivotes/P18 - Psicología.png',
  'P19': 'assets/Pivotes/P19 - Química.png',
  'P20': 'assets/Pivotes/P20 - Sociología.png',
};

/// Asociación canónica entre el pivote activo y su imagen correspondiente.
/// Únicamente la imagen del pivote de la pregunta se construye en Flutter;
/// registrar un PNG no implica que todos se muestren simultáneamente.
final Map<String, String> onboardingPivotImagePaths =
    Map<String, String>.unmodifiable({
  for (final pivot in onboardingQuizPivots)
    pivot.name: _pivotImageByCode[pivot.code]!,
});

String? onboardingPivotImageFor(String pivotName) =>
    onboardingPivotImagePaths[pivotName];
