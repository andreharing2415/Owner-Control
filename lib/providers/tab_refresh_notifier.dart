import 'package:flutter/foundation.dart';

/// Notifica telas que devem recarregar quando a aba muda (ARQ-05).
/// Substitui GlobalKey<ScreenState> por desacoplamento via Listenable.
class TabRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
