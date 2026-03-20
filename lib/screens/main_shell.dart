import 'package:flutter/material.dart';

import '../providers/tab_refresh_notifier.dart';
import 'home_screen.dart';
import 'obras_screen.dart';
import 'documents_screen.dart';
import 'prestadores_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // ARQ-05: desacoplado via notifier em vez de GlobalKey<ScreenState>
  final _homeRefresh = TabRefreshNotifier();
  final _documentsRefresh = TabRefreshNotifier();
  final _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  @override
  void dispose() {
    _homeRefresh.dispose();
    _documentsRefresh.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    if (index == _currentIndex) {
      // Re-tap same tab → pop to root
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _currentIndex = index);
    // Recarrega dados da aba destino para sincronizar obras.
    switch (index) {
      case 0:
        _homeRefresh.refresh();
      case 2:
        _documentsRefresh.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _navigatorKeys[_currentIndex].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _TabNavigator(
              navigatorKey: _navigatorKeys[0],
              child: HomeScreen(refreshNotifier: _homeRefresh),
            ),
            _TabNavigator(
              navigatorKey: _navigatorKeys[1],
              child: const ObrasScreen(),
            ),
            _TabNavigator(
              navigatorKey: _navigatorKeys[2],
              child: DocumentsScreen(refreshNotifier: _documentsRefresh),
            ),
            _TabNavigator(
              navigatorKey: _navigatorKeys[3],
              child: const PrestadoresScreen(),
            ),
            _TabNavigator(
              navigatorKey: _navigatorKeys[4],
              child: const SettingsScreen(),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabChanged,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.home_work_outlined),
              selectedIcon: Icon(Icons.home_work),
              label: 'Obra',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: 'Documentos',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Prestadores',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Config',
            ),
          ],
        ),
      ),
    );
  }
}

class _TabNavigator extends StatelessWidget {
  const _TabNavigator({required this.navigatorKey, required this.child});
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => child,
      ),
    );
  }
}
