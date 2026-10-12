import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muondia/app/app_theme.dart';

void main() {
  test(
    'la paleta expone los colores canónicos de marca, contenido y estado',
    () {
      final contract = <(Color, int)>[
        (MuondiaPalette.background, 0xFF38149B),
        (MuondiaPalette.backgroundLight, 0xFF7838F2),
        (MuondiaPalette.backgroundDark, 0xFF29116F),
        (MuondiaPalette.primary, 0xFF6931DD),
        (MuondiaPalette.primaryLight, 0xFFAB73FF),
        (MuondiaPalette.foreground, 0xFFFFFFFF),
        (MuondiaPalette.foregroundMuted, 0xFFD8CBFF),
        (MuondiaPalette.ink, 0xFF21163B),
        (MuondiaPalette.surface, 0xFFF7F5FB),
        (MuondiaPalette.surfaceElevated, 0xFFFFFFFF),
        (MuondiaPalette.inkMuted, 0xFF625B74),
        (MuondiaPalette.divider, 0xFFDED8EA),
        (MuondiaPalette.success, 0xFF16C77A),
        (MuondiaPalette.error, 0xFFFF4D67),
        (MuondiaPalette.warning, 0xFFFFC83D),
        (MuondiaPalette.info, 0xFF4DB9ED),
      ];
      for (final (color, value) in contract) {
        expect(color, Color(value));
      }
      expect(MuondiaPalette.accent, MuondiaPalette.warning);
    },
  );

  test('espacio, radios, layout y movimiento mantienen el contrato v1', () {
    expect(
      [
        MuondiaSpacing.xs,
        MuondiaSpacing.sm,
        MuondiaSpacing.md,
        MuondiaSpacing.lg,
        MuondiaSpacing.xl,
        MuondiaSpacing.xxl,
      ],
      [4, 8, 12, 16, 24, 32],
    );
    expect(
      [MuondiaRadii.small, MuondiaRadii.medium, MuondiaRadii.card, MuondiaRadii.hero],
      [12, 18, 24, 28],
    );
    expect(MuondiaRadii.pill, greaterThanOrEqualTo(MuondiaLayout.maxWidth / 2));
    expect(MuondiaLayout.maxWidth, 640);
    expect(MuondiaLayout.horizontalPadding, 12);
    expect(MuondiaDurations.fast, const Duration(milliseconds: 180));
    expect(MuondiaDurations.normal, const Duration(milliseconds: 240));
    expect(MuondiaDurations.curve, Curves.easeOutCubic);
  });

  test('Nunito conserva una jerarquía y se aplica a todo el tema', () {
    expect(MuondiaTypography.family, 'Nunito');
    final styles = [
      MuondiaTypography.brand,
      MuondiaTypography.screenTitle,
      MuondiaTypography.sectionTitle,
      MuondiaTypography.cardTitle,
      MuondiaTypography.body,
      MuondiaTypography.bodySecondary,
      MuondiaTypography.label,
      MuondiaTypography.caption,
    ];
    for (final style in styles) {
      expect(style.fontFamily, 'Nunito');
    }
    expect(
      MuondiaTypography.brand.fontSize,
      greaterThan(MuondiaTypography.screenTitle.fontSize!),
    );
    expect(MuondiaTypography.screenTitle.fontWeight, FontWeight.w900);
    expect(
      MuondiaTypography.bodySecondary.fontSize,
      lessThan(MuondiaTypography.body.fontSize!),
    );
    for (final theme in [muondiaTheme.textTheme, muondiaTheme.primaryTextTheme]) {
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
      final scheme = muondiaTheme.colorScheme;
      expect(scheme.brightness, Brightness.light);
      expect(muondiaTheme.scaffoldBackgroundColor, MuondiaPalette.surface);
      expect(scheme.primary, MuondiaPalette.primary);
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
