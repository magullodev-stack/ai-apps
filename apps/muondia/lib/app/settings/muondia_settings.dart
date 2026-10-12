/// Preferencias de sesión de Muondia, sin persistencia ni consumidores de audio
/// o vibración todavía.
final class MuondiaSettings {
  const MuondiaSettings({
    this.soundsEnabled = true,
    this.vibrationEnabled = true,
    this.reduceAnimations = false,
  });

  final bool soundsEnabled;
  final bool vibrationEnabled;
  final bool reduceAnimations;

  MuondiaSettings copyWith({
    bool? soundsEnabled,
    bool? vibrationEnabled,
    bool? reduceAnimations,
  }) => MuondiaSettings(
    soundsEnabled: soundsEnabled ?? this.soundsEnabled,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    reduceAnimations: reduceAnimations ?? this.reduceAnimations,
  );
}
