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
        toolbarHeight: 88,
        centerTitle: false,
        backgroundColor: QuizPalette.backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,

        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.asset(
                'assets/branding/quizai_logo.png',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'QuizAI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 43,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                ),
              ),
            ),
          ],
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(35),
                border: Border.all(color: Colors.white.withAlpha(55)),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: const BoxDecoration(color: QuizPalette.backgroundDark),
        child: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF5836B5),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withAlpha(65)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(35),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
                    (states) => TextStyle(
                      color: states.contains(WidgetState.selected)
                          ? QuizPalette.background
                          : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                child: NavigationBar(
                  height: 72,
                  backgroundColor: Colors.transparent,
                  indicatorColor: const Color(0xFFF0E2FF),
                  surfaceTintColor: Colors.transparent,
                  selectedIndex: _selectedTab,

                  onDestinationSelected: (index) {
                    setState(() => _selectedTab = index);
                  },

                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.grid_view_outlined, color: Colors.white),
                      selectedIcon: Icon(
                        Icons.grid_view_rounded,
                        color: QuizPalette.background,
                      ),
                      label: 'Modalidades',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline, color: Colors.white),
                      selectedIcon: Icon(
                        Icons.person,
                        color: QuizPalette.background,
                      ),
                      label: 'Perfil',
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
}
