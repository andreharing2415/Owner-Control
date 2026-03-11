import "dart:io";
import "package:flutter/material.dart";
import "package:flutter/services.dart" show FilteringTextInputFormatter;
import "package:open_filex/open_filex.dart";
import "package:path_provider/path_provider.dart";

import "package:provider/provider.dart";

import "../../models/convite.dart";
import "../../models/etapa.dart";
import "../../models/obra.dart";
import "../../providers/auth_provider.dart";
import "../../services/api_client.dart";
import "../checklist/checklist_screen.dart";
import "../normas/normas_screen.dart";
import "../financeiro/lancar_despesa_screen.dart";
import "../visual_ai/visual_ai_screen.dart";

const _statusEtapaLabels = {
  "pendente": "Pendente",
  "em_andamento": "Em andamento",
  "concluida": "Concluída",
};

class EtapasScreen extends StatefulWidget {
  const EtapasScreen({super.key, required this.obra, required this.api});

  final Obra obra;
  final ApiClient api;

  @override
  State<EtapasScreen> createState() => _EtapasScreenState();
}

class _EtapasScreenState extends State<EtapasScreen> {
  late Future<List<Etapa>> _etapasFuture;
  bool _exportando = false;

  @override
  void initState() {
    super.initState();
    _etapasFuture = widget.api.listarEtapas(widget.obra.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _etapasFuture = widget.api.listarEtapas(widget.obra.id);
    });
  }

  Future<void> _exportarPdf() async {
    setState(() => _exportando = true);
    try {
      final bytes = await widget.api.exportarPdf(widget.obra.id);
      final tempDir = await getTemporaryDirectory();
      final file = File("${tempDir.path}/obra-${widget.obra.id}.pdf");
      await file.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro ao exportar: $e")));
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _atualizarStatus(Etapa etapa) async {
    final statusOptions = _statusEtapaLabels.entries.toList();
    final novoStatus = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text("Status: ${etapa.nome}"),
        children: statusOptions.map((entry) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, entry.key),
            child: Text(entry.value),
          );
        }).toList(),
      ),
    );
    if (novoStatus != null && novoStatus != etapa.status) {
      try {
        await widget.api
            .atualizarStatusEtapa(etapaId: etapa.id, status: novoStatus);
        await _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Erro: $e")));
        }
      }
    }
  }

  void _mostrarComentarios(Etapa etapa) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ComentariosSheet(
        etapaId: etapa.id,
        etapaNome: etapa.nome,
        api: widget.api,
      ),
    );
  }

  Future<void> _mostrarDetalhamento() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => _DetalhamentoSheet(
          api: widget.api,
          obraId: widget.obra.id,
          scrollController: scrollController,
        ),
      ),
    );
  }

  Future<void> _editarFinanceiro(Etapa etapa) async {
    final previstoCtrl = TextEditingController(
      text: etapa.valorPrevisto?.toStringAsFixed(0) ?? "",
    );
    final gastoCtrl = TextEditingController(
      text: etapa.valorGasto?.toStringAsFixed(0) ?? "",
    );

    final salvar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Financeiro — ${etapa.nome}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: previstoCtrl,
              decoration: const InputDecoration(
                labelText: "Valor Previsto (R\$)",
                prefixText: "R\$ ",
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[\d.,]"))],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gastoCtrl,
              decoration: const InputDecoration(
                labelText: "Valor Gasto (R\$)",
                prefixText: "R\$ ",
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[\d.,]"))],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Salvar"),
            ),
          ],
        ),
      ),
    );

    if (salvar != true) return;

    final previsto = double.tryParse(
        previstoCtrl.text.replaceAll(".", "").replaceAll(",", ".").trim());
    final gasto = double.tryParse(
        gastoCtrl.text.replaceAll(".", "").replaceAll(",", ".").trim());

    previstoCtrl.dispose();
    gastoCtrl.dispose();

    try {
      await widget.api.salvarOrcamento(widget.obra.id, [
        {
          "etapa_id": etapa.id,
          "valor_previsto": previsto ?? 0,
          "valor_realizado": gasto ?? 0,
        },
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Financeiro atualizado")),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
  }

  Widget _buildOrcamentoBar(Etapa etapa) {
    if (etapa.valorPrevisto == null || etapa.valorPrevisto! <= 0) {
      return GestureDetector(
        onTap: () => _editarFinanceiro(etapa),
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text("Definir orçamento",
              style: TextStyle(fontSize: 12, color: Colors.blue[600])),
        ),
      );
    }
    final pct = (etapa.valorGasto ?? 0) / etapa.valorPrevisto!;
    final estourado = pct > 1.0;
    return GestureDetector(
      onTap: () => _editarFinanceiro(etapa),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
              color: estourado ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 4),
            Text(
              "R\$ ${(etapa.valorGasto ?? 0).toStringAsFixed(0)} / R\$ ${etapa.valorPrevisto!.toStringAsFixed(0)}",
              style: TextStyle(
                fontSize: 12,
                color: estourado ? Colors.red : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "concluida":
        return Colors.green;
      case "em_andamento":
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.obra.nome),
        actions: [
          IconButton(
            onPressed: _mostrarDetalhamento,
            icon: const Icon(Icons.home_outlined),
            tooltip: "Detalhes da casa",
          ),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          _exportando
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child:
                          CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  onPressed: _exportarPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: "Exportar PDF"),
        ],
      ),
      body: FutureBuilder<List<Etapa>>(
        future: _etapasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text("Erro: ${snapshot.error}", textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text("Tentar novamente"),
                    ),
                  ],
                ),
              ),
            );
          }
          final etapas = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: etapas.length,
              itemBuilder: (context, index) {
                final etapa = etapas[index];
                final scoreStr = etapa.score != null
                    ? "${etapa.score!.toStringAsFixed(0)}%"
                    : "\u2014";
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          _statusColor(etapa.status).withValues(alpha: 0.15),
                      child: Text(
                        "${etapa.ordem}",
                        style: TextStyle(
                          color: _statusColor(etapa.status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(etapa.nome,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _statusColor(etapa.status)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _statusEtapaLabels[etapa.status] ?? etapa.status,
                                style: TextStyle(
                                    color: _statusColor(etapa.status),
                                    fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text("Score: $scoreStr",
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        _buildOrcamentoBar(etapa),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) async {
                        switch (value) {
                          case "checklist":
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ChecklistScreen(
                                      etapa: etapa, api: widget.api)),
                            ).then((_) => _refresh());
                          case "status":
                            _atualizarStatus(etapa);
                          case "normas":
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NormasScreen(
                                    api: widget.api,
                                    etapaInicial: etapa.nome),
                              ),
                            );
                          case "visual_ai":
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VisualAiScreen(
                                    etapa: etapa, api: widget.api),
                              ),
                            );
                          case "comentarios":
                            _mostrarComentarios(etapa);
                          case "despesa":
                            final adicionou = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LancarDespesaScreen(
                                  api: widget.api,
                                  obraId: widget.obra.id,
                                  etapaId: etapa.id,
                                  etapaNome: etapa.nome,
                                ),
                              ),
                            );
                            if (adicionou == true) _refresh();
                        }
                      },
                      itemBuilder: (context) {
                        final isConvidado = context.read<AuthProvider>().user?.isConvidado ?? false;
                        return [
                          const PopupMenuItem(
                              value: "checklist",
                              child: Text("Ver checklist")),
                          const PopupMenuItem(
                              value: "status",
                              child: Text("Atualizar status")),
                          const PopupMenuItem(
                            value: "comentarios",
                            child: Row(
                              children: [
                                Icon(Icons.comment_outlined, size: 18),
                                SizedBox(width: 8),
                                Text("Comentários"),
                              ],
                            ),
                          ),
                          if (!isConvidado) ...[
                            const PopupMenuItem(
                              value: "despesa",
                              child: Row(
                                children: [
                                  Icon(Icons.attach_money, size: 18),
                                  SizedBox(width: 8),
                                  Text("Lançar despesa"),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: "normas",
                              child: Row(
                                children: [
                                  Icon(Icons.menu_book_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text("Normas aplicáveis"),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: "visual_ai",
                              child: Row(
                                children: [
                                  Icon(Icons.camera_enhance, size: 18),
                                  SizedBox(width: 8),
                                  Text("Análise Visual IA"),
                                ],
                              ),
                            ),
                          ],
                        ];
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ChecklistScreen(
                                etapa: etapa, api: widget.api)),
                      ).then((_) => _refresh());
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ─── Comentários Bottom Sheet ─────────────────────────────────────────────

class _ComentariosSheet extends StatefulWidget {
  const _ComentariosSheet({
    required this.etapaId,
    required this.etapaNome,
    required this.api,
  });

  final String etapaId;
  final String etapaNome;
  final ApiClient api;

  @override
  State<_ComentariosSheet> createState() => _ComentariosSheetState();
}

class _ComentariosSheetState extends State<_ComentariosSheet> {
  final _textCtrl = TextEditingController();
  List<EtapaComentario> _comentarios = [];
  bool _loading = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final lista = await widget.api.listarComentarios(widget.etapaId);
      if (mounted) setState(() { _comentarios = lista; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enviar() async {
    final texto = _textCtrl.text.trim();
    if (texto.isEmpty) return;

    setState(() => _enviando = true);
    try {
      final novo = await widget.api.criarComentario(
        etapaId: widget.etapaId,
        texto: texto,
      );
      _textCtrl.clear();
      if (mounted) {
        setState(() {
          _comentarios.insert(0, novo);
          _enviando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _enviando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.comment_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Comentários — ${widget.etapaNome}",
                      style: Theme.of(context).textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            // List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _comentarios.isEmpty
                      ? Center(
                          child: Text(
                            "Nenhum comentário ainda",
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _comentarios.length,
                          itemBuilder: (context, index) {
                            final c = _comentarios[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    child: Text(
                                      c.userNome.isNotEmpty
                                          ? c.userNome[0].toUpperCase()
                                          : "?",
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.userNome.isNotEmpty
                                              ? c.userNome
                                              : "Usuário",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(c.texto,
                                            style:
                                                const TextStyle(fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            // Input
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                8,
                8 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      decoration: const InputDecoration(
                        hintText: "Escreva um comentário...",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _enviar(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _enviando ? null : _enviar,
                    icon: _enviando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}


class _DetalhamentoSheet extends StatefulWidget {
  const _DetalhamentoSheet({
    required this.api,
    required this.obraId,
    required this.scrollController,
  });

  final ApiClient api;
  final String obraId;
  final ScrollController scrollController;

  @override
  State<_DetalhamentoSheet> createState() => _DetalhamentoSheetState();
}

class _DetalhamentoSheetState extends State<_DetalhamentoSheet> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _extracting = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final data = await widget.api.getDetalhamento(widget.obraId);
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _erro = "$e"; });
    }
  }

  Future<void> _extrair() async {
    setState(() { _extracting = true; _erro = null; });
    try {
      final data = await widget.api.extrairDetalhamento(widget.obraId);
      if (mounted) setState(() { _data = data; _extracting = false; });
    } catch (e) {
      if (mounted) setState(() { _extracting = false; _erro = "$e"; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comodos = (_data?["comodos"] as List<dynamic>?) ?? [];
    final areaTotal = _data?["area_total_m2"] as double?;
    final fonteDoc = _data?["fonte_doc_nome"] as String?;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.home_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text("Detalhes da Casa", style: theme.textTheme.titleLarge),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (_erro != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_erro!, style: const TextStyle(color: Colors.red)),
                      ),

                    // Area total
                    if (areaTotal != null)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.square_foot, color: Colors.blue),
                          title: Text("${areaTotal.toStringAsFixed(1)} m²"),
                          subtitle: const Text("Área total"),
                        ),
                      ),

                    // Fonte
                    if (fonteDoc != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text("Fonte: $fonteDoc",
                            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ),

                    // Cômodos
                    if (comodos.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text("Cômodos (${comodos.length})",
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...comodos.map((c) {
                        final nome = c["nome"] as String? ?? "—";
                        final area = c["area_m2"] as num?;
                        return Card(
                          child: ListTile(
                            dense: true,
                            title: Text(nome),
                            trailing: area != null
                                ? Text("${area.toStringAsFixed(1)} m²",
                                    style: const TextStyle(fontWeight: FontWeight.w600))
                                : null,
                          ),
                        );
                      }),
                    ],

                    if (comodos.isEmpty && areaTotal == null) ...[
                      const SizedBox(height: 32),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.home_work_outlined,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text("Nenhum detalhamento extraído"),
                            const SizedBox(height: 8),
                            Text(
                              "Envie documentos do projeto e clique em extrair para a IA identificar cômodos e metragens.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _extracting ? null : _extrair,
                      icon: _extracting
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(_extracting
                          ? "Extraindo..."
                          : comodos.isEmpty
                              ? "Extrair detalhamento com IA"
                              : "Atualizar detalhamento"),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
        ),
      ],
    );
  }
}
