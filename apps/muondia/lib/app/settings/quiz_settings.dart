/// Preferencias de sesión de Muondia, sin persistencia ni consumidores de audio
/// o vibración todavía.
final class QuizSettings {
  const QuizSettings({
    this.soundsEnabled = true,
    this.vibrationEnabled = true,
    this.reduceAnimations = false,
  });

  final bool soundsEnabled;
  final bool vibrationEnabled;
  final bool reduceAnimations;

  QuizSettings copyWith({
    bool? soundsEnabled,
    bool? vibrationEnabled,
    bool? reduceAnimations,
  }) => QuizSettings(
    soundsEnabled: soundsEnabled ?? this.soundsEnabled,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    reduceAnimations: reduceAnimations ?? this.reduceAnimations,
  );
}
