import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/auth_gate.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa auth (lê tokens armazenados)
  await AuthService.instance.initialize();

  // Firebase + Push: só inicializa se google-services.json estiver configurado.
  // Sem ele, Firebase.initializeApp() causa crash nativo no Android.
  if (!kIsWeb) {
    try {
      // Tenta inicializar; em builds sem google-services.json, captura o erro.
      await Firebase.initializeApp();
      await NotificationService.instance.initialize();
    } catch (e) {
      debugPrint('[Firebase] nao inicializado (push desabilitado): $e');
    }
  }

  runApp(const MestreDaObraApp());
}

class MestreDaObraApp extends StatelessWidget {
  const MestreDaObraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
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
