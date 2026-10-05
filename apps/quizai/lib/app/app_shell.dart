import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'home/modalidades_page.dart';
import 'profile/profile_page.dart';
import 'settings/settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedTab = 0;

  void _openSettings() {
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const SettingsPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QuizPalette.backgroundDark,
      appBar: AppBar(
        toolbarHeight: 92,
        titleSpacing: QuizLayout.horizontalPadding,
        centerTitle: false,
        backgroundColor: QuizPalette.backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/branding/quizai_logo.png',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: QuizSpacing.sm),
            const Flexible(
              child: Text(
                'QuizAI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: QuizTypography.brand,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: QuizSpacing.lg),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: QuizPalette.foreground.withAlpha(28),
                border: Border.all(color: QuizPalette.foreground.withAlpha(52)),
              ),
              child: IconButton(
                tooltip: 'Configuración',
                icon: const Icon(
                  Icons.settings_rounded,
                  color: QuizPalette.foreground,
                  size: 28,
                ),
                onPressed: _openSettings,
              ),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: QuizPalette.backgroundGradient,
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: _selectedTab == 0
              ? const ModalidadesPage()
              : Theme(
                  data: Theme.of(context).copyWith(
                    textTheme: Theme.of(context).textTheme.apply(
                      bodyColor: QuizPalette.foreground,
                      displayColor: QuizPalette.foreground,
                    ),
                  ),
                  child: const ProfilePage(),
                ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: QuizLayout.horizontalPadding,
          vertical: QuizSpacing.sm,
        ),
        decoration: const BoxDecoration(color: QuizPalette.backgroundDark),
        child: SafeArea(
          top: false,
          child: Container(
            key: const Key('quizai-bottom-nav'),
            height: 84,
            padding: const EdgeInsets.all(QuizSpacing.xs),
            decoration: BoxDecoration(
              gradient: QuizPalette.navBackgroundGradient,
              borderRadius: BorderRadius.circular(QuizRadii.pill),
              border: Border.all(color: QuizPalette.navBorder, width: 1.3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(55),
                  blurRadius: 20,
                  offset: const Offset(0, 7),
                ),
                BoxShadow(
                  color: QuizPalette.primaryLight.withAlpha(45),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _QuizNavItem(
                    key: const Key('quizai-nav-modalidades'),
                    label: 'Modalidades',
                    icon: Icons.grid_view_outlined,
                    selectedIcon: Icons.grid_view_rounded,
                    selected: _selectedTab == 0,
                    onTap: () {
                      if (_selectedTab != 0) {
                        setState(() => _selectedTab = 0);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _QuizNavItem(
                    key: const Key('quizai-nav-perfil'),
                    label: 'Perfil',
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    selected: _selectedTab == 1,
                    onTap: () {
                      if (_selectedTab != 1) {
                        setState(() => _selectedTab = 1);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizNavItem extends StatelessWidget {
  const _QuizNavItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? QuizPalette.navActiveText
        : QuizPalette.navInactiveText;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(QuizRadii.pill),
          child: AnimatedContainer(
            key: selected ? const Key('quizai-nav-active') : null,
            duration: QuizDurations.fast,
            curve: QuizDurations.curve,
            decoration: BoxDecoration(
              gradient: selected ? QuizPalette.navActiveGradient : null,
              borderRadius: BorderRadius.circular(QuizRadii.pill),
              border: selected
                  ? Border.all(color: QuizPalette.foreground, width: 1.5)
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: QuizPalette.foreground.withAlpha(70),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? selectedIcon : icon,
                    color: foreground,
                    size: 27,
                  ),
                  const SizedBox(height: QuizSpacing.xs),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: QuizTypography.label.copyWith(
                      color: foreground,
                      fontSize: selected ? QuizTypography.label.fontSize : 15,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
