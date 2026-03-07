import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "providers/auth_provider.dart";
import "providers/obra_provider.dart";
import "services/api_client.dart";
import "screens/auth/login_screen.dart";
import "screens/home/home_screen.dart";

void main() {
  runApp(const ObraMasterApp());
}

class ObraMasterApp extends StatefulWidget {
  const ObraMasterApp({super.key});

  @override
  State<ObraMasterApp> createState() => _ObraMasterAppState();
}

class _ObraMasterAppState extends State<ObraMasterApp> {
  final _api = ApiClient();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(api: _api)..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => ObraAtualProvider(api: _api),
        ),
      ],
      child: MaterialApp(
        title: "Mestre da Obra",
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.loading) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 220,
                  ),
                  const SizedBox(height: 32),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }
        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }
        return const HomeScreen();
      },
    );
  }
}
