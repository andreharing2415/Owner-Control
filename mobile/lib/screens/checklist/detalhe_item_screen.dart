import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../../models/checklist_item.dart";
import "../../services/api_client.dart";
import "../normas/normas_screen.dart";

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
  bool _salvandoObs = false;
  bool _salvandoStatus = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _obsController = TextEditingController(text: _item.observacao ?? "");
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
            source: ImageSource.camera, imageQuality: 85);
        if (img == null) return;
        await widget.api.uploadEvidenciaImagem(itemId: _item.id, image: img);
      } else if (opcao == "galeria") {
        final img = await _imagePicker.pickImage(
            source: ImageSource.gallery, imageQuality: 85);
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
        setState(() {}); // trigger FutureBuilder rebuild
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
      appBar: AppBar(
        title: const Text("Detalhe do Item"),
      ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text("Crítico",
                      style: TextStyle(color: Colors.red, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text("${_item.grupo} · ${widget.etapaNome}",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),

          // ── Descrição ───────────────────────────────────────────────
          if (_item.descricao != null && _item.descricao!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text("Descrição", style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(_item.descricao!, style: const TextStyle(fontSize: 14)),
          ],

          // ── Norma ───────────────────────────────────────────────────
          if (_item.normaReferencia != null) ...[
            const SizedBox(height: 16),
            Text("Norma de referência", style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
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
            future: widget.api.listarEvidencias(_item.id),
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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: evidencias.length,
                itemBuilder: (context, i) {
                  final ev = evidencias[i];
                  final isImage = ev.mimeType?.startsWith("image/") == true;
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
                      width: 18, height: 18,
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

// ─── Widget auxiliar ─────────────────────────────────────────────────────────

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
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
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
