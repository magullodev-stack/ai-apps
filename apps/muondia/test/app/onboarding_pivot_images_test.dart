import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muondia/app/onboarding/pivot_images.dart';
import 'package:muondia/app/onboarding/production/onboarding_dimensions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Los 20 pivotes canónicos tienen un PNG distinto y empaquetado', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final bundledAssets = manifest.listAssets().toSet();

    expect(onboardingQuizPivots.length, 20);
    expect(onboardingPivotImagePaths.length, 20);
    expect(onboardingPivotImagePaths.values.toSet().length, 20);

    for (final pivot in onboardingQuizPivots) {
      final expectedPath =
          'assets/Pivotes/${pivot.code} - ${pivot.name}.png';
      expect(onboardingPivotImageFor(pivot.name), expectedPath);
      expect(bundledAssets, contains(expectedPath),
          reason: 'Flutter debe empaquetar el PNG de ${pivot.name}');
    }
  });

  test('Cada cambio de pivote resuelve su recurso, sin reutilizar el anterior', () {
    expect(onboardingPivotImageFor('Física'),
        'assets/Pivotes/P08 - Física.png');
    expect(onboardingPivotImageFor('Astronomía'),
        'assets/Pivotes/P03 - Astronomía.png');
    expect(onboardingPivotImageFor('Vista previa'), isNull);
    expect(onboardingPivotImageFor('Desconocido'), isNull);
  });
}
