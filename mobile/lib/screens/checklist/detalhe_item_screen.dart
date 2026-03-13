import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../../models/checklist_item.dart";
import "../../services/api_client.dart";
import "../normas/normas_screen.dart";
import "verificacao_inline_widget.dart";
import "../../utils/theme_helpers.dart";

class DetalheItemScreen extends StatefulWidget {
  const DetalheItemScreen({
    super.key,
    required this.item,
    required this.api,
    required this.etapaNome,
  });

  final ChecklistItem item;
  final ApiClient api;
  final String etapaNome;

  @override
  State<DetalheItemScreen> createState() => _DetalheItemScreenState();
}

class _DetalheItemScreenState extends State<DetalheItemScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  late ChecklistItem _item;
  late TextEditingController _obsController;
  late Future<List<dynamic>> _evidenciasFuture;
  bool _salvandoObs = false;
  bool _salvandoStatus = false;
  bool _mostrarFormVerificacao = false;
  bool _enriquecendo = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _obsController = TextEditingController(text: _item.observacao ?? "");
    _evidenciasFuture = widget.api.listarEvidencias(_item.id);
  }

  void _recarregarEvidencias() {
    setState(() {
      _evidenciasFuture = widget.api.listarEvidencias(_item.id);
    });
  }

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _atualizarStatus(String novoStatus) async {
    setState(() => _salvandoStatus = true);
    try {
      final atualizado = await widget.api.atualizarItem(
        itemId: _item.id,
        status: novoStatus,
      );
      if (mounted) setState(() => _item = atualizado);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    } finally {
      if (mounted) setState(() => _salvandoStatus = false);
    }
  }

  Future<void> _salvarObservacao() async {
    setState(() => _salvandoObs = true);
    try {
      final atualizado = await widget.api.atualizarItem(
        itemId: _item.id,
        observacao: _obsController.text.trim(),
      );
      if (mounted) {
        setState(() => _item = atualizado);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Observação salva.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    } finally {
      if (mounted) setState(() => _salvandoObs = false);
    }
  }

  Future<void> _enriquecerItem() async {
    setState(() => _enriquecendo = true);
    try {
      final enriched = await widget.api.enriquecerItem(_item.id);
      if (mounted) {
        setState(() => _item = enriched);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Item enriquecido com sucesso!")),
        );
      }
    } on FeatureGateException {
      // onFeatureGate callback already handled
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _enriquecendo = false);
    }
  }

  Future<void> _adicionarEvidencia() async {
    final opcao = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Adicionar evidência"),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "camera"),
            child: const Row(children: [
              Icon(Icons.camera_alt), SizedBox(width: 12), Text("Tirar foto"),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "galeria"),
            child: const Row(children: [
              Icon(Icons.photo_library), SizedBox(width: 12), Text("Da galeria"),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "arquivo"),
            child: const Row(children: [
              Icon(Icons.attach_file), SizedBox(width: 12), Text("Arquivo"),
            ]),
          ),
        ],
      ),
    );
    if (opcao == null) return;
    try {
      if (opcao == "camera") {
        final img = await _imagePicker.pickImage(
            source: ImageSource.camera,
            imageQuality: 85,
            maxWidth: 1920,
            maxHeight: 1920);
        if (img == null) return;
        await widget.api.uploadEvidenciaImagem(itemId: _item.id, image: img);
        // Offer AI analysis
        if (mounted) {
          final analisar = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Analisar com IA?"),
              content: const Text(
                  "Deseja enviar esta foto para análise visual com inteligência artificial?"),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Não")),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text("Sim")),
              ],
            ),
          );
          if (analisar == true && mounted) {
            try {
              final analise = await widget.api.enviarAnaliseVisual(
                etapaId: _item.etapaId,
                image: img,
                grupo: _item.grupo,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        "Análise concluída: ${analise.achados?.length ?? 0} achado(s)")));
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erro na análise IA: $e")));
              }
            }
          }
        }
      } else if (opcao == "galeria") {
        final img = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
            maxWidth: 1920,
            maxHeight: 1920);
        if (img == null) return;
        await widget.api.uploadEvidenciaImagem(itemId: _item.id, image: img);
      } else {
        final result = await FilePicker.platform.pickFiles(withReadStream: true);
        if (result == null || result.files.isEmpty) return;
        await widget.api.uploadEvidencia(itemId: _item.id, file: result.files.first);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Evidência enviada.")));
        _recarregarEvidencias();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Detalhe do Item")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(_item.titulo,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              if (_item.critico)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text("Crítico",
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              if (_item.severidade != null) ...[
                const SizedBox(width: 6),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _severidadeColor(_item.severidade!)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _item.severidade!.toUpperCase(),
                    style: TextStyle(
                      color: _severidadeColor(_item.severidade!),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text("${_item.grupo} · ${widget.etapaNome}",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              if (_item.statusVerificacao != "pendente") ...[
                const SizedBox(width: 8),
                _VerificacaoBadge(status: _item.statusVerificacao),
              ],
            ],
          ),

          // ── Documento de origem ──────────────────────────────────────
          if (_item.projetoDocNome != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.description_outlined,
                    size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "Origem: ${_item.projetoDocNome}",
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // ── Descrição ───────────────────────────────────────────────
          if (_item.descricao != null && _item.descricao!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text("Descrição", style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(_item.descricao!, style: const TextStyle(fontSize: 14)),
          ],

          // ── Por que é importante ──────────────────────────────────
          if (_item.explicacaoLeigo != null &&
              _item.explicacaoLeigo!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 18, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Por que é importante",
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber[800])),
                        const SizedBox(height: 4),
                        Text(_item.explicacaoLeigo!,
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Como verificar ────────────────────────────────────────
          if (_item.comoVerificar != null &&
              _item.comoVerificar!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _BlocoExpansivel(
              titulo: "Como verificar",
              icon: Icons.checklist_rtl,
              cor: Colors.blue,
              initiallyExpanded: true,
              children: [
                Text(_item.comoVerificar!,
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
          ],

          // ── Medidas mínimas ───────────────────────────────────────
          if (_item.medidasMinimas != null &&
              _item.medidasMinimas!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _BlocoExpansivel(
              titulo: "Medidas mínimas",
              icon: Icons.straighten,
              cor: Colors.teal,
              children: [
                Text(_item.medidasMinimas!,
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
          ],

          // ── Tradução leigo (legado) ───────────────────────────────
          if (_item.traducaoLeigo != null &&
              _item.explicacaoLeigo == null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 18, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_item.traducaoLeigo!,
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],

          // ═══ BLOCO 1: O que o projeto diz ═══════════════════════════
          if (_item.dadoProjeto != null) ...[
            const SizedBox(height: 20),
            _BlocoExpansivel(
              titulo: "O que o projeto diz",
              icon: Icons.architecture,
              cor: Colors.teal,
              children: [
                if (_item.dadoProjeto!["descricao"] != null)
                  Text(_item.dadoProjeto!["descricao"],
                      style: const TextStyle(fontSize: 14)),
                if (_item.dadoProjeto!["especificacao"] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.straighten,
                            size: 16, color: Colors.teal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _item.dadoProjeto!["especificacao"],
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_item.dadoProjeto!["fonte"] != null) ...[
                  const SizedBox(height: 6),
                  Text("Fonte: ${_item.dadoProjeto!["fonte"]}",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ],
            ),
          ],

          // ═══ BLOCO 2: Verifique na obra ═════════════════════════════
          if (_item.verificacoes != null && _item.verificacoes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _BlocoExpansivel(
              titulo: "Verifique na obra",
              icon: Icons.checklist_rtl,
              cor: Colors.blue,
              initiallyExpanded: true,
              children: [
                for (final v in _item.verificacoes!) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _tipoVerificacaoIcon(v["tipo"] as String? ?? "visual"),
                        size: 18,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v["instrucao"] ?? "",
                                style: const TextStyle(fontSize: 14)),
                            if (v["valor_esperado"] != null)
                              Text("Esperado: ${v["valor_esperado"]}",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600])),
                            if (v["como_medir"] != null)
                              Text(v["como_medir"],
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                // Resultado do cruzamento (se já registrado)
                if (_item.resultadoCruzamento != null) ...[
                  const Divider(),
                  _ResultadoCruzamentoCard(
                      resultado: _item.resultadoCruzamento!),
                ],
                // Botão/form de verificação
                const SizedBox(height: 8),
                if (_mostrarFormVerificacao)
                  VerificacaoInlineWidget(
                    item: _item,
                    api: widget.api,
                    onVerificado: (atualizado) {
                      setState(() {
                        _item = atualizado;
                        _mostrarFormVerificacao = false;
                      });
                    },
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _mostrarFormVerificacao = true),
                    icon: Icon(
                      _item.registroProprietario != null
                          ? Icons.edit
                          : Icons.assignment_turned_in,
                      size: 18,
                    ),
                    label: Text(
                      _item.registroProprietario != null
                          ? "Atualizar Verificação"
                          : "Registrar Verificação",
                    ),
                  ),
              ],
            ),
          ],

          // ═══ BLOCO 3: Norma & Engenheiro ════════════════════════════
          if (_item.perguntaEngenheiro != null ||
              _item.normaReferencia != null ||
              (_item.documentosAExigir != null &&
                  _item.documentosAExigir!.isNotEmpty)) ...[
            const SizedBox(height: 12),
            _BlocoExpansivel(
              titulo: "Norma & Engenheiro",
              icon: Icons.engineering,
              cor: Colors.deepPurple,
              children: [
                // Norma
                if (_item.normaReferencia != null) ...[
                  Row(
                    children: [
                      Icon(Icons.menu_book_outlined,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_item.normaReferencia!,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NormasScreen(
                              api: widget.api,
                              etapaInicial: widget.etapaNome,
                            ),
                          ),
                        ),
                        child: const Text("Ver biblioteca"),
                      ),
                    ],
                  ),
                ],
                // Pergunta para engenheiro
                if (_item.perguntaEngenheiro != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_item.perguntaEngenheiro!["contexto"] != null)
                          Text(_item.perguntaEngenheiro!["contexto"],
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[700])),
                        if (_item.perguntaEngenheiro!["pergunta"] != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            "\"${_item.perguntaEngenheiro!["pergunta"]}\"",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        if (_item.perguntaEngenheiro!["resposta_esperada"] != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 16, color: Colors.green[700]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "Resposta esperada: ${_item.perguntaEngenheiro!["resposta_esperada"]}",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.green[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                // Documentos a exigir
                if (_item.documentosAExigir != null &&
                    _item.documentosAExigir!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text("Documentos a exigir:",
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  for (final doc in _item.documentosAExigir!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined,
                              size: 14, color: Colors.deepPurple),
                          const SizedBox(width: 6),
                          Expanded(
                              child:
                                  Text(doc, style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ],

          // ── Botão Analisar com IA (se não enriquecido) ────────────
          if (!_item.isEnriquecido) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.blue.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: ListTile(
                leading: const Icon(Icons.auto_awesome, color: Colors.blue),
                title: const Text("Analisar com IA"),
                subtitle: const Text("Preencher os 3 blocos com análise inteligente"),
                trailing: _enriquecendo
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _enriquecendo ? null : _enriquecerItem,
              ),
            ),
            if (_item.normaReferencia != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.menu_book_outlined,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_item.normaReferencia!,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NormasScreen(
                          api: widget.api,
                          etapaInicial: widget.etapaNome,
                        ),
                      ),
                    ),
                    child: const Text("Ver biblioteca"),
                  ),
                ],
              ),
            ],
          ],

          // ── Status ──────────────────────────────────────────────────
          const SizedBox(height: 20),
          Text("Status", style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          _salvandoStatus
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    _StatusButton(
                      label: "Pendente",
                      icon: Icons.radio_button_unchecked,
                      color: Colors.grey,
                      selected: _item.status == "pendente",
                      onTap: () => _atualizarStatus("pendente"),
                    ),
                    const SizedBox(width: 8),
                    _StatusButton(
                      label: "OK",
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                      selected: _item.status == "ok",
                      onTap: () => _atualizarStatus("ok"),
                    ),
                    const SizedBox(width: 8),
                    _StatusButton(
                      label: "Não conforme",
                      icon: Icons.cancel_outlined,
                      color: Colors.red,
                      selected: _item.status == "nao_conforme",
                      onTap: () => _atualizarStatus("nao_conforme"),
                    ),
                  ],
                ),

          // ── Confiança IA ────────────────────────────────────────────
          if (_item.confianca != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text("Confiança da IA: ", style: theme.textTheme.titleSmall),
                Text("${_item.confianca}%",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: _item.confianca! / 100.0,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
            ),
          ],

          // ── Validação profissional ──────────────────────────────────
          if (_item.requerValidacaoProfissional) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber,
                      size: 20, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Este item requer validação de engenheiro ou arquiteto.",
                      style: TextStyle(fontSize: 13, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Evidências ──────────────────────────────────────────────
          const SizedBox(height: 24),
          Row(
            children: [
              Text("Evidências", style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: _adicionarEvidencia,
                icon: const Icon(Icons.add_a_photo, size: 18),
                label: const Text("Adicionar"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder(
            future: _evidenciasFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final evidencias = snapshot.data ?? [];
              if (evidencias.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text("Nenhuma evidência ainda.",
                        style: TextStyle(color: Colors.grey)),
                  ),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: evidencias.length,
                itemBuilder: (context, i) {
                  final ev = evidencias[i];
                  final isImage =
                      ev.mimeType?.startsWith("image/") == true;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: isImage
                        ? Image.network(ev.arquivoUrl, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.attach_file,
                                color: Colors.grey),
                          ),
                  );
                },
              );
            },
          ),

          // ── Observação ──────────────────────────────────────────────
          const SizedBox(height: 24),
          Text("Observação", style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _obsController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: "Anotações sobre este item...",
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _salvandoObs ? null : _salvarObservacao,
              child: _salvandoObs
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text("Salvar observação"),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Helper functions ────────────────────────────────────────────────────────

Color _severidadeColor(String s) => severidadeColor(s);

IconData _tipoVerificacaoIcon(String tipo) {
  switch (tipo) {
    case "medicao":
      return Icons.straighten;
    case "visual":
      return Icons.visibility;
    case "documento":
      return Icons.description;
    default:
      return Icons.check;
  }
}

// ─── Widgets auxiliares ──────────────────────────────────────────────────────

class _BlocoExpansivel extends StatelessWidget {
  const _BlocoExpansivel({
    required this.titulo,
    required this.icon,
    required this.cor,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String titulo;
  final IconData icon;
  final Color cor;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cor.withValues(alpha: 0.3)),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon, color: cor),
        title: Text(titulo,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: cor, fontSize: 15)),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _VerificacaoBadge extends StatelessWidget {
  const _VerificacaoBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      "conforme" => ("Conforme", Colors.green, Icons.check_circle),
      "divergente" => ("Divergente", Colors.red, Icons.error),
      "duvida" => ("Dúvida", Colors.orange, Icons.help),
      _ => ("Pendente", Colors.grey, Icons.pending),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ResultadoCruzamentoCard extends StatelessWidget {
  const _ResultadoCruzamentoCard({required this.resultado});

  final Map<String, dynamic> resultado;

  @override
  Widget build(BuildContext context) {
    final conclusao = resultado["conclusao"] as String? ?? "duvida";
    final cor = switch (conclusao) {
      "conforme" => Colors.green,
      "divergente" => Colors.red,
      _ => Colors.orange,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                conclusao == "conforme"
                    ? Icons.check_circle
                    : conclusao == "divergente"
                        ? Icons.error
                        : Icons.help,
                size: 18,
                color: cor,
              ),
              const SizedBox(width: 6),
              Text("Resultado da verificação",
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: cor, fontSize: 13)),
            ],
          ),
          if (resultado["resumo"] != null) ...[
            const SizedBox(height: 6),
            Text(resultado["resumo"], style: const TextStyle(fontSize: 13)),
          ],
          if (resultado["acao"] != null) ...[
            const SizedBox(height: 4),
            Text(resultado["acao"],
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.grey.withValues(alpha: 0.3),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : Colors.grey, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? color : Colors.grey,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
