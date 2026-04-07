import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/complete_profile_screen.dart';
import '../screens/documents_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/obras_screen.dart';
import '../screens/owner_progresso_screen.dart';
import '../screens/prestadores_screen.dart';
import '../screens/settings_screen.dart';

class AppRouteNames {
  static const splash = 'splash';
  static const login = 'login';
  static const completeProfile = 'completeProfile';
  static const home = 'home';
  static const obras = 'obras';
  static const documentos = 'documentos';
  static const prestadores = 'prestadores';
  static const config = 'config';
  static const owner = 'owner';
  static const ownerConfig = 'ownerConfig';
}

class AppRouter {
  AppRouter({required this.authProvider});

  final AuthProvider authProvider;

  late final GoRouter router = GoRouter(
        initialLocation: '/splash',
        refreshListenable: authProvider,
        redirect: (context, state) {
          final path = state.matchedLocation;
          final isAuthPath = path == '/login' || path == '/splash' || path == '/complete-profile';

          if (authProvider.status == AuthStatus.unknown) {
            return path == '/splash' ? null : '/splash';
          }

          if (authProvider.status == AuthStatus.unauthenticated) {
            return path == '/login' ? null : '/login';
          }

          if (authProvider.isNewUser) {
            return path == '/complete-profile' ? null : '/complete-profile';
          }

          final userRole = authProvider.user?['role'] as String? ?? 'owner';
          final isDono = userRole == 'dono_da_obra';

          if (isDono) {
            if (path.startsWith('/owner')) return null;
            return '/owner';
          }

          if (path.startsWith('/owner')) {
            return '/';
          }

          if (isAuthPath) {
            return '/';
          }

          return null;
        },
        routes: [
          GoRoute(
            name: AppRouteNames.splash,
            path: '/splash',
            builder: (context, state) => _SplashRouteView(authProvider: authProvider),
          ),
          GoRoute(
            name: AppRouteNames.login,
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            name: AppRouteNames.completeProfile,
            path: '/complete-profile',
            builder: (context, state) => const CompleteProfileScreen(),
          ),
          ShellRoute(
            builder: (context, state, child) => RoleAwareShell(
              currentPath: state.matchedLocation,
              onNavigate: (path) => context.go(path),
              destinations: const [
                RoleShellDestination(
                  path: '/',
                  destination: NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Inicio',
                  ),
                ),
                RoleShellDestination(
                  path: '/obras',
                  destination: NavigationDestination(
                    icon: Icon(Icons.home_work_outlined),
                    selectedIcon: Icon(Icons.home_work),
                    label: 'Obra',
                  ),
                ),
                RoleShellDestination(
                  path: '/documentos',
                  destination: NavigationDestination(
                    icon: Icon(Icons.folder_outlined),
                    selectedIcon: Icon(Icons.folder),
                    label: 'Documentos',
                  ),
                ),
                RoleShellDestination(
                  path: '/prestadores',
                  destination: NavigationDestination(
                    icon: Icon(Icons.people_outline),
                    selectedIcon: Icon(Icons.people),
                    label: 'Prestadores',
                  ),
                ),
                RoleShellDestination(
                  path: '/config',
                  destination: NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Config',
                  ),
                ),
              ],
              child: child,
            ),
            routes: [
              GoRoute(
                name: AppRouteNames.home,
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
              GoRoute(
                name: AppRouteNames.obras,
                path: '/obras',
                builder: (context, state) => const ObrasScreen(),
              ),
              GoRoute(
                name: AppRouteNames.documentos,
                path: '/documentos',
                builder: (context, state) => const DocumentsScreen(),
              ),
              GoRoute(
                name: AppRouteNames.prestadores,
                path: '/prestadores',
                builder: (context, state) => const PrestadoresScreen(),
              ),
              GoRoute(
                name: AppRouteNames.config,
                path: '/config',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
          ShellRoute(
            builder: (context, state, child) => RoleAwareShell(
              currentPath: state.matchedLocation,
              onNavigate: (path) => context.go(path),
              destinations: const [
                RoleShellDestination(
                  path: '/owner',
                  destination: NavigationDestination(
                    icon: Icon(Icons.monitor_heart_outlined),
                    selectedIcon: Icon(Icons.monitor_heart),
                    label: 'Progresso',
                  ),
                ),
                RoleShellDestination(
                  path: '/owner/config',
                  destination: NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Config',
                  ),
                ),
              ],
              child: child,
            ),
            routes: [
              GoRoute(
                name: AppRouteNames.owner,
                path: '/owner',
                builder: (context, state) => const OwnerProgressoScreen(),
              ),
              GoRoute(
                name: AppRouteNames.ownerConfig,
                path: '/owner/config',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      );

  String? _routeNameForPayload(Map<String, dynamic> payload) {
    final explicit = payload['route'] as String?;
    switch (explicit) {
      case 'home':
        return AppRouteNames.home;
      case 'obras':
        return AppRouteNames.obras;
      case 'documentos':
        return AppRouteNames.documentos;
      case 'prestadores':
        return AppRouteNames.prestadores;
      case 'config':
        return AppRouteNames.config;
      case 'owner':
        return AppRouteNames.owner;
      case 'owner_config':
        return AppRouteNames.ownerConfig;
    }

    final type = payload['type'] as String?;
    switch (type) {
      case 'cronograma_alert':
      case 'rdo_publicado':
      case 'obra_update':
        return AppRouteNames.obras;
      case 'document_update':
        return AppRouteNames.documentos;
      case 'prestador_update':
        return AppRouteNames.prestadores;
    }
    return null;
  }

  Future<void> openFromNotificationPayload(Map<String, dynamic> payload) async {
    final currentRole = authProvider.user?['role'] as String? ?? 'owner';
    final isOwnerView = currentRole == 'dono_da_obra';

    final resolved = _routeNameForPayload(payload) ??
        (isOwnerView ? AppRouteNames.owner : AppRouteNames.home);

    final ownerOnly = resolved == AppRouteNames.owner ||
        resolved == AppRouteNames.ownerConfig;
    if (ownerOnly && !isOwnerView) {
      router.goNamed(AppRouteNames.home);
      return;
    }
    if (!ownerOnly && isOwnerView && resolved != AppRouteNames.config) {
      router.goNamed(AppRouteNames.owner);
      return;
    }
    router.goNamed(resolved);
  }
}

class _SplashRouteView extends StatefulWidget {
  const _SplashRouteView({required this.authProvider, super.key});

  final AuthProvider authProvider;

  @override
  State<_SplashRouteView> createState() => _SplashRouteViewState();
}

class _SplashRouteViewState extends State<_SplashRouteView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.authProvider.checkAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
