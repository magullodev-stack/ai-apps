import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import 'muondia_settings.dart';
import 'settings_components.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final MuondiaSettings settings;
  final ValueChanged<MuondiaSettings> onChanged;

  void _showUnavailable(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      animationStyle: AnimationStyle(
        duration: MuondiaDurations.normal,
        reverseDuration: MuondiaDurations.fast,
        curve: MuondiaDurations.curve,
      ),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(MuondiaSpacing.xl),
        child: Container(
          decoration: BoxDecoration(
            color: MuondiaPalette.surface,
            borderRadius: BorderRadius.circular(MuondiaRadii.card),
            boxShadow: MuondiaShadows.card,
          ),
          padding: const EdgeInsets.all(MuondiaSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                message,
                style: MuondiaTypography.body.copyWith(color: MuondiaPalette.ink),
              ),
              const SizedBox(height: MuondiaSpacing.xl),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: MuondiaPalette.primary,
                    textStyle: MuondiaTypography.label,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MuondiaRadii.small),
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
      backgroundColor: MuondiaPalette.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: MuondiaPalette.backgroundGradient,
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: MuondiaLayout.maxWidth),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MuondiaLayout.horizontalPadding,
                      vertical: MuondiaSpacing.lg,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Volver',
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: MuondiaPalette.foreground,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: MuondiaSpacing.sm),
                        Expanded(
                          child: Text(
                            'Ajustes',
                            style: MuondiaTypography.screenTitle.copyWith(
                              color: MuondiaPalette.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        MuondiaLayout.horizontalPadding,
                        MuondiaSpacing.sm,
                        MuondiaLayout.horizontalPadding,
                        MuondiaSpacing.xxl,
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
                                accent: MuondiaPalette.primary,
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
                                accent: MuondiaPalette.info,
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
                                accent: MuondiaPalette.warning,
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
                          const SizedBox(height: MuondiaSpacing.xxl),
                          SettingsSectionCard(
                            title: 'Información',
                            children: [
                              SettingsInfoRow(
                                title: 'Privacidad',
                                icon: Icons.privacy_tip_outlined,
                                accent: MuondiaPalette.error,
                                onTap: () => _showUnavailable(
                                  context,
                                  'El contenido de privacidad todavía no está disponible.',
                                ),
                              ),
                              SettingsInfoRow(
                                title: 'Términos de uso',
                                icon: Icons.description_outlined,
                                accent: MuondiaPalette.primary,
                                onTap: () => _showUnavailable(
                                  context,
                                  'Los términos de uso todavía no están disponibles.',
                                ),
                              ),
                              const SettingsInfoRow(
                                title: 'Versión',
                                icon: Icons.info_outline_rounded,
                                accent: MuondiaPalette.info,
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
