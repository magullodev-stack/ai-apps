import 'package:flutter/material.dart';

import 'quiz_generation.dart';
import 'quiz_page.dart';

/// Application identity and navigation, independent of Quiz10's game rules.
class QuizAIApp extends StatelessWidget {
  const QuizAIApp({super.key, this.generator});

  final QuizGenerator? generator;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'QuizAI',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
    ),
    home: _HomePage(generator: generator),
  );
}

class _HomePage extends StatefulWidget {
  const _HomePage({this.generator});
  final QuizGenerator? generator;

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
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
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const _SettingsPage()),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: _selectedTab == 0
          ? Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ModeEntry(
                      title: '🎲 Quiz10',
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => QuizPage(generator: widget.generator),
                        ),
                      ),
                    ),
                    const _ModeEntry(title: '🏆 Sala'),
                    const _ModeEntry(title: '⚔️ 1vs1'),
                    const _ModeEntry(title: '📚 Estudio'),
                  ],
                ),
              ),
            )
          : const _PendingPageContent(title: 'Perfil'),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedTab,
      onDestinationSelected: (index) => setState(() => _selectedTab = index),
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

class _ModeEntry extends StatelessWidget {
  const _ModeEntry({required this.title, this.onTap});
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: onTap == null ? const Text('No disponible') : null,
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        enabled: onTap != null,
        onTap: onTap,
      ),
    ),
  );
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Configuración'), centerTitle: false),
    body: const SafeArea(child: _PendingPageContent()),
  );
}

class _PendingPageContent extends StatelessWidget {
  const _PendingPageContent({this.title});
  final String? title;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
          ],
          const Text('Todavía no disponible.'),
        ],
      ),
    ),
  );
}
