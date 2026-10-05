import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import 'quiz_settings.dart';
import 'settings_components.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final QuizSettings settings;
  final ValueChanged<QuizSettings> onChanged;

  void _showUnavailable(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      animationStyle: AnimationStyle(
        duration: QuizDurations.normal,
        reverseDuration: QuizDurations.fast,
        curve: QuizDurations.curve,
      ),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(QuizSpacing.xl),
        child: Container(
          decoration: BoxDecoration(
            color: QuizPalette.surface,
            borderRadius: BorderRadius.circular(QuizRadii.card),
            boxShadow: QuizShadows.card,
          ),
          padding: const EdgeInsets.all(QuizSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                message,
                style: QuizTypography.body.copyWith(color: QuizPalette.ink),
              ),
              const SizedBox(height: QuizSpacing.xl),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: QuizPalette.primary,
                    textStyle: QuizTypography.label,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(QuizRadii.small),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: QuizPalette.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: QuizPalette.backgroundGradient,
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: QuizLayout.maxWidth),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: QuizLayout.horizontalPadding,
                      vertical: QuizSpacing.lg,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Volver',
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: QuizPalette.foreground,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: QuizSpacing.sm),
                        Expanded(
                          child: Text(
                            'Ajustes',
                            style: QuizTypography.screenTitle.copyWith(
                              color: QuizPalette.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        QuizLayout.horizontalPadding,
                        QuizSpacing.sm,
                        QuizLayout.horizontalPadding,
                        QuizSpacing.xxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SettingsSectionCard(
                            title: 'Experiencia',
                            children: [
                              SettingsPreferenceRow(
                                title: 'Sonidos',
                                subtitle:
                                    'Efectos de sonido durante las partidas.',
                                icon: Icons.volume_up_rounded,
                                accent: QuizPalette.primary,
                                value: settings.soundsEnabled,
                                onToggle: () => onChanged(
                                  settings.copyWith(
                                    soundsEnabled: !settings.soundsEnabled,
                                  ),
                                ),
                              ),
                              SettingsPreferenceRow(
                                title: 'Vibración',
                                subtitle: 'Respuesta háptica al jugar.',
                                icon: Icons.vibration_rounded,
                                accent: QuizPalette.info,
                                value: settings.vibrationEnabled,
                                onToggle: () => onChanged(
                                  settings.copyWith(
                                    vibrationEnabled:
                                        !settings.vibrationEnabled,
                                  ),
                                ),
                              ),
                              SettingsPreferenceRow(
                                title: 'Reducir animaciones',
                                subtitle:
                                    'Reduce movimientos y efectos visuales.',
                                icon: Icons.motion_photos_off_rounded,
                                accent: QuizPalette.warning,
                                value: settings.reduceAnimations,
                                onToggle: () => onChanged(
                                  settings.copyWith(
                                    reduceAnimations:
                                        !settings.reduceAnimations,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: QuizSpacing.xxl),
                          SettingsSectionCard(
                            title: 'Información',
                            children: [
                              SettingsInfoRow(
                                title: 'Privacidad',
                                icon: Icons.privacy_tip_outlined,
                                accent: QuizPalette.error,
                                onTap: () => _showUnavailable(
                                  context,
                                  'El contenido de privacidad todavía no está disponible.',
                                ),
                              ),
                              SettingsInfoRow(
                                title: 'Términos de uso',
                                icon: Icons.description_outlined,
                                accent: QuizPalette.primary,
                                onTap: () => _showUnavailable(
                                  context,
                                  'Los términos de uso todavía no están disponibles.',
                                ),
                              ),
                              const SettingsInfoRow(
                                title: 'Versión',
                                icon: Icons.info_outline_rounded,
                                accent: QuizPalette.info,
                                value: '1.0.0',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
