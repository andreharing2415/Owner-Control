import "package:flutter/foundation.dart";

import "../models/subscription.dart";
import "../services/api_client.dart";

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider({required this.api});

  final ApiClient api;
  SubscriptionInfo? _info;
  bool _loading = false;
  String? _error;

  SubscriptionInfo? get info => _info;
  bool get loading => _loading;
  String? get error => _error;

  String get plan => _info?.plan ?? "gratuito";
  bool get isGratuito => plan == "gratuito";
  bool get isDono => plan == "dono_da_obra";

  // Quick access to plan config
  bool get canDeleteDoc => _info?.canDeleteDoc ?? false;
  bool get canCreateEtapas => _info?.canCreateEtapas ?? false;
  bool get canCreateChecklistItems =>
      _info?.canCreateChecklistItems ?? false;
  bool get canCreateComentarios => _info?.canCreateComentarios ?? false;
  int get maxConvites => _info?.maxConvites ?? 0;
  int? get maxDocPagesViewable => _info?.maxDocPagesViewable;

  // Usage tracking
  int get aiVisualUsed => _info?.aiVisualUsed ?? 0;
  int? get aiVisualMonthlyLimit => _info?.aiVisualMonthlyLimit;
  int get checklistInteligenteUsed => _info?.checklistInteligenteUsed ?? 0;
  int? get checklistInteligenteLifetimeLimit =>
      _info?.checklistInteligenteLifetimeLimit;
  int? get normasResultsLimit => _info?.normasResultsLimit;
  int? get prestadoresLimit => _info?.prestadoresLimit;
  bool get prestadoresShowContact => _info?.prestadoresShowContact ?? false;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _info = await api.getSubscriptionInfo();
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> sync() async {
    try {
      await api.syncSubscription();
      await load();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clear() {
    _info = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }
}
