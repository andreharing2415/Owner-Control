import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/obra.dart';
import '../../models/etapa.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../visual_ai/visual_ai_screen.dart';
import '../documentos/documentos_screen.dart';
import '../checklist_inteligente/checklist_inteligente_screen.dart';
import '../normas/normas_screen.dart';

class IAHubScreen extends StatelessWidget {
  final Obra obra;
  final ApiClient api;
  final VoidCallback? onNavigateToObra;

  const IAHubScreen({super.key, required this.obra, required this.api, this.onNavigateToObra});

  @override
  Widget build(BuildContext context) {
    final isConvidado =
        context.read<AuthProvider>().user?.isConvidado ?? false;

    final acoes = <_IAAction>[
      if (!isConvidado) ...[
        _IAAction(
          icon: Icons.camera_alt,
          titulo: "Analisar Foto",
          descricao: "Tire uma foto da obra e a IA identifica problemas",
          onTap: () => _selecionarEtapaParaFoto(context),
        ),
        _IAAction(
          icon: Icons.description,
          titulo: "Documentos",
          descricao: "Upload e análise de projetos PDF",
          onTap: () async {
            final result = await Navigator.push<String>(
              context,
              MaterialPageRoute(
                builder: (_) => DocumentosScreen(obraId: obra.id, api: api),
              ),
            );
            if (result == "navigate_obra") {
              onNavigateToObra?.call();
            }
          },
        ),
        _IAAction(
          icon: Icons.checklist,
          titulo: "Gerar Checklist IA",
          descricao: "Checklist inteligente a partir dos documentos",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChecklistInteligenteScreen(
                obraId: obra.id,
                api: api,
                autoStart: false,
              ),
            ),
          ),
        ),
        _IAAction(
          icon: Icons.auto_awesome,
          titulo: "Enriquecer Checklist",
          descricao: "IA analisa itens existentes e preenche 3 blocos",
          onTap: () => _selecionarEtapaParaEnriquecer(context),
        ),
      ],
      _IAAction(
        icon: Icons.menu_book,
        titulo: "Normas Técnicas",
        descricao: "Consulte normas ABNT/NBR em linguagem simples",
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NormasScreen(api: api),
          ),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Inteligência Artificial"),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: acoes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _buildActionCard(context, acoes[i]),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, _IAAction acao) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(acao.icon, color: Theme.of(context).colorScheme.primary),
        ),
        title:
            Text(acao.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(acao.descricao),
        trailing: const Icon(Icons.chevron_right),
        onTap: acao.onTap,
      ),
    );
  }

  Future<void> _selecionarEtapaParaFoto(BuildContext context) async {
    final etapas = await api.listarEtapas(obra.id);
    if (!context.mounted) return;
    final etapa = await showDialog<Etapa>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text("Selecione a etapa"),
        children: etapas
            .map((e) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, e),
                  child: Text(e.nome),
                ))
            .toList(),
      ),
    );
    if (etapa == null || !context.mounted) return;

    // Second dialog: select category (optional)
    String? grupo;
    try {
      final itens = await api.listarItens(etapa.id);
      final grupos = itens.map((i) => i.grupo).toSet().toList()..sort();
      if (grupos.isNotEmpty && context.mounted) {
        grupo = await showDialog<String>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text("Categoria (opcional)"),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text("Nenhuma — análise geral",
                    style: TextStyle(color: Colors.grey)),
              ),
              ...grupos.map((g) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, g),
                    child: Text(g),
                  )),
            ],
          ),
        );
      }
    } catch (_) {
      // If loading items fails, proceed without group
    }

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisualAiScreen(etapa: etapa, api: api, grupo: grupo),
      ),
    );
  }

  Future<void> _selecionarEtapaParaEnriquecer(BuildContext context) async {
    final etapas = await api.listarEtapas(obra.id);
    if (!context.mounted) return;

    // Use a sentinel value for "all etapas"
    final opcao = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text("Selecione a etapa"),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, "__todas__"),
            child: const Text("Todas as etapas",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          ...etapas.map((e) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, e.id),
                child: Text(e.nome),
              )),
        ],
      ),
    );
    if (opcao == null || !context.mounted) return;

    try {
      final Map<String, dynamic> result;
      if (opcao == "__todas__") {
        result = await api.enriquecerTodos(obra.id);
      } else {
        result = await api.enriquecerChecklist(opcao);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("${result['enriquecidos']} itens enriquecidos!")),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e")),
      );
    }
  }
}

class _IAAction {
  final IconData icon;
  final String titulo;
  final String descricao;
  final VoidCallback onTap;

  _IAAction({
    required this.icon,
    required this.titulo,
    required this.descricao,
    required this.onTap,
  });
}
