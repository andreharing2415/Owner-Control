import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api.dart';
import '../providers/riverpod_providers.dart';
import '../providers/owner_progress_provider.dart';
import '../services/owner_progress_service.dart';
import '../utils/auth_error_handler.dart';

// ─── Dados consolidados de progresso para o dono ──────────────────────────────

class _OwnerProgressData {
  _OwnerProgressData({
    required this.obra,
    required this.etapas,
    required this.fotosRecentes,
  });

  final Obra obra;
  final List<Etapa> etapas;
  final List<Evidencia> fotosRecentes;

  int get etapasConcluidas =>
      etapas.where((e) => e.status == 'concluida').length;

  int get totalEtapas => etapas.length;

  double get progressoPercent =>
      totalEtapas > 0 ? (etapasConcluidas / totalEtapas) : 0.0;

  /// Etapa em andamento no momento.
  Etapa? get etapaAtual =>
      etapas.where((e) => e.status == 'em_andamento').firstOrNull;

  /// Próximas etapas ainda não iniciadas.
  List<Etapa> get proximasEtapas =>
      etapas.where((e) => e.status == 'pendente').toList();

  /// Etapas já concluídas.
  List<Etapa> get etapasConcluidasList =>
      etapas.where((e) => e.status == 'concluida').toList();
}

// ─── Rótulos para o dono — linguagem leiga ────────────────────────────────────

String _labelStatus(String status) {
  return switch (status) {
    'concluida' => 'Concluída',
    'em_andamento' => 'Em andamento',
    'pendente' => 'Aguardando',
    _ => 'Indefinido',
  };
}

Color _corStatus(String status) {
  return switch (status) {
    'concluida' => const Color(0xFF4CAF50),
    'em_andamento' => const Color(0xFF2196F3),
    'pendente' => const Color(0xFF9E9E9E),
    _ => const Color(0xFF9E9E9E),
  };
}

// ─── Tela principal ───────────────────────────────────────────────────────────

/// Tela de acompanhamento de obra para o proprietário (dono_da_obra).
///
/// Apresenta progresso, fotos recentes e próximas etapas em linguagem acessível,
/// sem expor termos técnicos de engenharia.
class OwnerProgressoScreen extends ConsumerStatefulWidget {
  const OwnerProgressoScreen({
    super.key,
    this.obraId,
    this.obraNome,
  });

  final String? obraId;
  final String? obraNome;

  @override
  ConsumerState<OwnerProgressoScreen> createState() => _OwnerProgressoScreenState();
}

class _OwnerProgressoScreenState extends ConsumerState<OwnerProgressoScreen> {
  late Future<_OwnerProgressData> _dataFuture;
  String? _obraAtualId;
  int _lastRefreshTick = -1;

  OwnerProgressService get _progressService => ref.read(ownerProgressServiceProvider);

