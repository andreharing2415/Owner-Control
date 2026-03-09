import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

import "../../models/documento.dart";
import "../../services/api_client.dart";
import "registrar_verificacao_screen.dart";

class DetalheRiscoScreen extends StatefulWidget {
  const DetalheRiscoScreen({
    super.key,
    required this.risco,
    required this.api,
  });

  final Risco risco;
  final ApiClient api;

  @override
  State<DetalheRiscoScreen> createState() => _DetalheRiscoScreenState();
}

class _DetalheRiscoScreenState extends State<DetalheRiscoScreen> {
  late Risco _risco;

  @override
  void initState() {
    super.initState();
    _risco = widget.risco;
  }

  Color _severidadeColor(String severidade) {
    switch (severidade) {
      case "alto":
        return Colors.red;
      case "medio":
        return Colors.orange;
      case "baixo":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _severidadeLabel(String severidade) {
    switch (severidade) {
      case "alto":
        return "Alto";
      case "medio":
        return "Médio";
      case "baixo":
        return "Baixo";
      default:
        return severidade;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case "conforme":
        return Colors.green;
      case "divergente":
        return Colors.red;
      case "duvida":
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case "conforme":
        return "Conforme";
      case "divergente":
        return "Divergente";
      case "duvida":
        return "Dúvida";
      default:
        return "Pendente";
    }
  }

  Future<void> _abrirNormaUrl(BuildContext context) async {
    if (_risco.normaUrl == null) return;
    final uri = Uri.tryParse(_risco.normaUrl!);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Não foi possível abrir o link.")),
      );
    }
  }

