import "dart:async";
import "dart:io";

import "package:app_links/app_links.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "providers/auth_provider.dart";
import "providers/convite_provider.dart";
import "providers/obra_provider.dart";
import "providers/subscription_provider.dart";
import "services/ad_service.dart";
import "services/api_client.dart";
import "services/appsflyer_service.dart";
import "screens/auth/login_screen.dart";
import "screens/convites/aceitar_convite_screen.dart";
import "screens/home/home_screen.dart";
import "screens/subscription/paywall_screen.dart";
import "widgets/rewarded_dialog.dart";

bool _isNetworkError(Object error) {
  return error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error.toString().contains('connection abort') ||
      error.toString().contains('Connection reset') ||
      error.toString().contains('ClientException');
}

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (!_isNetworkError(details.exception)) {
        _globalErrorNotifier.value = details.exceptionAsString();
      }
    };
    runApp(const ObraMasterApp());
  }, (error, stack) {
    // Network errors should not crash the entire app
    if (_isNetworkError(error)) {
      debugPrint("Network error (ignored): $error");
      return;
    }
    _globalErrorNotifier.value = "$error\n$stack";
  });
}

final _globalErrorNotifier = ValueNotifier<String?>(null);

class ObraMasterApp extends StatefulWidget {
  const ObraMasterApp({super.key});

  @override
  State<ObraMasterApp> createState() => _ObraMasterAppState();
}

/// Maps a 403 error message to a feature key for the reward-usage endpoint.
String _extractFeatureFromMessage(String message) {
  final lower = message.toLowerCase();
  if (lower.contains("visual") || lower.contains("foto")) return "ai_visual";
  if (lower.contains("checklist") || lower.contains("inteligente")) return "checklist_inteligente";
  if (lower.contains("norma")) return "normas";
  if (lower.contains("documento") || lower.contains("upload") || lower.contains("doc")) return "doc_upload";
  return "ai_visual"; // fallback
}

class _ObraMasterAppState extends State<ObraMasterApp> {
  final _api = ApiClient();
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    // Global 403 handler — shows rewarded dialog (free) or paywall
    _api.onFeatureGate = (message) {
      final ctx = _navigatorKey.currentContext;
      if (ctx == null) return;

      final sub = ctx.read<SubscriptionProvider>();
      if (sub.canWatchRewarded) {
        // Free user can watch a video to earn extra uses
        final feature = _extractFeatureFromMessage(message);
        RewardedDialog.show(
          ctx,
          feature: feature,
          featureLabel: message,
          api: _api,
        );
      } else {
        PaywallScreen.show(ctx, message: message);
      }
    };
    _initDeepLinks();
    // Initialize ad and attribution SDKs
    AdService.instance.initialize();
    AppsFlyerService.instance.initialize();
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
  bool _wasAuthenticated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated) {
      _subscriptionLoaded = false;
      _wasAuthenticated = false;
    } else if (!_subscriptionLoaded && !_wasAuthenticated) {
      _subscriptionLoaded = true;
      _wasAuthenticated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<SubscriptionProvider>().load();
        }
      });
    }
  }

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
          return const LoginScreen();
        }
        return const HomeScreen();
      },
      ),
    );
  }
}
