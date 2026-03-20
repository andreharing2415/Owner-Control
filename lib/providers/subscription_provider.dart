import 'package:flutter/foundation.dart';

import '../api/api.dart';

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionInfo? _info;
  bool _loading = false;

  SubscriptionInfo? get info => _info;
  bool get loading => _loading;

  // ─── Getters de plano ─────────────────────────────────────────────────────

  String get plan => _info?.plan ?? 'gratuito';
  bool get isGratuito => _info?.isGratuito ?? true;
  bool get isEssencial => _info?.isEssencial ?? false;
  bool get isCompleto => _info?.isCompleto ?? false;
  bool get showAds => _info?.showAds ?? true;

  // ─── Getters de feature ───────────────────────────────────────────────────

  bool get canDeleteDoc => _info?.canDeleteDoc ?? false;
  bool get canCreateEtapas => _info?.canCreateEtapas ?? false;
  bool get canCreateChecklistItems => _info?.canCreateChecklistItems ?? false;
  int get maxObras => _info?.maxObras ?? 1;
  int get maxConvites => _info?.maxConvites ?? 0;

  // ─── Carregar ─────────────────────────────────────────────────────────────

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final api = ApiClient();
      _info = await api.getSubscription();
    } catch (e) {
      debugPrint('[SubscriptionProvider] load error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> sync() async {
    try {
      final api = ApiClient();
      _info = await api.syncSubscription();
      notifyListeners();
    } catch (e) {
      debugPrint('[SubscriptionProvider] sync error: $e');
    }
  }

  void clear() {
    _info = null;
    notifyListeners();
  }
}
