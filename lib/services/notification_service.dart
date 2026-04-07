import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/api.dart';

// ─── Background handler (top-level — obrigatório para FCM) ────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // O Firebase já exibe a notificação no sistema quando o app está em background/encerrado.
  // Aqui apenas logamos para debug.
  debugPrint('[FCM] mensagem em background: ${message.messageId}');
}

// ─── Canais de notificação Android ────────────────────────────────────────────
const _kChannelAlertasId = 'alertas_orcamentarios';
const _kChannelAlertasName = 'Alertas Orçamentários';
const _kChannelAlertasDesc = 'Notificações de desvio orçamentário na obra';

/// Singleton que gerencia permissões FCM, token e notificações locais.
///
/// Uso típico:
/// ```dart
/// await NotificationService.instance.initialize();
/// await NotificationService.instance.registrarParaObra('obra-id', apiClient);
/// ```
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _local = FlutterLocalNotificationsPlugin();
  final List<void Function(Map<String, dynamic>)> _dataListeners = [];
  Future<void> Function(Map<String, dynamic>)? _deepLinkHandler;
  bool _initialized = false;

  void setDeepLinkHandler(Future<void> Function(Map<String, dynamic>) handler) {
    _deepLinkHandler = handler;
  }

  void addDataListener(void Function(Map<String, dynamic>) listener) {
    _dataListeners.add(listener);
  }

  void removeDataListener(void Function(Map<String, dynamic>) listener) {
    _dataListeners.remove(listener);
  }

  void _notifyDataListeners(Map<String, dynamic> data) {
    for (final listener in _dataListeners) {
      listener(data);
    }
  }

  // ── Inicialização ────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    await _initLocalNotifications();
    await _initFcm();
    _initialized = true;
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == null || response.payload!.isEmpty) return;
        final payload = <String, dynamic>{'route': response.payload};
        _notifyDataListeners(payload);
        if (_deepLinkHandler != null) {
          _deepLinkHandler!(payload);
        }
      },
    );

    // Criar canal de alta prioridade no Android 8+
    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _kChannelAlertasId,
              _kChannelAlertasName,
              description: _kChannelAlertasDesc,
              importance: Importance.high,
            ),
          );
    }
  }

  Future<void> _initFcm() async {
    // Registrar handler de background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Solicitar permissão (iOS / Web)
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] permissão: ${settings.authorizationStatus}');

    // Notificações em foreground
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handlers
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _onMessageOpenedApp(initialMessage);
    }
  }

  // ── Token FCM ────────────────────────────────────────────────────────────────

  /// Retorna o token FCM do dispositivo, ou null se não disponível.
  Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('[FCM] erro ao obter token: $e');
      return null;
    }
  }

  /// Registra o token FCM deste dispositivo para uma obra específica no backend.
  /// Chame quando o usuário abrir/selecionar uma obra.
  Future<void> registrarParaObra(String obraId, ApiClient api) async {
    final token = await getToken();
    if (token == null) return;
    final platform = Platform.isIOS ? 'ios' : 'android';
    try {
      await api.registrarDeviceToken(
        obraId: obraId,
        token: token,
        platform: platform,
      );
      debugPrint('[FCM] token registrado para obra $obraId');
    } catch (e) {
      debugPrint('[FCM] erro ao registrar token: $e');
    }
  }

  /// Remove o token deste dispositivo para uma obra (ex: ao desativar alertas).
  Future<void> removerDaObra(String obraId, ApiClient api) async {
    final token = await getToken();
    if (token == null) return;
    try {
      await api.removerDeviceToken(obraId: obraId, token: token);
    } catch (e) {
      debugPrint('[FCM] erro ao remover token: $e');
    }
  }

  // ── Handlers ─────────────────────────────────────────────────────────────────

  void _onForegroundMessage(RemoteMessage message) {
    _notifyDataListeners(message.data);
    final n = message.notification;
    if (n == null) return;
    final route = message.data['route'] as String?;

    _local.show(
      message.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelAlertasId,
          _kChannelAlertasName,
          channelDescription: _kChannelAlertasDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: route,
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    _notifyDataListeners(message.data);
    if (_deepLinkHandler != null) {
      _deepLinkHandler!(message.data);
    }
    debugPrint('[FCM] app aberto via notificação: ${message.data}');
  }
}
