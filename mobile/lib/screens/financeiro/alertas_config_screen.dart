import "package:flutter/material.dart";

import "../../services/api_client.dart";

class AlertasConfigScreen extends StatefulWidget {
  const AlertasConfigScreen({
    super.key,
    required this.obraId,
    required this.api,
  });

  final String obraId;
  final ApiClient api;

  @override
  State<AlertasConfigScreen> createState() => _AlertasConfigScreenState();
}

class _AlertasConfigScreenState extends State<AlertasConfigScreen> {
  double _threshold = 15.0;
  bool _notificacaoAtiva = true;
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarConfig();
  }

  Future<void> _carregarConfig() async {
    try {
      final config = await widget.api.obterAlertaConfig(widget.obraId);
      if (mounted) {
        setState(() {
          _threshold = config.percentualDesvioThreshold.clamp(5.0, 50.0);
          _notificacaoAtiva = config.notificacaoAtiva;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await widget.api.salvarAlertaConfig(
        obraId: widget.obraId,
        percentualDesvioThreshold: _threshold,
        notificacaoAtiva: _notificacaoAtiva,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Configuracao salva com sucesso")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
  }

  Color _thresholdColor(double value) {
    if (value < 10) return Colors.green;
    if (value < 20) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _thresholdColor(_threshold);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Configurar Alertas"),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: color),
                              const SizedBox(width: 8),
                              Text(
                                "Limite de Desvio",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Voce sera alertado quando o desvio entre o "
                            "orcamento previsto e o realizado ultrapassar "
                            "este percentual.",
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                "${_threshold.toStringAsFixed(0)}%",
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Slider(
                            value: _threshold,
                            min: 5,
                            max: 50,
                            divisions: 45,
                            activeColor: color,
                            label: "${_threshold.toStringAsFixed(0)}%",
                            onChanged: (value) {
                              setState(() => _threshold = value);
                            },
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("5%",
                                    style: theme.textTheme.bodySmall),
                                Text("50%",
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: SwitchListTile(
                      title: const Text("Notificacoes ativas"),
                      subtitle: Text(
                        _notificacaoAtiva
                            ? "Voce recebera alertas quando o desvio "
                                "ultrapassar o limite"
                            : "Notificacoes desativadas",
                        style: theme.textTheme.bodySmall,
                      ),
                      secondary: Icon(
                        _notificacaoAtiva
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        color: _notificacaoAtiva
                            ? theme.colorScheme.primary
                            : Colors.grey,
                      ),
                      value: _notificacaoAtiva,
                      onChanged: (value) {
                        setState(() => _notificacaoAtiva = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _salvando ? null : _salvar,
                    icon: _salvando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label:
                        Text(_salvando ? "Salvando..." : "Salvar Configuracao"),
                  ),
                ],
              ),
            ),
    );
  }
}