  @override
  void initState() {
    super.initState();
    _dataFuture = Future.value(
      _OwnerProgressData(obra: Obra(id: "", nome: "", tipo: "construcao"), etapas: [], fotosRecentes: []),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ownerProvider = ref.read(ownerProgressProvider);
    if (!ownerProvider.loading && ownerProvider.obras.isEmpty && ownerProvider.error == null) {
      ownerProvider.load();
    }
  }

  Future<_OwnerProgressData> _carregarDados(String obraId, String obraNome) async {
    final etapas = await _progressService.listarEtapas(obraId);

    // Coleta evidencias das etapas concluidas ou em andamento (máx. 3 por etapa).
    final fotosRecentes = <Evidencia>[];
    for (final etapa in etapas) {
      if (etapa.status == 'pendente') continue;
      try {
        final itens = await _progressService.listarItens(etapa.id);
        for (final item in itens.take(3)) {
          try {
            final evidencias = await _progressService.listarEvidencias(item.id);
            final fotos = evidencias
                .where((e) =>
                    e.mimeType?.startsWith('image/') ?? false)
                .toList();
            fotosRecentes.addAll(fotos);
            if (fotosRecentes.length >= 6) break;
          } catch (_) {
            // Evidencias nao criticas — ignora falha individual
          }
        }
        if (fotosRecentes.length >= 6) break;
      } catch (_) {
        // Item nao critico — ignora falha individual
      }
    }

    // Obra basica — usamos apenas o nome passado como argumento
    final obra = Obra(
      id: obraId,
      nome: obraNome,
      tipo: 'construcao',
    );

    return _OwnerProgressData(
      obra: obra,
      etapas: etapas,
      fotosRecentes: fotosRecentes.take(6).toList(),
    );
  }

  Future<void> _refresh() async {
    await ref.read(ownerProgressProvider).refreshCurrent();
    setState(() {
      final obra = _resolveObraSelecionada(ref.read(ownerProgressProvider));
      if (obra != null) {
        _dataFuture = _carregarDados(obra.obraId, obra.obraNome);
      }
    });
  }

  ObraConvidada? _resolveObraSelecionada(OwnerProgressProvider provider) {
    if (widget.obraId != null && widget.obraNome != null) {
      return ObraConvidada(
        obraId: widget.obraId!,
        obraNome: widget.obraNome!,
        donoNome: "",
        papel: "dono_da_obra",
        conviteId: "",
      );
    }
    return provider.selectedObra;
  }

  @override
  Widget build(BuildContext context) {
    final ownerProvider = ref.watch(ownerProgressProvider);
    final obraSelecionada = _resolveObraSelecionada(ownerProvider);

    if (ownerProvider.loading && obraSelecionada == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (obraSelecionada == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acompanhamento')),
        body: _ErroCarregamento(
          mensagem: ownerProvider.error ?? 'Nenhuma obra compartilhada foi encontrada.',
          onRetry: () {
            ownerProvider.load();
          },
        ),
      );
    }

    if (_obraAtualId != obraSelecionada.obraId || _lastRefreshTick != ownerProvider.refreshTick) {
      _obraAtualId = obraSelecionada.obraId;
      _lastRefreshTick = ownerProvider.refreshTick;
      _dataFuture = _carregarDados(obraSelecionada.obraId, obraSelecionada.obraNome);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          obraSelecionada.obraNome,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: FutureBuilder<_OwnerProgressData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final e = snapshot.error!;
            if (e is AuthExpiredException) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) handleApiError(context, e);
              });
            }
            return _ErroCarregamento(
              mensagem: 'Não foi possível carregar o progresso da obra.',
              onRetry: _refresh,
            );
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: Column(
              children: [
                if (widget.obraId == null && ownerProvider.obras.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: DropdownButtonFormField<String>(
                      initialValue: obraSelecionada.obraId,
                      decoration: const InputDecoration(
                        labelText: 'Obra compartilhada',
                        border: OutlineInputBorder(),
                      ),
                      items: ownerProvider.obras
                          .map(
                            (obra) => DropdownMenuItem<String>(
                              value: obra.obraId,
                              child: Text(obra.obraNome),
                            ),
                          )
                          .toList(),
                      onChanged: (obraId) {
                        if (obraId == null) return;
                        final selecionada = ownerProvider.obras.firstWhere((obra) => obra.obraId == obraId);
                        ownerProvider.selectObra(selecionada);
                      },
                    ),
                  ),
                Expanded(child: _OwnerProgressoBody(data: data)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Corpo principal ──────────────────────────────────────────────────────────

class _OwnerProgressoBody extends StatelessWidget {
  const _OwnerProgressoBody({required this.data});

  final _OwnerProgressData data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardProgressoGeral(data: data),
          const SizedBox(height: 16),
          if (data.etapaAtual != null) ...[
            _CardEtapaAtual(etapa: data.etapaAtual!),
            const SizedBox(height: 16),
          ],
          if (data.fotosRecentes.isNotEmpty) ...[
            _CardFotosRecentes(fotos: data.fotosRecentes),
            const SizedBox(height: 16),
          ],
          if (data.proximasEtapas.isNotEmpty) ...[
            _CardProximasEtapas(etapas: data.proximasEtapas),
            const SizedBox(height: 16),
          ],
          if (data.etapasConcluidasList.isNotEmpty) ...[
            _CardEtapasConcluidas(etapas: data.etapasConcluidasList),
            const SizedBox(height: 16),
          ],
          const _AvisoSomenteVisualizacao(),
        ],
      ),
    );
  }
}

