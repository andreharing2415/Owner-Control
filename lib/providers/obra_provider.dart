import 'package:flutter/foundation.dart';
import '../api/api.dart';

/// Guarda a obra atualmente selecionada pelo usuário no HomeScreen.
class ObraAtualProvider extends ChangeNotifier {
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