  Future<void> _abrirVerificacao() async {
    final resultado = await Navigator.push<Risco>(
      context,
      MaterialPageRoute(
        builder: (_) => RegistrarVerificacaoScreen(
          risco: _risco,
          api: widget.api,
        ),
      ),
    );
    if (resultado != null && mounted) {
      setState(() {
        _risco = resultado;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _severidadeColor(_risco.severidade);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalhe do Risco"),
      ),
      floatingActionButton: _risco.verificacoes != null &&
              _risco.verificacoes!.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _abrirVerificacao,
              icon: const Icon(Icons.checklist),
              label: Text(
                _risco.statusVerificacao == "pendente"
                    ? "Verificar na Obra"
                    : "Atualizar Verificação",
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header: Severidade + Status
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield, size: 16, color: color),
                    const SizedBox(width: 6),
                    Text(
                      _severidadeLabel(_risco.severidade),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(_risco.statusVerificacao)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _statusLabel(_risco.statusVerificacao),
                  style: TextStyle(
                    color: _statusColor(_risco.statusVerificacao),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              if (_risco.requerValidacaoProfissional)
                const Icon(Icons.warning, size: 20, color: Colors.orange),
            ],
          ),
          const SizedBox(height: 20),

          // Descrição técnica
          Text(
            _risco.descricao,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),

          // Explicação simplificada
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _risco.traducaoLeigo,
              style: TextStyle(
                color: Colors.indigo[700],
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ══════════════════════════════════════════════════════════
          // BLOCO 1 — O que o projeto diz
          // ══════════════════════════════════════════════════════════
          if (_risco.dadoProjeto != null) ...[
            _buildSection(
              context,
              icon: Icons.architecture,
              iconColor: Colors.teal,
              title: "O que o projeto diz",
              bgColor: Colors.teal.withValues(alpha: 0.06),
              borderColor: Colors.teal.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_risco.dadoProjeto!["descricao"] != null)
                    Text(
                      _risco.dadoProjeto!["descricao"],
                      style: TextStyle(
                        color: Colors.teal[900],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  if (_risco.dadoProjeto!["especificacao"] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.straighten,
                            size: 16, color: Colors.teal[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _risco.dadoProjeto!["especificacao"],
                            style: TextStyle(
                                color: Colors.teal[800], fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_risco.dadoProjeto!["fonte"] != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.source, size: 14, color: Colors.teal[400]),
                        const SizedBox(width: 6),
                        Text(
                          _risco.dadoProjeto!["fonte"],
                          style: TextStyle(
                            color: Colors.teal[600],
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ══════════════════════════════════════════════════════════
          // BLOCO 2 — Verifique na obra
          // ══════════════════════════════════════════════════════════
          if (_risco.verificacoes != null &&
              _risco.verificacoes!.isNotEmpty) ...[
            _buildSection(
              context,
              icon: Icons.checklist_rtl,
              iconColor: Colors.blue,
              title: "Verifique na obra",
              bgColor: Colors.blue.withValues(alpha: 0.06),
              borderColor: Colors.blue.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _risco.verificacoes!.map((v) {
                  final tipo = v["tipo"] ?? "visual";
                  final iconMap = {
                    "medicao": Icons.straighten,
                    "visual": Icons.visibility,
                    "documento": Icons.description,
                  };
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(iconMap[tipo] ?? Icons.check,
                                size: 18, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                v["instrucao"] ?? "",
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (v["valor_esperado"] != null) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 26),
                            child: Text(
                              "Esperado: ${v["valor_esperado"]}",
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        if (v["como_medir"] != null) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 26),
                            child: Text(
                              v["como_medir"]!,
                              style: TextStyle(
                                color: Colors.blue[600],
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ══════════════════════════════════════════════════════════
          // BLOCO 3 — Se algo parecer diferente
          // ══════════════════════════════════════════════════════════
          if (_risco.perguntaEngenheiro != null) ...[
            _buildSection(
              context,
              icon: Icons.engineering,
              iconColor: Colors.deepPurple,
              title: "Se algo parecer diferente",
              bgColor: Colors.deepPurple.withValues(alpha: 0.06),
              borderColor: Colors.deepPurple.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_risco.perguntaEngenheiro!["contexto"] != null) ...[
                    Text(
                      _risco.perguntaEngenheiro!["contexto"],
                      style: TextStyle(
                        color: Colors.deepPurple[800],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 18, color: Colors.deepPurple[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '"${_risco.perguntaEngenheiro!["pergunta"] ?? ""}"',
                            style: TextStyle(
                              color: Colors.deepPurple[900],
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ══════════════════════════════════════════════════════════
          // Resultado do cruzamento (inline, se existir)
          // ══════════════════════════════════════════════════════════
          if (_risco.resultadoCruzamento != null) ...[
            _buildCruzamentoCard(context),
            const SizedBox(height: 16),
          ],

          // Norma referência
          if (_risco.normaReferencia != null) ...[
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _risco.normaUrl != null
                    ? () => _abrirNormaUrl(context)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.gavel,
                          size: 20, color: Colors.blueGrey),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_risco.normaReferencia!)),
                      if (_risco.normaUrl != null)
                        const Icon(Icons.open_in_new,
                            size: 16, color: Colors.blue),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Ação do proprietário (fallback para riscos sem 3 camadas)
          if (_risco.acaoProprietario != null &&
              _risco.dadoProjeto == null) ...[
            _buildSection(
              context,
              icon: Icons.task_alt,
              iconColor: Colors.green,
              title: "O que você deve fazer",
              bgColor: Colors.green.withValues(alpha: 0.08),
              borderColor: Colors.green.withValues(alpha: 0.3),
              child: Text(
                _risco.acaoProprietario!,
                style: TextStyle(
                  color: Colors.green[900],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Perguntas para profissional (fallback)
          if (_risco.perguntasParaProfissional != null &&
              _risco.perguntasParaProfissional!.isNotEmpty &&
              _risco.perguntaEngenheiro == null) ...[
            _buildSection(
              context,
              icon: Icons.help_outline,
              iconColor: Colors.blue,
              title: "Pergunte ao seu engenheiro",
              bgColor: Colors.blue.withValues(alpha: 0.08),
              borderColor: Colors.blue.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _risco.perguntasParaProfissional!.map((perg) {
                  final pergunta = perg["pergunta"] ?? "";
                  final respostaEsperada = perg["resposta_esperada"] ?? "";
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pergunta,
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (respostaEsperada.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: Text(
                              "Resposta esperada: $respostaEsperada",
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Documentos a exigir
          if (_risco.documentosAExigir != null &&
              _risco.documentosAExigir!.isNotEmpty) ...[
            _buildSection(
              context,
              icon: Icons.description,
              iconColor: Colors.purple,
              title: "Documentos a exigir",
              bgColor: Colors.purple.withValues(alpha: 0.08),
              borderColor: Colors.purple.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _risco.documentosAExigir!
                    .map((doc) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.article_outlined,
                                  size: 16, color: Colors.purple[600]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  doc,
                                  style: TextStyle(
                                    color: Colors.purple[900],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Confiança
          Row(
            children: [
              Text(
                "Confiança: ",
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _risco.confianca / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _risco.confianca >= 80
                          ? Colors.green
                          : _risco.confianca >= 50
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${_risco.confianca}%",
                style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Validação profissional
          if (_risco.requerValidacaoProfissional) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.engineering,
                      color: Colors.orange, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Validação Profissional Necessária",
                          style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.orange[800],
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Este risco deve ser avaliado por um profissional "
                          "habilitado antes de tomar qualquer decisão.",
                          style: TextStyle(color: Colors.orange[900]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 80), // espaço para FAB
        ],
      ),
    );
  }

  Widget _buildCruzamentoCard(BuildContext context) {
    final cruzamento = _risco.resultadoCruzamento!;
    final conclusao = cruzamento["conclusao"] ?? "duvida";
    final urgencia = cruzamento["urgencia"] ?? "media";

    final urgenciaColor = urgencia == "alta"
        ? Colors.red
        : urgencia == "media"
            ? Colors.orange
            : Colors.green;

    return _buildSection(
      context,
      icon: Icons.compare_arrows,
      iconColor: urgenciaColor,
      title: "Resultado da Verificação",
      bgColor: urgenciaColor.withValues(alpha: 0.06),
      borderColor: urgenciaColor.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(conclusao).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusLabel(conclusao).toUpperCase(),
              style: TextStyle(
                color: _statusColor(conclusao),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            cruzamento["resumo"] ?? "",
            style: TextStyle(color: urgenciaColor.shade900, fontSize: 14),
          ),
          if (cruzamento["acao"] != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.arrow_forward, size: 16, color: urgenciaColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    cruzamento["acao"],
                    style: TextStyle(
                      color: urgenciaColor.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color bgColor,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

extension on Color {
  Color get shade800 => HSLColor.fromColor(this).withLightness(0.3).toColor();
  Color get shade900 => HSLColor.fromColor(this).withLightness(0.2).toColor();
}
