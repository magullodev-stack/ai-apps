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
          style: MuondiaTypography.sectionTitle.copyWith(
            color: MuondiaPalette.foreground,
          ),
        ),
      ),
      const SizedBox(height: MuondiaSpacing.md),
      Container(
        decoration: BoxDecoration(
          color: MuondiaPalette.surface,
          borderRadius: BorderRadius.circular(MuondiaRadii.card),
          boxShadow: MuondiaShadows.card,
        ),
        child: Material(
          color: MuondiaPalette.surface,
          borderRadius: BorderRadius.circular(MuondiaRadii.card),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    indent: MuondiaSpacing.lg,
                    endIndent: MuondiaSpacing.lg,
                    color: MuondiaPalette.divider,
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
        ? Text(value!, style: MuondiaTypography.bodySecondary)
        : const Icon(Icons.chevron_right_rounded, color: MuondiaPalette.inkMuted),
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
      padding: const EdgeInsets.all(MuondiaSpacing.lg),
      child: Row(
        children: [
          _SettingsIcon(icon: icon, accent: accent),
          const SizedBox(width: MuondiaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MuondiaTypography.label.copyWith(color: MuondiaPalette.ink),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: MuondiaSpacing.xs),
                  Text(subtitle!, style: MuondiaTypography.bodySecondary),
                ],
              ],
            ),
          ),
          const SizedBox(width: MuondiaSpacing.md),
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
      width: MuondiaSpacing.xxl + MuondiaSpacing.lg,
      height: MuondiaSpacing.xxl + MuondiaSpacing.lg,
      decoration: BoxDecoration(
        color: accent.withAlpha(32),
        borderRadius: BorderRadius.circular(MuondiaRadii.medium),
      ),
      child: Icon(
        icon,
        size: MuondiaSpacing.xl,
        color: accent == MuondiaPalette.warning ? MuondiaPalette.ink : accent,
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
        : MuondiaDurations.fast;
    return AnimatedContainer(
      duration: duration,
      curve: MuondiaDurations.curve,
      width: MuondiaSpacing.xxl + MuondiaSpacing.xl,
      height: MuondiaSpacing.xxl,
      padding: const EdgeInsets.all(MuondiaSpacing.xs),
      decoration: BoxDecoration(
        color: value ? MuondiaPalette.primary : MuondiaPalette.divider,
        borderRadius: BorderRadius.circular(MuondiaRadii.pill),
      ),
      child: AnimatedAlign(
        duration: duration,
        curve: MuondiaDurations.curve,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: MuondiaSpacing.xl,
          height: MuondiaSpacing.xl,
          decoration: const BoxDecoration(
            color: MuondiaPalette.surfaceElevated,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
