import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/app/app_shell.dart';
import 'package:quizai/app/app_theme.dart';
import 'package:quizai/app/settings/quiz_settings.dart';
import 'package:quizai/app/settings/settings_components.dart';
import 'package:quizai/app/settings/settings_page.dart';

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Ajustes'));
  await tester.pumpAndSettle();
}

Finder preference(String title) => find.byWidgetPredicate(
  (widget) => widget is SettingsPreferenceRow && widget.title == title,
);

void expectPreferences(WidgetTester tester, List<bool> values) {
  for (var i = 0; i < values.length; i++) {
    expect(
      tester
          .widget<SettingsPreferenceRow>(
            find.byType(SettingsPreferenceRow).at(i),
          )
          .value,
      values[i],
    );
  }
}

void main() {
  test(
    'cambiar una preferencia conserva las otras y los valores iniciales',
    () {
      const initial = QuizSettings();
      final updated = initial.copyWith(soundsEnabled: false);
      expect(initial.soundsEnabled, isTrue);
      expect(initial.vibrationEnabled, isTrue);
      expect(initial.reduceAnimations, isFalse);
      expect(updated.soundsEnabled, isFalse);
      expect(updated.vibrationEnabled, isTrue);
      expect(updated.reduceAnimations, isFalse);
    },
  );

  testWidgets(
    'filas, iconos y switches alternan una sola vez y conservan el estado de sesión',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(theme: quizAITheme, home: const AppShell()),
      );
      await openSettings(tester);
      expectPreferences(tester, [true, true, false]);
      expect(
        tester
            .getSemantics(preference('Sonidos'))
            .flagsCollection
            .isToggled
            .toBoolOrNull(),
        isTrue,
      );
      expect(
        tester
            .getSemantics(preference('Sonidos'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );

      // El texto, el icono y el extremo del switch comparten una sola acción.
      await tester.tap(find.text('Efectos de sonido durante las partidas.'));
      await tester.pumpAndSettle();
      expectPreferences(tester, [false, true, false]);
      expect(
        tester
            .getSemantics(preference('Sonidos'))
            .flagsCollection
            .isToggled
            .toBoolOrNull(),
        isFalse,
      );
      await tester.tap(find.byIcon(Icons.vibration_rounded));
      await tester.pumpAndSettle();
      final row = tester.getRect(preference('Reducir animaciones'));
      await tester.tapAt(Offset(row.right - 32, row.center.dy));
      await tester.pumpAndSettle();
      expectPreferences(tester, [false, false, true]);

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quizai-nav-perfil')));
      await tester.pumpAndSettle();
      await openSettings(tester);
      expectPreferences(tester, [false, false, true]);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('Perfil'), findsNWidgets(2));

      // Una nueva sesión de AppShell vuelve a los valores iniciales.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(theme: quizAITheme, home: const AppShell()),
      );
      await openSettings(tester);
      expectPreferences(tester, [true, true, false]);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Información muestra únicamente avisos provisionales y Versión no navega',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: quizAITheme, home: const AppShell()),
      );
      await openSettings(tester);
      for (final entry in {
        'Privacidad': 'El contenido de privacidad todavía no está disponible.',
        'Términos de uso': 'Los términos de uso todavía no están disponibles.',
      }.entries) {
        await tester.ensureVisible(find.text(entry.key));
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        final dialogTexts = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(Dialog),
                matching: find.byType(Text),
              ),
            )
            .map((text) => text.data)
            .toList();
        expect(dialogTexts, [entry.value, 'Cerrar']);
        await tester.tap(find.text('Cerrar'));
        await tester.pumpAndSettle();
      }
      final version = find.byWidgetPredicate(
        (widget) => widget is SettingsInfoRow && widget.title == 'Versión',
      );
      await tester.ensureVisible(version);
      expect(
        find.descendant(of: version, matching: find.text('1.0.0')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: version,
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: version, matching: find.byType(InkWell)),
        findsNothing,
      );
      await tester.tap(find.text('Versión'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 480), const Size(900, 1100)]) {
    testWidgets('Ajustes permite desplazamiento y texto grande a $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(2),
            ),
            child: SettingsPage(
              settings: const QuizSettings(),
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.byType(SettingsSectionCard), findsNWidgets(2));
      await tester.ensureVisible(find.text('Versión'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(SettingsSectionCard).first).width,
        lessThanOrEqualTo(640),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
