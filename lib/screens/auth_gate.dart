import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import 'complete_profile_screen.dart';
import 'login_screen.dart';
import 'main_shell.dart';

/// Widget raiz que roteia entre splash, login e app principal.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AuthProvider>().checkAuth();
      if (mounted && context.read<AuthProvider>().isAuthenticated) {
        context.read<SubscriptionProvider>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return switch (auth.status) {
      AuthStatus.unknown => const _SplashView(),
      AuthStatus.authenticated => auth.isNewUser
          ? const CompleteProfileScreen()
          : const MainShell(),
      AuthStatus.unauthenticated => const LoginScreen(),
    };
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo_horizontal.png', width: 220),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
