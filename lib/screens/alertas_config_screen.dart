import 'package:flutter/material.dart';

import '../api/api.dart';
import '../utils/auth_error_handler.dart';

class AlertasConfigScreen extends StatefulWidget {
  const AlertasConfigScreen({
    super.key,
    required this.obra,
    required this.thresholdAtual,
  });

  final Obra obra;
  final double thresholdAtual;

  @override
  State<AlertasConfigScreen> createState() => _AlertasConfigScreenState();
}

class _AlertasConfigScreenState extends State<AlertasConfigScreen> {
  final ApiClient _api = ApiClient();
  late double _threshold;
  bool _notificacaoAtiva = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _threshold = widget.thresholdAtual.clamp(5.0, 50.0);
  }

  Future<void> _salvar() async {
    setState(() => _loading = true);
    try {
      await _api.configurarAlertas(
        obraId: widget.obra.id,
        percentualDesvioThreshold: _threshold,
        notificacaoAtiva: _notificacaoAtiva,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurações de alerta salvas!')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color get _thresholdColor {
    if (_threshold <= 10) return Colors.green;
    if (_threshold <= 20) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Alertas'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ─── Obra selecionada ──────────────────────────────────────
          Card(
            elevation: 0,
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            child: ListTile(
              leading: const Icon(Icons.home_work_outlined),
              title: const Text(
                'Obra',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              subtitle: Text(
                widget.obra.nome,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ─── Threshold ────────────────────────────────────────────
          const Text(
            'Limite de Desvio para Alerta',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Um alerta será exibido quando o gasto ultrapassar o orçamento previsto além do percentual abaixo.',
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Slider
          Row(
            children: [
              const Text('5%',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Expanded(
                child: Slider(
                  value: _threshold,
                  min: 5,
                  max: 50,
                  divisions: 9,
                  label: '${_threshold.toStringAsFixed(0)}%',
                  activeColor: _thresholdColor,
                  onChanged: (v) => setState(() => _threshold = v),
                ),
              ),
              const Text('50%',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),

          // Badge de limite
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _thresholdColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: _thresholdColor.withValues(alpha: 0.30)),
              ),
              child: Text(
                'Alerta em ${_threshold.toStringAsFixed(0)}% de desvio',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _thresholdColor,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Descrição contextual do nível
          Center(
            child: Text(
              _threshold <= 10
                  ? 'Sensibilidade alta — alerta precoce'
                  : _threshold <= 20
                      ? 'Sensibilidade moderada'
                      : 'Sensibilidade baixa — apenas grandes desvios',
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade500),
            ),
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 8),

          // ─── Toggle notificação ───────────────────────────────────
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Exibir alertas no app'),
            subtitle: const Text(
              'Destaca visualmente etapas e totais com desvio acima do limite',
              style: TextStyle(fontSize: 12),
            ),
            value: _notificacaoAtiva,
            onChanged: (v) => setState(() => _notificacaoAtiva = v),
          ),

          const SizedBox(height: 32),

          // ─── Botão salvar ─────────────────────────────────────────
          FilledButton(
            onPressed: _loading ? null : _salvar,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Salvar Configurações'),
          ),
        ],
      ),
    );
  }
}
