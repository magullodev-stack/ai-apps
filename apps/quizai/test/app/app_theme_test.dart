import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/app/app_theme.dart';

void main() {
  test(
    'la paleta expone los colores canónicos de marca, contenido y estado',
    () {
      final contract = <(Color, int)>[
        (QuizPalette.background, 0xFF38149B),
        (QuizPalette.backgroundLight, 0xFF7838F2),
        (QuizPalette.backgroundDark, 0xFF29116F),
        (QuizPalette.primary, 0xFF6931DD),
        (QuizPalette.primaryLight, 0xFFAB73FF),
        (QuizPalette.foreground, 0xFFFFFFFF),
        (QuizPalette.foregroundMuted, 0xFFD8CBFF),
        (QuizPalette.ink, 0xFF21163B),
        (QuizPalette.surface, 0xFFF7F5FB),
        (QuizPalette.surfaceElevated, 0xFFFFFFFF),
        (QuizPalette.inkMuted, 0xFF625B74),
        (QuizPalette.divider, 0xFFDED8EA),
        (QuizPalette.success, 0xFF16C77A),
        (QuizPalette.error, 0xFFFF4D67),
        (QuizPalette.warning, 0xFFFFC83D),
        (QuizPalette.info, 0xFF4DB9ED),
      ];
      for (final (color, value) in contract) {
        expect(color, Color(value));
      }
      expect(QuizPalette.accent, QuizPalette.warning);
    },
  );

  test('espacio, radios, layout y movimiento mantienen el contrato v1', () {
    expect(
      [
        QuizSpacing.xs,
        QuizSpacing.sm,
        QuizSpacing.md,
        QuizSpacing.lg,
        QuizSpacing.xl,
        QuizSpacing.xxl,
      ],
      [4, 8, 12, 16, 24, 32],
    );
    expect(
      [QuizRadii.small, QuizRadii.medium, QuizRadii.card, QuizRadii.hero],
      [12, 18, 24, 28],
    );
    expect(QuizRadii.pill, greaterThanOrEqualTo(QuizLayout.maxWidth / 2));
    expect(QuizLayout.maxWidth, 640);
    expect(QuizLayout.horizontalPadding, 14);
    expect(QuizDurations.fast, const Duration(milliseconds: 180));
    expect(QuizDurations.normal, const Duration(milliseconds: 240));
    expect(QuizDurations.curve, Curves.easeOutCubic);
  });

  test('Nunito conserva una jerarquía y se aplica a todo el tema', () {
    expect(QuizTypography.family, 'Nunito');
    final styles = [
      QuizTypography.brand,
      QuizTypography.screenTitle,
      QuizTypography.sectionTitle,
      QuizTypography.cardTitle,
      QuizTypography.body,
      QuizTypography.bodySecondary,
      QuizTypography.label,
      QuizTypography.caption,
    ];
    for (final style in styles) {
      expect(style.fontFamily, 'Nunito');
    }
    expect(
      QuizTypography.brand.fontSize,
      greaterThan(QuizTypography.screenTitle.fontSize!),
    );
    expect(QuizTypography.screenTitle.fontWeight, FontWeight.w900);
    expect(
      QuizTypography.bodySecondary.fontSize,
      lessThan(QuizTypography.body.fontSize!),
    );
    for (final theme in [quizAITheme.textTheme, quizAITheme.primaryTextTheme]) {
      for (final style in [
        theme.displayLarge,
        theme.displayMedium,
        theme.displaySmall,
        theme.headlineLarge,
        theme.headlineMedium,
        theme.headlineSmall,
        theme.titleLarge,
        theme.titleMedium,
        theme.titleSmall,
        theme.bodyLarge,
        theme.bodyMedium,
        theme.bodySmall,
        theme.labelLarge,
        theme.labelMedium,
        theme.labelSmall,
      ]) {
        expect(style!.fontFamily, 'Nunito');
      }
    }
  });

  test(
    'el tema Material mantiene contenido legible sobre superficies claras',
    () {
      final scheme = quizAITheme.colorScheme;
      expect(scheme.brightness, Brightness.light);
      expect(quizAITheme.scaffoldBackgroundColor, QuizPalette.surface);
      expect(scheme.primary, QuizPalette.primary);
      for (final ink in [
        scheme.onSurface,
        scheme.onSurfaceVariant,
        scheme.error,
      ]) {
        final contrast =
            (scheme.surface.computeLuminance() + 0.05) /
            (ink.computeLuminance() + 0.05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      }
    },
  );
}
