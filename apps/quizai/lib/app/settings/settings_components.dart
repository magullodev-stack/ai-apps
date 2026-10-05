import 'package:flutter/material.dart';

import '../app_theme.dart';

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          style: QuizTypography.sectionTitle.copyWith(
            color: QuizPalette.foreground,
          ),
        ),
      ),
      const SizedBox(height: QuizSpacing.md),
      Container(
        decoration: BoxDecoration(
          color: QuizPalette.surface,
          borderRadius: BorderRadius.circular(QuizRadii.card),
          boxShadow: QuizShadows.card,
        ),
        child: Material(
          color: QuizPalette.surface,
          borderRadius: BorderRadius.circular(QuizRadii.card),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    indent: QuizSpacing.lg,
                    endIndent: QuizSpacing.lg,
                    color: QuizPalette.divider,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

class SettingsPreferenceRow extends StatelessWidget {
  const SettingsPreferenceRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.value,
    required this.onToggle,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool value;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$title. $subtitle',
    toggled: value,
    enabled: true,
    onTap: onToggle,
    child: ExcludeSemantics(
      child: _SettingsRow(
        title: title,
        subtitle: subtitle,
        icon: icon,
        accent: accent,
        onTap: onToggle,
        trailing: _SettingsSwitch(value: value),
      ),
    ),
  );
}

class SettingsInfoRow extends StatelessWidget {
  const SettingsInfoRow({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    this.value,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _SettingsRow(
    title: title,
    icon: icon,
    accent: accent,
    onTap: onTap,
    trailing: value != null
        ? Text(value!, style: QuizTypography.bodySecondary)
        : const Icon(Icons.chevron_right_rounded, color: QuizPalette.inkMuted),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.icon,
    required this.accent,
    required this.trailing,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(QuizSpacing.lg),
      child: Row(
        children: [
          _SettingsIcon(icon: icon, accent: accent),
          const SizedBox(width: QuizSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: QuizTypography.label.copyWith(color: QuizPalette.ink),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: QuizSpacing.xs),
                  Text(subtitle!, style: QuizTypography.bodySecondary),
                ],
              ],
            ),
          ),
          const SizedBox(width: QuizSpacing.md),
          trailing,
        ],
      ),
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: QuizSpacing.xxl + QuizSpacing.lg,
      height: QuizSpacing.xxl + QuizSpacing.lg,
      decoration: BoxDecoration(
        color: accent.withAlpha(32),
        borderRadius: BorderRadius.circular(QuizRadii.medium),
      ),
      child: Icon(
        icon,
        size: QuizSpacing.xl,
        color: accent == QuizPalette.warning ? QuizPalette.ink : accent,
      ),
    ),
  );
}

/// El control visual comparte el área táctil y la semántica de toda la fila.
class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : QuizDurations.fast;
    return AnimatedContainer(
      duration: duration,
      curve: QuizDurations.curve,
      width: QuizSpacing.xxl + QuizSpacing.xl,
      height: QuizSpacing.xxl,
      padding: const EdgeInsets.all(QuizSpacing.xs),
      decoration: BoxDecoration(
        color: value ? QuizPalette.primary : QuizPalette.divider,
        borderRadius: BorderRadius.circular(QuizRadii.pill),
      ),
      child: AnimatedAlign(
        duration: duration,
        curve: QuizDurations.curve,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: QuizSpacing.xl,
          height: QuizSpacing.xl,
          decoration: const BoxDecoration(
            color: QuizPalette.surfaceElevated,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
