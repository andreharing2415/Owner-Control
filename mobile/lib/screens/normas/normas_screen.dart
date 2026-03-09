import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../models/norma.dart";
import "../../providers/auth_provider.dart";
import "../../providers/subscription_provider.dart";
import "../../services/api_client.dart";
import "../subscription/paywall_screen.dart";
import "normas_historico_screen.dart";

const _etapasNormas = [
  "Planejamento e Projeto",
  "Preparacao do Terreno",
  "Fundacoes e Estrutura",
  "Alvenaria e Cobertura",
  "Instalacoes e Acabamentos",
  "Entrega e Pos-obra",
];

class NormasScreen extends StatefulWidget {
  const NormasScreen({super.key, this.etapaInicial, this.etapaId, required this.api});

  final String? etapaInicial;
  final String? etapaId;   // se fornecido, carrega normas do checklist desta etapa
  final ApiClient api;

  @override
  State<NormasScreen> createState() => _NormasScreenState();
}

class _NormasScreenState extends State<NormasScreen> {
  final _localController = TextEditingController();
  late String _etapaSelecionada;
  bool _buscando = false;
  NormaBuscarResponse? _resultado;
  String? _erro;
  List<String>? _normasChecklist;
  bool _carregandoNormasChecklist = false;

  @override
  void initState() {
    super.initState();
    _etapaSelecionada =
        widget.etapaInicial != null && _etapasNormas.contains(widget.etapaInicial)
            ? widget.etapaInicial!
            : _etapasNormas.first;
    if (widget.etapaId != null) {
      _carregarNormasChecklist();
    }
  }

  Future<void> _carregarNormasChecklist() async {
    setState(() => _carregandoNormasChecklist = true);
    try {
      final normas = await widget.api.listarNormasChecklist(widget.etapaId!);
      if (mounted) setState(() => _normasChecklist = normas);
    } catch (_) {
      // Falha silenciosa — não impede o uso da biblioteca
    } finally {
      if (mounted) setState(() => _carregandoNormasChecklist = false);
    }
  }

  @override
  void dispose() {
    _localController.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() {
      _buscando = true;
      _resultado = null;
      _erro = null;
    });
    try {
      final resp = await widget.api.buscarNormas(
        etapaNome: _etapaSelecionada,
        localizacao: _localController.text.trim().isEmpty
            ? null
            : _localController.text.trim(),
      );
      if (mounted) setState(() => _resultado = resp);
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final isConvidado = user?.isConvidado ?? false;

    // Convidado: completely blocked
    if (isConvidado) {
      return Scaffold(
        appBar: AppBar(title: const Text("Biblioteca Normativa")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text("Recurso indisponível",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  "A Biblioteca Normativa está disponível apenas para o proprietário da obra.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Biblioteca Normativa"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: "Histórico",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => NormasHistoricoScreen(api: widget.api)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Pesquise normas técnicas aplicáveis à sua obra",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _etapaSelecionada,
                  decoration: const InputDecoration(
                    labelText: "Etapa da obra",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _etapasNormas
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _etapaSelecionada = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _localController,
                  decoration: const InputDecoration(
                    labelText: "Localização (opcional, ex: São Paulo/SP)",
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _buscando ? null : _buscar,
                  icon: _buscando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                  label:
                      Text(_buscando ? "Pesquisando..." : "Pesquisar normas"),
                ),
              ],
            ),
          ),
          if (widget.etapaId != null) ...[
            if (_carregandoNormasChecklist)
              const LinearProgressIndicator(),
            if (_normasChecklist != null && _normasChecklist!.isNotEmpty)
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Normas identificadas nesta etapa",
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _normasChecklist!.map((norma) => ActionChip(
                        label: Text(norma, style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          _buscar();
                        },
                      )).toList(),
                    ),
                  ],
                ),
              ),
          ],
          Expanded(
            child: _buscando
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Consultando normas técnicas..."),
                        SizedBox(height: 4),
                        Text("Aguarde alguns segundos.",
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  )
                : _erro != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 48, color: Colors.red),
                              const SizedBox(height: 12),
                              Text("Erro na pesquisa:\n$_erro",
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                  onPressed: _buscar,
                                  child: const Text("Tentar novamente")),
                            ],
                          ),
                        ),
                      )
                    : _resultado == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.menu_book_outlined,
                                    size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  "Selecione a etapa e pesquise\nas normas aplicáveis",
                                  textAlign: TextAlign.center,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                          )
                        : _NormasResultadoView(
                            resultado: _resultado!,
                            maxResults: context.read<SubscriptionProvider>().normasResultsLimit,
                          ),
          ),
        ],
      ),
    );
  }
}

