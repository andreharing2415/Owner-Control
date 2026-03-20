import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show FlutterError, PlatformDispatcher, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/subscription_provider.dart';
import 'screens/auth_gate.dart';
import 'services/auth_service.dart';
import 'services/ad_service.dart';
import 'services/notification_service.dart';

/// Se true, Crashlytics foi inicializado com sucesso.
bool _crashlyticsReady = false;

Future<void> main() async {
  // Captura erros assíncronos na zona raiz
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Inicializa auth (lê tokens armazenados)
    await AuthService.instance.initialize();

    // Firebase + Crashlytics + Push
    if (!kIsWeb) {
      try {
        await Firebase.initializeApp();

        // Crashlytics: captura erros fatais do Flutter
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(!kDebugMode);
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
        _crashlyticsReady = true;

        await NotificationService.instance.initialize();
      } catch (e) {
        debugPrint('[Firebase] nao inicializado (crashlytics/push desabilitado): $e');
      }
    }

    // Captura erros assíncronos não tratados (fora do Flutter framework)
    PlatformDispatcher.instance.onError = (error, stack) {
      if (_crashlyticsReady) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } else {
        debugPrint('[CRASH] $error\n$stack');
      }
      return true;
    };

    // AdMob: inicializa SDK de anúncios (não bloqueia se falhar)
    AdService.instance.initialize();

    runApp(const MestreDaObraApp());
  }, (error, stack) {
    // Erros da zona raiz (runZonedGuarded)
    if (_crashlyticsReady) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } else {
      debugPrint('[ZONE-CRASH] $error\n$stack');
    }
  });
}

class MestreDaObraApp extends StatelessWidget {
  const MestreDaObraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
      ],
      child: MaterialApp(
        title: 'Mestre da Obra',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}
