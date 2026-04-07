import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api.dart';
import '../providers/riverpod_providers.dart';
import '../services/obra_service.dart';
import '../utils/auth_error_handler.dart';
import 'convites_screen.dart';
import 'etapas_screen.dart';
import 'criar_obra_wizard.dart';
import 'cronograma_screen.dart';
import 'rdo_screen.dart';

class ObrasScreen extends ConsumerStatefulWidget {
  const ObrasScreen({super.key, this.modoSelecao = false});

  final bool modoSelecao;

  @override
  ConsumerState<ObrasScreen> createState() => _ObrasScreenState();
}

class _ObrasScreenState extends ConsumerState<ObrasScreen> {
  late Future<List<Obra>> _obrasFuture;

  ObraService get _obraService => ref.read(obraServiceProvider);

  // Controla se o redirect automático para criação já foi disparado nesta sessão.
  // Evita loop infinito caso o usuário cancele o wizard sem criar obra.
  bool _redirectedToCreate = false;

  @override
  void initState() {
    super.initState();
    _obrasFuture = _obraService.listarObras();
  }

  Future<void> _refresh() async {
    setState(() {
      _obrasFuture = _obraService.listarObras();
    });
  }

  Future<void> _deletarObra(Obra obra) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir obra'),
        content: Text(
          'Deseja excluir "${obra.nome}"?\n\n'
          'Todos os dados associados (etapas, documentos, checklist, financeiro) serão removidos permanentemente.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _obraService.deletarObra(obra.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Obra excluída.')),
        );
        _refresh();
      }
    } catch (e) {
      if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _criarObra() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CriarObraWizard()),
    );
    if (created == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Obras"),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "fab_obras",
        onPressed: _criarObra,
        icon: const Icon(Icons.add),
        label: const Text("Nova Obra"),
      ),
      body: FutureBuilder<List<Obra>>(
        future: _obrasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text("Erro ao carregar obras:\n${snapshot.error}", textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _refresh, child: const Text("Tentar novamente")),
                ],
              ),
            );
          }
          final obras = snapshot.data ?? [];
          if (obras.isEmpty) {
            // Redireciona automaticamente para o wizard na primeira vez.
            if (!_redirectedToCreate && !widget.modoSelecao) {
              _redirectedToCreate = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!mounted) return;
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const CriarObraWizard()),
                );
                if (created == true && mounted) {
                  setState(() {
                    _redirectedToCreate = false;
                    _obrasFuture = _obraService.listarObras();
                  });
                }
              });
            }
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home_work_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("Nenhuma obra cadastrada", style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text("Toque em 'Nova Obra' para começar."),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _criarObra,
                    icon: const Icon(Icons.add),
                    label: const Text("Criar primeira obra"),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: obras.length,
              itemBuilder: (context, index) {
                final obra = obras[index];
                String subtitulo = obra.localizacao ?? "Localização não informada";
                if (obra.dataInicio != null || obra.dataFim != null) {
                  final partes = [
                    if (obra.dataInicio != null) "Início: ${obra.dataInicio!.split('-').reversed.join('/')}",
                    if (obra.dataFim != null) "Fim: ${obra.dataFim!.split('-').reversed.join('/')}",
                  ];
                  subtitulo += "\n${partes.join('  ·  ')}";
                }
                return Card(
                  child: ListTile(
                    isThreeLine: obra.dataInicio != null || obra.dataFim != null,
                    leading: const CircleAvatar(child: Icon(Icons.home_work)),
                    title: Text(obra.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(subtitulo),
                    trailing: widget.modoSelecao
                        ? const Icon(Icons.chevron_right)
                        : PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'convites') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ConvitesScreen(
                                      obraId: obra.id,
                                      obraNome: obra.nome,
                                    ),
                                  ),
                                );
                              } else if (v == 'rdo') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RdoScreen(obra: obra),
                                  ),
                                );
                              } else if (v == 'excluir') {
                                _deletarObra(obra);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'convites',
                                child: Row(children: [
                                  Icon(Icons.person_add_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Convites'),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'rdo',
                                child: Row(children: [
                                  Icon(Icons.event_note_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('RDO diario'),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'excluir',
                                child: Row(children: [
                                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Excluir obra', style: TextStyle(color: Colors.red)),
                                ]),
                              ),
                            ],
                          ),
                    onTap: () {
                      if (widget.modoSelecao) {
                        Navigator.pop(context, obra);
                      } else if (obra.tipo == "construcao") {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CronogramaScreen(obra: obra)),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EtapasScreen(obra: obra)),
                        );
                      }
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
