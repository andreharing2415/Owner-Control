import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../models/prestador.dart";
import "../../providers/auth_provider.dart";
import "../../providers/subscription_provider.dart";
import "../../services/api_client.dart";
import "../subscription/paywall_screen.dart";
import "detalhe_prestador_screen.dart";

class PrestadoresScreen extends StatefulWidget {
  const PrestadoresScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<PrestadoresScreen> createState() => _PrestadoresScreenState();
}

class _PrestadoresScreenState extends State<PrestadoresScreen> {
  String? _categoriaFiltro;
  String _busca = "";
  String? _regiaoFiltro;
  late Future<List<Prestador>> _prestadoresFuture;
  final _buscaController = TextEditingController();
  final _regiaoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prestadoresFuture = _load();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    _regiaoController.dispose();
    super.dispose();
  }

  Future<List<Prestador>> _load() {
    return widget.api.listarPrestadores(
      categoria: _categoriaFiltro,
      busca: _busca.isNotEmpty ? _busca : null,
      regiao: _regiaoFiltro,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _prestadoresFuture = _load();
    });
  }

  void _setCategoria(String? cat) {
    setState(() {
      _categoriaFiltro = cat;
      _prestadoresFuture = _load();
    });
  }

  Future<void> _adicionarPrestador() async {
    final nomeController = TextEditingController();
    final regiaoController = TextEditingController();
    final telefoneController = TextEditingController();
    final emailController = TextEditingController();
    String categoriaSelecionada = "prestador_servico";
    String? subcategoriaSelecionada;
    Map<String, List<String>>? subcategoriasMap;

    try {
      subcategoriasMap = await widget.api.listarSubcategorias();
    } catch (_) {
      subcategoriasMap = {};
    }

    if (!mounted) return;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final subs = subcategoriasMap?[categoriaSelecionada] ?? [];
          return AlertDialog(
            title: const Text("Novo Prestador"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nomeController,
                    decoration: const InputDecoration(labelText: "Nome *"),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey("cat_$categoriaSelecionada"),
                    initialValue: categoriaSelecionada,
                    decoration: const InputDecoration(labelText: "Categoria *"),
                    items: const [
                      DropdownMenuItem(
                        value: "prestador_servico",
                        child: Text("Prestador de Servico"),
                      ),
                      DropdownMenuItem(
                        value: "materiais",
                        child: Text("Fornecedor de Materiais"),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          categoriaSelecionada = value;
                          subcategoriaSelecionada = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey("sub_$subcategoriaSelecionada"),
                    initialValue: subcategoriaSelecionada,
                    decoration:
                        const InputDecoration(labelText: "Subcategoria *"),
                    items: subs
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        subcategoriaSelecionada = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: regiaoController,
                    decoration: const InputDecoration(labelText: "Regiao"),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: telefoneController,
                    decoration: const InputDecoration(labelText: "Telefone"),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: "Email"),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Salvar"),
              ),
            ],
          );
        },
      ),
    );

    if (created == true &&
        nomeController.text.trim().isNotEmpty &&
        subcategoriaSelecionada != null) {
      try {
        await widget.api.criarPrestador(
          nome: nomeController.text.trim(),
          categoria: categoriaSelecionada,
          subcategoria: subcategoriaSelecionada!,
          regiao: regiaoController.text.trim().isNotEmpty
              ? regiaoController.text.trim()
              : null,
          telefone: telefoneController.text.trim().isNotEmpty
              ? telefoneController.text.trim()
              : null,
          email: emailController.text.trim().isNotEmpty
              ? emailController.text.trim()
              : null,
        );
        await _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Prestador criado com sucesso.")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro ao criar prestador: $e")),
          );
        }
      }
    }
  }

  Widget _buildStars(double? media) {
    final valor = media ?? 0.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (valor >= i + 1) {
          return const Icon(Icons.star, size: 16, color: Colors.amber);
        } else if (valor > i) {
          return const Icon(Icons.star_half, size: 16, color: Colors.amber);
        }
        return Icon(Icons.star_border, size: 16, color: Colors.grey[400]);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = context.read<AuthProvider>().user;
    final isConvidado = user?.isConvidado ?? false;

    // Convidado: completely blocked
    if (isConvidado) {
      return Scaffold(
        appBar: AppBar(title: const Text("Prestadores")),
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
                  "Os Prestadores estão disponíveis apenas para o proprietário da obra.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sub = context.watch<SubscriptionProvider>();
    final prestadoresLimit = sub.prestadoresLimit;
    final showContact = sub.prestadoresShowContact;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Prestadores"),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _adicionarPrestador,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text("Todos"),
                  selected: _categoriaFiltro == null,
                  onSelected: (_) => _setCategoria(null),
                ),
                FilterChip(
                  label: const Text("Prestadores"),
                  selected: _categoriaFiltro == "prestador_servico",
                  onSelected: (_) => _setCategoria(
                    _categoriaFiltro == "prestador_servico"
                        ? null
                        : "prestador_servico",
                  ),
                ),
                FilterChip(
                  label: const Text("Fornecedores"),
                  selected: _categoriaFiltro == "materiais",
                  onSelected: (_) => _setCategoria(
                    _categoriaFiltro == "materiais" ? null : "materiais",
                  ),
                ),
              ],
            ),
          ),
          // Search & region filter
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _buscaController,
                    decoration: InputDecoration(
                      hintText: "Buscar por nome...",
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _busca.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _buscaController.clear();
                                setState(() {
                                  _busca = "";
                                  _prestadoresFuture = _load();
                                });
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (value) {
                      setState(() {
                        _busca = value.trim();
                        _prestadoresFuture = _load();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _regiaoController,
                    decoration: InputDecoration(
                      hintText: "Regiao",
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _regiaoFiltro != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _regiaoController.clear();
                                setState(() {
                                  _regiaoFiltro = null;
                                  _prestadoresFuture = _load();
                                });
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (value) {
                      setState(() {
                        _regiaoFiltro =
                            value.trim().isNotEmpty ? value.trim() : null;
                        _prestadoresFuture = _load();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: FutureBuilder<List<Prestador>>(
              future: _prestadoresFuture,
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
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          Text("Erro: ${snapshot.error}",
                              textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                              onPressed: _refresh,
                              child: const Text("Tentar novamente")),
                        ],
                      ),
                    ),
                  );
                }
                final prestadores = snapshot.data ?? [];
                if (prestadores.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text("Nenhum prestador encontrado",
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  );
                }
                final isTruncated = prestadoresLimit != null &&
                    prestadores.length > prestadoresLimit;
                final visibleCount = isTruncated
                    ? prestadoresLimit
                    : prestadores.length;
                // +1 for upgrade banner if truncated
                final itemCount = isTruncated
                    ? visibleCount + 1
                    : visibleCount;

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      // Upgrade banner at the end
                      if (isTruncated && index == visibleCount) {
                        return Card(
                          color: Colors.amber.withValues(alpha: 0.1),
                          child: InkWell(
                            onTap: () => PaywallScreen.show(context,
                                message:
                                    "Veja todos os ${prestadores.length} prestadores"),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const Icon(Icons.workspace_premium,
                                      color: Colors.amber),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Veja todos os prestadores",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          "Exibindo $visibleCount de ${prestadores.length}. Assine para ver todos com contato.",
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      final p = prestadores[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                colorScheme.primaryContainer,
                            child: Icon(
                              p.categoria == "materiais"
                                  ? Icons.inventory_2
                                  : Icons.engineering,
                              color: colorScheme.primary,
                            ),
                          ),
                          title: Text(p.nome),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.subcategoria),
                              if (p.regiao != null)
                                Text(
                                  p.regiao!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              // Contact hidden for free plan
                              if (!showContact &&
                                  (p.telefone != null || p.email != null))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.lock_outline,
                                          size: 12, color: Colors.grey[400]),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Contato disponível no plano Dono",
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildStars(p.mediaGeral),
                              if (p.mediaGeral != null)
                                Text(
                                  p.mediaGeral!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          isThreeLine: p.regiao != null || !showContact,
                          onTap: showContact
                              ? () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DetalhePrestadorScreen(
                                        prestadorId: p.id,
                                        api: widget.api,
                                      ),
                                    ),
                                  );
                                  _refresh();
                                }
                              : () => PaywallScreen.show(context,
                                  message:
                                      "Veja o contato completo dos prestadores"),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
