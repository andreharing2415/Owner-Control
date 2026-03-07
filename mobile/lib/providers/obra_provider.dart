import 'package:flutter/foundation.dart';
import '../models/obra.dart';
import '../services/api_client.dart';

class ObraAtualProvider extends ChangeNotifier {
  ObraAtualProvider({this.api});

  final ApiClient? api;
  Obra? _obraAtual;

  Obra? get obraAtual => _obraAtual;
  bool get temObra => _obraAtual != null;

  void selecionarObra(Obra obra) {
    _obraAtual = obra;
    notifyListeners();
  }

  void limparObra() {
    _obraAtual = null;
    notifyListeners();
  }
}
