import 'package:flutter/material.dart';

import '../modes/quiz10/quiz_generation.dart';
import 'app_theme.dart';
import 'home/modalidades_page.dart';
import 'profile/profile_page.dart';
import 'settings/settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.generator});

  final QuizGenerator? generator;

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
        titleSpacing: 14,
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
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'QuizAI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 47,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2.2,
                  height: 0.95,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(28),
                border: Border.all(color: Colors.white.withAlpha(52)),
              ),
              child: IconButton(
                tooltip: 'Configuración',
                icon: const Icon(
                  Icons.settings_rounded,
                  color: Colors.white,
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
              ? ModalidadesPage(generator: widget.generator)
              : Theme(
                  data: Theme.of(context).copyWith(
                    textTheme: Theme.of(context).textTheme.apply(
                      bodyColor: Colors.white,
                      displayColor: Colors.white,
                    ),
                  ),
                  child: const ProfilePage(),
                ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        decoration: const BoxDecoration(color: QuizPalette.backgroundDark),
        child: SafeArea(
          top: false,
          child: Container(
            key: const Key('quizai-bottom-nav'),
            height: 84,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: QuizPalette.navBackgroundGradient,
              borderRadius: BorderRadius.circular(48),
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
          borderRadius: BorderRadius.circular(44),
          child: AnimatedContainer(
            key: selected ? const Key('quizai-nav-active') : null,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: selected ? QuizPalette.navActiveGradient : null,
              borderRadius: BorderRadius.circular(44),
              border: selected
                  ? Border.all(color: Colors.white, width: 1.5)
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.white.withAlpha(70),
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
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: QuizTypography.family,
                      color: foreground,
                      fontSize: selected ? 16 : 15,
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
