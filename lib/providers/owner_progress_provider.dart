import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../services/notification_service.dart';

/// Provider da visão do dono da obra.
///
/// Carrega obras convidadas, mantém a obra selecionada e atualiza o feed quando
/// chegam notificações relacionadas à obra atual.
class OwnerProgressProvider extends ChangeNotifier {
  OwnerProgressProvider({ApiClient? apiClient}) : _api = apiClient ?? ApiClient() {
    NotificationService.instance.addDataListener(_onNotificationData);
  }

  final ApiClient _api;

  bool _loading = false;
  String? _error;
  List<ObraConvidada> _obras = [];
  ObraConvidada? _selectedObra;
  int _refreshTick = 0;

  bool get loading => _loading;
  String? get error => _error;
  List<ObraConvidada> get obras => _obras;
  ObraConvidada? get selectedObra => _selectedObra;
  int get refreshTick => _refreshTick;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _obras = await _api.listarObrasConvidadas();
      if (_obras.isNotEmpty) {
        _selectedObra ??= _obras.first;
        final selectedId = _selectedObra?.obraId;
        _selectedObra = _obras.firstWhere(
          (obra) => obra.obraId == selectedId,
          orElse: () => _obras.first,
        );
      } else {
        _selectedObra = null;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> selectObra(ObraConvidada obra) async {
    if (_selectedObra?.obraId == obra.obraId) return;
    _selectedObra = obra;
    _refreshTick++;
    notifyListeners();
  }

  Future<void> refreshCurrent() async {
    _refreshTick++;
    notifyListeners();
  }

  void _onNotificationData(Map<String, dynamic> data) {
    final obraId = data['obra_id'] as String?;
    if (obraId == null) {
      _refreshTick++;
      notifyListeners();
      return;
    }
    if (_selectedObra?.obraId == obraId) {
      _refreshTick++;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    NotificationService.instance.removeDataListener(_onNotificationData);
    super.dispose();
  }
}
