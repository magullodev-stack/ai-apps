import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'home/home_page.dart';
import 'profile/profile_page.dart';
import 'settings/muondia_settings.dart';
import 'settings/settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedTab = 0;
  final _settings = ValueNotifier(const MuondiaSettings());

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => ValueListenableBuilder<MuondiaSettings>(
          valueListenable: _settings,
          builder: (_, settings, _) => SettingsPage(
            settings: settings,
            onChanged: (value) => _settings.value = value,
          ),
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHome = _selectedTab == 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF16003F),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
        if (isHome)
          Image.asset(
            'assets/home/Muondia_Home_background_1080x1920.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.high,
          )
        else
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: MuondiaPalette.backgroundGradient,
            ),
          ),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: isHome
              ? HomePage(onOpenSettings: _openSettings)
              : SafeArea(
                  bottom: false,
                  child: _ProfileTab(onOpenSettings: _openSettings),
                ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(
              MuondiaLayout.horizontalPadding,
              0,
              MuondiaLayout.horizontalPadding,
              MuondiaSpacing.sm,
            ),
            color: Colors.transparent,
            child: SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MuondiaRadii.pill),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(38),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: MuondiaPalette.primaryLight.withAlpha(26),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(MuondiaRadii.pill),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: Container(
                      key: const Key('muondia-bottom-nav'),
                      height: 70,
                      padding: const EdgeInsets.all(MuondiaSpacing.xs),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0x4DFFFFFF),
                            Color(0x3D8E70E8),
                            Color(0x334B2C9C),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(MuondiaRadii.pill),
                        border: Border.all(
                          color: const Color(0x80FFFFFF),
                          width: 1.1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _QuizNavItem(
                              key: const Key('muondia-nav-inicio'),
                              label: 'Inicio',
                              icon: Icons.home_outlined,
                              selectedIcon: Icons.home_rounded,
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
                              key: const Key('muondia-nav-perfil'),
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
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Theme(
            data: Theme.of(context).copyWith(
              textTheme: Theme.of(context).textTheme.apply(
                bodyColor: MuondiaPalette.foreground,
                displayColor: MuondiaPalette.foreground,
              ),
            ),
            child: const ProfilePage(),
          ),
        ),
        Positioned(
          top: 28,
          right: MuondiaLayout.horizontalPadding,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MuondiaPalette.navSurfaceEnd,
              border: Border.all(color: MuondiaPalette.foreground.withAlpha(72)),
            ),
            child: IconButton(
              tooltip: 'Ajustes',
              onPressed: onOpenSettings,
              icon: const Icon(
                Icons.settings_rounded,
                color: MuondiaPalette.foreground,
                size: 29,
              ),
            ),
          ),
        ),
      ],
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
        ? MuondiaPalette.navActiveText
        : MuondiaPalette.navInactiveText;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MuondiaRadii.pill),
          child: AnimatedContainer(
            key: selected ? const Key('muondia-nav-active') : null,
            duration: MuondiaDurations.fast,
            curve: MuondiaDurations.curve,
            decoration: BoxDecoration(
              gradient: selected ? MuondiaPalette.navActiveGradient : null,
              borderRadius: BorderRadius.circular(MuondiaRadii.pill),
              border: selected
                  ? Border.all(color: MuondiaPalette.foreground, width: 1.5)
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: MuondiaPalette.foreground.withAlpha(70),
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
                  const SizedBox(height: MuondiaSpacing.xs),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MuondiaTypography.label.copyWith(
                      color: foreground,
                      fontSize: selected ? MuondiaTypography.label.fontSize : 15,
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
