import 'package:flutter/material.dart';

import '../providers/tab_refresh_notifier.dart';
import 'home_screen.dart';
import 'obras_screen.dart';
import 'documents_screen.dart';
import 'prestadores_screen.dart';
import 'settings_screen.dart';

// Índice da aba Obras na NavigationBar.
const _kObrasTabIndex = 1;

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
      child: NotificationListener<ObraTabNotification>(
        onNotification: (_) {
          _onTabChanged(_kObrasTabIndex);
          return true;
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

class RoleShellDestination {
  const RoleShellDestination({
    required this.path,
    required this.destination,
  });

  final String path;
  final NavigationDestination destination;
}

class RoleAwareShell extends StatelessWidget {
  const RoleAwareShell({
    super.key,
    required this.child,
    required this.currentPath,
    required this.destinations,
    required this.onNavigate,
  });

  final Widget child;
  final String currentPath;
  final List<RoleShellDestination> destinations;
  final ValueChanged<String> onNavigate;

  int _resolveSelectedIndex() {
    final exact = destinations.indexWhere((d) => d.path == currentPath);
    if (exact >= 0) return exact;
    final nested = destinations.indexWhere(
      (d) => currentPath.startsWith('${d.path}/'),
    );
    return nested >= 0 ? nested : 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _resolveSelectedIndex();
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => onNavigate(destinations[index].path),
        destinations: destinations.map((d) => d.destination).toList(),
      ),
    );
  }
}
