import "dart:async";

import "package:app_links/app_links.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "providers/auth_provider.dart";
import "providers/convite_provider.dart";
import "providers/obra_provider.dart";
import "providers/subscription_provider.dart";
import "services/api_client.dart";
import "screens/auth/login_screen.dart";
import "screens/convites/aceitar_convite_screen.dart";
import "screens/home/home_screen.dart";
import "screens/subscription/paywall_screen.dart";

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _globalErrorNotifier.value = details.exceptionAsString();
    };
    runApp(const ObraMasterApp());
  }, (error, stack) {
    _globalErrorNotifier.value = "$error\n$stack";
  });
}

final _globalErrorNotifier = ValueNotifier<String?>(null);

class ObraMasterApp extends StatefulWidget {
  const ObraMasterApp({super.key});

  @override
  State<ObraMasterApp> createState() => _ObraMasterAppState();
}

class _ObraMasterAppState extends State<ObraMasterApp> {
  final _api = ApiClient();
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    // Global 403 handler — shows paywall bottom sheet
    _api.onFeatureGate = (message) {
      final ctx = _navigatorKey.currentContext;
      if (ctx != null) {
        PaywallScreen.show(ctx, message: message);
      }
    };
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    try {
      _appLinks = AppLinks();

      // Handle link that launched the app
      final initialUri = await _appLinks.getInitialLink()
          .timeout(const Duration(seconds: 3));
      if (initialUri != null) _handleDeepLink(initialUri);

      // Handle links while app is running
      _linkSub = _appLinks.uriLinkStream.listen(_handleDeepLink);
    } catch (_) {
      // Deep links not available — app continues normally
    }
  }

  void _handleDeepLink(Uri uri) {
    // Match: .../api/convites/aceitar?token=XXX
    if (uri.path.contains("/convites/aceitar")) {
      final token = uri.queryParameters["token"];
      if (token != null && token.isNotEmpty) {
        // Wait for navigator to be ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => AceitarConviteScreen(
                token: token,
                api: _api,
              ),
            ),
          );
        });
      }
    }
  }

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
        ChangeNotifierProvider(
          create: (_) => SubscriptionProvider(api: _api),
        ),
        ChangeNotifierProvider(
          create: (_) => ConviteProvider(api: _api),
        ),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
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

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _subscriptionLoaded = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: _globalErrorNotifier,
      builder: (context, error, child) {
        if (error != null) {
          return MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.red[50],
              appBar: AppBar(title: const Text("Erro de Inicialização"), backgroundColor: Colors.red),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(error, style: const TextStyle(fontSize: 12, fontFamily: "monospace")),
              ),
            ),
          );
        }
        return child!;
      },
      child: Consumer<AuthProvider>(
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
                  const SizedBox(height: 16),
                  const Text("Carregando...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }
        if (!auth.isAuthenticated) {
          _subscriptionLoaded = false;
          return const LoginScreen();
        }
        // Load subscription info once after authentication
        if (!_subscriptionLoaded) {
          _subscriptionLoaded = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<SubscriptionProvider>().load();
          });
        }
        return const HomeScreen();
      },
      ),
    );
  }
}