class _NormasResultadoView extends StatelessWidget {
  const _NormasResultadoView({required this.resultado, this.maxResults});

  final NormaBuscarResponse resultado;
  final int? maxResults;

  Color _confiancaColor(int nivel) {
    if (nivel >= 75) return Colors.green;
    if (nivel >= 50) return Colors.orange;
    return Colors.red;
  }

  Color _riscoColor(String? nivel) {
    switch (nivel) {
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

  @override
  Widget build(BuildContext context) {
    final totalNormas = resultado.normas.length;
    final isTruncated = maxResults != null && totalNormas > maxResults!;
    final normasVisiveis = isTruncated
        ? resultado.normas.take(maxResults!).toList()
        : resultado.normas;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.4),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "$totalNormas normas — ${resultado.etapaNome}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(resultado.resumoGeral),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_outlined,
                  size: 16, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(resultado.avisoLegal,
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text("Normas encontradas",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 6),
        ...normasVisiveis.map((norma) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: Text(norma.titulo,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))),
                        const SizedBox(width: 8),
                        _BadgeFonte(tipo: norma.fonteTipo),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.source_outlined,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "${norma.fonteNome}${norma.versao != null ? ' — ${norma.versao}' : ''}",
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ]),
                    if (norma.dataNorma != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text("Publicação: ${norma.dataNorma}",
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ),
                    const Divider(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("O que isso significa para você:",
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.indigo)),
                          const SizedBox(height: 4),
                          Text(norma.traducaoLeigo,
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    if (norma.trechoRelevante != null &&
                        norma.trechoRelevante!.isNotEmpty)
                      Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          title: const Text("Ver trecho técnico",
                              style: TextStyle(fontSize: 12)),
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(norma.trechoRelevante!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic)),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.bar_chart, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          "Confiança: ${norma.nivelConfianca}%",
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  _confiancaColor(norma.nivelConfianca),
                              fontWeight: FontWeight.w600),
                        ),
                        if (norma.riscoNivel != null) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _riscoColor(norma.riscoNivel)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Risco ${norma.riscoNivel}",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _riscoColor(norma.riscoNivel),
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (norma.requerValidacaoProfissional)
                          const Icon(Icons.engineering,
                              size: 16, color: Colors.orange),
                      ],
                    ),
                    if (norma.requerValidacaoProfissional)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                            "Recomenda-se validação por profissional habilitado.",
                            style: TextStyle(
                                fontSize: 11, color: Colors.orange)),
                      ),
                  ],
                ),
              ),
            )),
        // Upgrade banner when results are truncated
        if (isTruncated) ...[
          const SizedBox(height: 8),
          Card(
            color: Colors.amber.withValues(alpha: 0.1),
            child: InkWell(
              onTap: () => PaywallScreen.show(context,
                  message: "Veja todas as $totalNormas normas encontradas"),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Veja todas as normas",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Exibindo $maxResults de $totalNormas normas. Assine para ver todas.",
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (resultado.checklistDinamico.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text("Checklist gerado pela IA",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          ...resultado.checklistDinamico.map((item) => ListTile(
                dense: true,
                leading: Icon(
                  item.critico
                      ? Icons.priority_high
                      : Icons.check_box_outline_blank,
                  color: item.critico ? Colors.red : Colors.grey,
                  size: 18,
                ),
                title: Text(item.item, style: const TextStyle(fontSize: 13)),
                subtitle: item.normaReferencia != null
                    ? Text(item.normaReferencia!,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey))
                    : null,
              )),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _BadgeFonte extends StatelessWidget {
  const _BadgeFonte({required this.tipo});

  final String tipo;

  @override
  Widget build(BuildContext context) {
    final isOficial = tipo == "oficial";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOficial
            ? Colors.blue.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isOficial
                ? Colors.blue.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Text(
        isOficial ? "Oficial" : "Secundária",
        style: TextStyle(
            fontSize: 10,
            color: isOficial ? Colors.blue : Colors.grey[600],
            fontWeight: FontWeight.w600),
      ),
    );
  }
}
