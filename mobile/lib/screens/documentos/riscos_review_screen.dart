import "package:flutter/material.dart";

import "../../services/api_client.dart";

class RiscosReviewScreen extends StatefulWidget {
  const RiscosReviewScreen({
    super.key,
    required this.api,
    required this.obraId,
  });

  final ApiClient api;
  final String obraId;

  @override
  State<RiscosReviewScreen> createState() => _RiscosReviewScreenState();
}

class _RiscosReviewScreenState extends State<RiscosReviewScreen> {
  List<Map<String, dynamic>> _riscos = [];
  final Set<String> _selecionados = {};
  bool _loading = true;
  bool _aplicando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarRiscos();
  }

  Future<void> _carregarRiscos() async {
    try {
      final result = await widget.api.listarRiscosPendentes(widget.obraId);
      final riscos = (result["riscos"] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
      if (mounted) {
        setState(() {
          _riscos = riscos;
          _selecionados.addAll(riscos.map((r) => r["id"] as String));
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _aplicar() async {
    setState(() => _aplicando = true);
    try {
      final criados = await widget.api.aplicarRiscos(
        widget.obraId,
        _selecionados.toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$criados itens adicionados ao checklist"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e")),
        );
        setState(() => _aplicando = false);
      }
    }
  }

  Widget _severidadeBadge(String? severidade) {
    final Color cor;
    final String label;
    switch (severidade) {
      case "alto":
        cor = Colors.red;
        label = "ALTO";
      case "medio":
        cor = Colors.orange;
        label = "MÉDIO";
      default:
        cor = Colors.blue;
        label = "BAIXO";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Riscos Identificados"),
        actions: [
          if (_riscos.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selecionados.length == _riscos.length) {
                    _selecionados.clear();
                  } else {
                    _selecionados.addAll(
                      _riscos.map((r) => r["id"] as String),
                    );
                  }
                });
              },
              child: Text(
                _selecionados.length == _riscos.length
                    ? "Desmarcar todos"
                    : "Selecionar todos",
              ),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _riscos.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed:
                      _selecionados.isEmpty || _aplicando ? null : _aplicar,
                  child: _aplicando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          "Aplicar ${_selecionados.length} ao checklist",
                        ),
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text("Erro: $_erro", textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _erro = null;
                  });
                  _carregarRiscos();
                },
                child: const Text("Tentar novamente"),
              ),
            ],
          ),
        ),
      );
    }
    if (_riscos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text("Nenhum risco pendente"),
            SizedBox(height: 8),
            Text("Todos os riscos já foram aplicados ao checklist."),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _riscos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (ctx, i) {
        final risco = _riscos[i];
        final id = risco["id"] as String;
        final selecionado = _selecionados.contains(id);
        return Card(
          elevation: selecionado ? 2 : 0,
          child: CheckboxListTile(
            value: selecionado,
            onChanged: (v) => setState(() {
              v == true
                  ? _selecionados.add(id)
                  : _selecionados.remove(id);
            }),
            title: Text(
              risco["descricao"] as String,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (risco["traducao_leigo"] != null)
                  Text(
                    risco["traducao_leigo"] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _severidadeBadge(risco["severidade"] as String?),
                    const SizedBox(width: 8),
                    if (risco["norma_referencia"] != null)
                      Expanded(
                        child: Text(
                          risco["norma_referencia"] as String,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  risco["documento_nome"] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            isThreeLine: true,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        );
      },
    );
  }
}
