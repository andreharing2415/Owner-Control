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
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ObraMasterApp());
}

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
    _appLinks = AppLinks();

    // Handle link that launched the app
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleDeepLink(initialUri);
    } catch (_) {}

    // Handle links while app is running
    _linkSub = _appLinks.uriLinkStream.listen(_handleDeepLink);
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
    );
  }
}
