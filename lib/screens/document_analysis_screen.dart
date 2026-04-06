import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api.dart';
import 'detalhe_risco_screen.dart';
import 'pdf_viewer_screen.dart';
import 'riscos_review_screen.dart';
import '../utils/auth_error_handler.dart';

class DocumentAnalysisScreen extends StatefulWidget {
  const DocumentAnalysisScreen({super.key, required this.projeto});

  final ProjetoDoc projeto;

  @override
  State<DocumentAnalysisScreen> createState() => _DocumentAnalysisScreenState();
}

class _DocumentAnalysisScreenState extends State<DocumentAnalysisScreen> {
  final ApiClient _api = ApiClient();

  late ProjetoDoc _projeto;
  Future<ProjetoAnalise>? _analiseFuture;
  bool _disparando = false;

  // Polling de geração unificada (AI-06)
  GeracaoUnificadaLog? _geracaoLog;
  Timer? _pollingTimer;
  static const _pollingInterval = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _projeto = widget.projeto;
    if (_projeto.status == 'concluido') {
      _analiseFuture = _api.obterAnalise(_projeto.id);
    }
  }

  @override
  void dispose() {
    // Ao sair da tela, cancela o polling — o backend detecta a desconexão SSE
    // (AI-07) e interrompe o processamento background para evitar consumo ocioso.
    _stopPolling();
    super.dispose();
  }

  void _startPolling(GeracaoUnificadaLog log) {
    setState(() => _geracaoLog = log);
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) => _pollStatus());
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _pollStatus() async {
    final log = _geracaoLog;
    if (log == null) return;
    try {
      final atualizado = await _api.statusGeracaoUnificada(log.obraId, log.id);
      if (!mounted) return;
      setState(() => _geracaoLog = atualizado);
      if (atualizado.isTerminal) {
        _stopPolling();
      }
    } catch (_) {
      // Falha de rede no polling é ignorada silenciosamente — tentará no próximo tick
    }
  }

  Future<void> _dispararAnalise() async {
    setState(() => _disparando = true);
    try {
      await _api.dispararAnalise(_projeto.id);
      final atualizado = await _api.aguardarAnalise(_projeto.id);
      if (!mounted) return;
      setState(() {
        _projeto = atualizado;
        if (atualizado.status == 'concluido') {
          _analiseFuture = _api.obterAnalise(_projeto.id);
        }
        _disparando = false;
      });
    } catch (e) {
      if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
      if (!mounted) return;
      setState(() => _disparando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao analisar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_projeto.arquivoNome, overflow: TextOverflow.ellipsis),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Visualizar PDF',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PdfViewerScreen(
                  url: _projeto.arquivoUrl,
                  titulo: _projeto.arquivoNome,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // ─── Info do projeto ─────────────────────────────────────
          _ProjetoInfoCard(projeto: _projeto, formatDate: _formatDate),
          const SizedBox(height: 16),

          // ─── Status de geração unificada (polling AI-06) ──────────
          if (_geracaoLog != null) ...[
            _GeracaoUnificadaStatusCard(log: _geracaoLog!),
            const SizedBox(height: 16),
          ],

          // ─── Botão ou resultado de análise ───────────────────────
          if (_projeto.status == 'pendente' || _projeto.status == 'erro') ...[
            _AnalisarCard(
              status: _projeto.status,
              erroDetalhe: _projeto.erroDetalhe,
              disparando: _disparando,
              onAnalisar: _dispararAnalise,
            ),
          ] else if (_projeto.status == 'processando') ...[
            const _ProcessandoCard(),
          ] else if (_projeto.status == 'concluido') ...[
            FutureBuilder<ProjetoAnalise>(
              future: _analiseFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text('Erro: ${snap.error}',
                        style: const TextStyle(color: Colors.red)),
                  );
                }
                return _AnaliseResultado(analise: snap.data!);
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Card de info do projeto ──────────────────────────────────────────────────

class _ProjetoInfoCard extends StatelessWidget {
  const _ProjetoInfoCard(
      {required this.projeto, required this.formatDate});

  final ProjetoDoc projeto;
  final String Function(String) formatDate;

  (String, Color) get _statusStyle => switch (projeto.status) {
        'concluido' => ('Análise concluída', Colors.green),
        'processando' => ('Analisando...', Colors.blue),
        'erro' => ('Erro na análise', Colors.red),
        _ => ('Aguardando análise', Colors.orange),
      };

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _statusStyle;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined,
                    size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                const Text(
                  'Informações do Projeto',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const Divider(height: 20),
            _InfoRow(label: 'Arquivo', value: projeto.arquivoNome),
            _InfoRow(
                label: 'Enviado em',
                value: formatDate(projeto.createdAt)),
            _InfoRow(
              label: 'Status',
              valueWidget: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card para disparar análise ───────────────────────────────────────────────

class _AnalisarCard extends StatelessWidget {
  const _AnalisarCard({
    required this.status,
    this.erroDetalhe,
    required this.disparando,
    required this.onAnalisar,
  });

  final String status;
  final String? erroDetalhe;
  final bool disparando;
  final VoidCallback onAnalisar;

  @override
  Widget build(BuildContext context) {
    final isErro = status == 'erro';
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              isErro ? Icons.warning_amber_rounded : Icons.auto_awesome,
              size: 40,
              color: isErro ? Colors.red : Colors.indigo,
            ),
            const SizedBox(height: 12),
            Text(
              isErro
                  ? 'A análise anterior falhou. Tente novamente.'
                  : 'Pronto para analisar este projeto com IA.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isErro ? Colors.red : Colors.grey[700],
                fontSize: 13,
              ),
            ),
            if (isErro && erroDetalhe != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  erroDetalhe!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.red),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: disparando ? null : onAnalisar,
              icon: disparando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                  disparando ? 'Analisando...' : 'Analisar com IA'),
            ),
            const SizedBox(height: 10),
            Text(
              'A análise pode levar alguns segundos.',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card de "processando" ────────────────────────────────────────────────────

class _ProcessandoCard extends StatelessWidget {
  const _ProcessandoCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Análise em andamento...',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 4),
            Text(
              'Recarregue a tela em alguns instantes.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Resultado da análise ─────────────────────────────────────────────────────

class _AnaliseResultado extends StatelessWidget {
  const _AnaliseResultado({required this.analise});

  final ProjetoAnalise analise;

  @override
  Widget build(BuildContext context) {
    final riscos = analise.riscos;
    final altos = riscos.where((r) => r.severidade == 'alto').length;
    final medios = riscos.where((r) => r.severidade == 'medio').length;
    final baixos = riscos.where((r) => r.severidade == 'baixo').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Resumo geral
        if (analise.projeto.resumoGeral != null) ...[
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 18,
                          color:
                              Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Resumo da Análise',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    analise.projeto.resumoGeral!,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Contadores de severidade
        Row(
          children: [
            _SeveridadeChip(label: '$altos Alto', color: Colors.red),
            const SizedBox(width: 8),
            _SeveridadeChip(
                label: '$medios Médio', color: Colors.orange),
            const SizedBox(width: 8),
            _SeveridadeChip(
                label: '$baixos Baixo', color: Colors.green),
          ],
        ),
        const SizedBox(height: 12),

        // Ações
        if (riscos.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RiscosReviewScreen(
                        obraId: analise.projeto.obraId,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.playlist_add_check, size: 18),
                  label: const Text('Aplicar Riscos'),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),

        // Lista de riscos
        if (riscos.isEmpty)
          const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Nenhum risco identificado neste documento.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          )
        else
          ...riscos.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RiscoTile(risco: r),
            ),
          ),

        // Aviso legal
        if (analise.projeto.avisoLegal != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.30)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: Colors.amber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    analise.projeto.avisoLegal!,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Tile de Risco ────────────────────────────────────────────────────────────

class _RiscoTile extends StatelessWidget {
  const _RiscoTile({required this.risco});

  final Risco risco;

  (Color, IconData) get _sev => switch (risco.severidade) {
        'alto' => (Colors.red, Icons.warning_rounded),
        'medio' => (Colors.orange, Icons.warning_amber_rounded),
        _ => (Colors.green, Icons.info_outline),
      };

  String get _sevLabel => switch (risco.severidade) {
        'alto' => 'Alto',
        'medio' => 'Médio',
        _ => 'Baixo',
      };

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _sev;

    return Card(
      elevation: 0,
      clipBehavior: Clip.hardEdge,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.10),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          risco.traducaoLeigo,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: risco.normaReferencia != null
            ? Text(
                risco.normaReferencia!,
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _sevLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right,
                size: 16, color: Colors.grey),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalheRiscoScreen(risco: risco),
          ),
        ),
      ),
    );
  }
}

// ─── Chip de severidade ───────────────────────────────────────────────────────

class _SeveridadeChip extends StatelessWidget {
  const _SeveridadeChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Card de status de geração unificada (polling AI-06) ─────────────────────

class _GeracaoUnificadaStatusCard extends StatelessWidget {
  const _GeracaoUnificadaStatusCard({required this.log});

  final GeracaoUnificadaLog log;

  (String, Color, IconData) get _statusStyle => switch (log.status) {
        'concluido' => ('Geração concluída', Colors.green, Icons.check_circle_outline),
        'erro' => ('Falha na geração', Colors.red, Icons.error_outline),
        'cancelado' => ('Geração cancelada', Colors.orange, Icons.cancel_outlined),
        'analisando' => ('Analisando documentos...', Colors.blue, Icons.search),
        'gerando' => ('Gerando cronograma e checklist...', Colors.indigo, Icons.auto_awesome),
        _ => ('Aguardando início...', Colors.grey, Icons.hourglass_empty),
      };

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _statusStyle;
    final emAndamento = !log.isTerminal;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: color,
                    ),
                  ),
                ),
                if (emAndamento)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (log.etapaAtual != null) ...[
              const SizedBox(height: 6),
              Text(
                log.etapaAtual!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            if (log.totalAtividades > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: log.totalAtividades > 0
                    ? log.atividadesGeradas / log.totalAtividades
                    : null,
                color: color,
              ),
              const SizedBox(height: 4),
              Text(
                '${log.atividadesGeradas} de ${log.totalAtividades} atividades',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
            if (log.status == 'concluido' && log.totalItensChecklist > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${log.totalItensChecklist} itens de checklist gerados',
                style: const TextStyle(fontSize: 11, color: Colors.green),
              ),
            ],
            if (log.erroDetalhe != null) ...[
              const SizedBox(height: 8),
              Text(
                log.erroDetalhe!,
                style: const TextStyle(fontSize: 11, color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Helper ───────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.value, this.valueWidget});

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 12)),
          ),
          Expanded(
            child: valueWidget ??
                Text(
                  value ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                ),
          ),
        ],
      ),
    );
  }
}
