import 'package:flutter/material.dart';

import '../modes/quiz10/quiz_generation.dart';
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('QuizAI'),
      centerTitle: false,
      actions: [
        IconButton(
          tooltip: 'Configuración',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(
            context,
          ).push<void>(MaterialPageRoute(builder: (_) => const SettingsPage())),
        ),
      ],
    ),
    body: SafeArea(
      child: _selectedTab == 0
          ? ModalidadesPage(generator: widget.generator)
          : const ProfilePage(),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedTab,
      onDestinationSelected: (index) {
        setState(() => _selectedTab = index);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view_rounded),
          label: 'Modalidades',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
    ),
  );
}