// ─── Card: Progresso geral ────────────────────────────────────────────────────

class _CardProgressoGeral extends StatelessWidget {
  const _CardProgressoGeral({required this.data});

  final _OwnerProgressData data;

  @override
  Widget build(BuildContext context) {
    final pct = data.progressoPercent;
    final pctStr = '${(pct * 100).round()}%';
    final etapasConcluidas = data.etapasConcluidas;
    final totalEtapas = data.totalEtapas;

    String mensagem;
    if (pct == 0) {
      mensagem = 'A obra ainda não começou.';
    } else if (pct < 0.25) {
      mensagem = 'A obra está nas fases iniciais.';
    } else if (pct < 0.5) {
      mensagem = 'Aproximadamente um quarto da obra está pronto.';
    } else if (pct < 0.75) {
      mensagem = 'A obra está na metade do caminho.';
    } else if (pct < 1.0) {
      mensagem = 'A obra está na reta final!';
    } else {
      mensagem = 'Parabéns! A obra foi concluída.';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.home_work_outlined, color: Color(0xFF1976D2)),
                const SizedBox(width: 8),
                Text(
                  'Progresso da obra',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              pctStr,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1976D2),
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: const Color(0xFFE0E0E0),
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 1.0
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF1976D2),
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 12),
            Text(
              mensagem,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$etapasConcluidas de $totalEtapas etapas concluídas',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card: Etapa atual ────────────────────────────────────────────────────────

class _CardEtapaAtual extends StatelessWidget {
  const _CardEtapaAtual({required this.etapa});

  final Etapa etapa;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFFE3F2FD),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.construction, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acontecendo agora',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF1565C0),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    etapa.nome,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card: Fotos recentes ─────────────────────────────────────────────────────

class _CardFotosRecentes extends StatelessWidget {
  const _CardFotosRecentes({required this.fotos});

  final List<Evidencia> fotos;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_library_outlined, color: Color(0xFF1976D2)),
                const SizedBox(width: 8),
                Text(
                  'Fotos recentes da obra',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 1,
              ),
              itemCount: fotos.length,
              itemBuilder: (context, index) {
                final foto = fotos[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: foto.arquivoUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card: Próximas etapas ────────────────────────────────────────────────────

class _CardProximasEtapas extends StatelessWidget {
  const _CardProximasEtapas({required this.etapas});

  final List<Etapa> etapas;

  @override
  Widget build(BuildContext context) {
    final exibir = etapas.take(3).toList();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule_outlined, color: Color(0xFF1976D2)),
                const SizedBox(width: 8),
                Text(
                  'O que vem a seguir',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...exibir.map(
              (etapa) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _corStatus(etapa.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        etapa.nome,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      _labelStatus(etapa.status),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _corStatus(etapa.status),
                          ),
                    ),
                  ],
                ),
              ),
            ),
            if (etapas.length > 3) ...[
              const SizedBox(height: 8),
              Text(
                'e mais ${etapas.length - 3} etapa${etapas.length - 3 > 1 ? 's' : ''}…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Card: Etapas concluídas ──────────────────────────────────────────────────

class _CardEtapasConcluidas extends StatelessWidget {
  const _CardEtapasConcluidas({required this.etapas});

  final List<Etapa> etapas;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50)),
                const SizedBox(width: 8),
                Text(
                  'O que já foi feito',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...etapas.map(
              (etapa) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check,
                      size: 16,
                      color: Color(0xFF4CAF50),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        etapa.nome,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Aviso de visualização somente ───────────────────────────────────────────

class _AvisoSomenteVisualizacao extends StatelessWidget {
  const _AvisoSomenteVisualizacao();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Você está visualizando esta obra como proprietário. '
              'Para mais informações, entre em contato com o responsável.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widget de erro ───────────────────────────────────────────────────────────

class _ErroCarregamento extends StatelessWidget {
  const _ErroCarregamento({required this.mensagem, required this.onRetry});

  final String mensagem;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
