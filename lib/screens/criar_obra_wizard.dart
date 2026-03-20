import 'package:flutter/material.dart';
import '../api/api.dart';
import '../utils/auth_error_handler.dart';
import '../widgets/criar_obra/step_tipo.dart';
import '../widgets/criar_obra/step_documentos.dart';
import '../widgets/criar_obra/step_cronograma.dart';
import 'etapas_screen.dart';
import 'cronograma_screen.dart';

class CriarObraWizard extends StatefulWidget {
  const CriarObraWizard({super.key});

  @override
  State<CriarObraWizard> createState() => _CriarObraWizardState();
}

class _CriarObraWizardState extends State<CriarObraWizard> {
  final ApiClient _api = ApiClient();
  final PageController _pageController = PageController();

  int _currentStep = 0;
  String _tipo = "construcao";

  // Step 1 - Info
  final _nomeController = TextEditingController();
  final _localController = TextEditingController();
  final _orcamentoController = TextEditingController();
  DateTime? _dataInicio;
  DateTime? _dataFim;
  bool _criandoObra = false;

  // Created obra
  Obra? _obra;

  // Step 3 - Cronograma
  CronogramaResponse? _cronograma;
  bool _gerandoCronograma = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nomeController.dispose();
    _localController.dispose();
    _orcamentoController.dispose();
    super.dispose();
  }

  int get _totalSteps => _tipo == "construcao" ? 4 : 2;

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = page);
  }

  String _fmtDate(DateTime? d) =>
      d == null
          ? "Nao definida"
          : "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

  String? _fmtIso(DateTime? d) =>
      d == null
          ? null
          : "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  Future<void> _criarObra() async {
    if (_nomeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("O nome da obra e obrigatorio.")),
      );
      return;
    }

    setState(() => _criandoObra = true);
    try {
      final orcamento = double.tryParse(
          _orcamentoController.text.replaceAll(",", "."));
      final obra = await _api.criarObra(
        nome: _nomeController.text.trim(),
        localizacao: _localController.text.trim(),
        orcamento: orcamento,
        dataInicio: _fmtIso(_dataInicio),
        dataFim: _fmtIso(_dataFim),
        tipo: _tipo,
      );
      if (!mounted) return;
      setState(() => _obra = obra);

      if (_tipo == "reforma") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => EtapasScreen(obra: obra)),
        );
        return;
      } else {
        _goToPage(2);
      }
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) handleApiError(context, e);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao criar obra: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _criandoObra = false);
    }
  }

  Future<void> _gerarCronograma(List<TipoProjetoIdentificado> tipos) async {
    if (_obra == null) return;

    final tiposSelecionados = tipos
        .where((t) => t.confirmado)
        .map((t) => t.nome)
        .toList();

    setState(() => _gerandoCronograma = true);
    _goToPage(3);

    try {
      final cronograma = await _api.gerarCronograma(
        obraId: _obra!.id,
        tiposProjeto: tiposSelecionados,
      );
      if (!mounted) return;
      setState(() => _cronograma = cronograma);
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) handleApiError(context, e);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao gerar cronograma: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _gerandoCronograma = false);
    }
  }

  void _aceitarCronograma() {
    if (_obra == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => CronogramaScreen(obra: _obra!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nova Obra"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0) {
              _goToPage(_currentStep - 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          StepTipo(
            tipo: _tipo,
            onTipoSelected: (tipo) {
              setState(() => _tipo = tipo);
              _goToPage(1);
            },
          ),
          _buildStepInfo(),
          if (_obra != null)
            StepDocumentos(
              obra: _obra!,
              onAnaliseCompleta: _gerarCronograma,
            )
          else
            const SizedBox.shrink(),
          StepCronograma(
            cronograma: _cronograma,
            gerando: _gerandoCronograma,
            onRegenerar: () {
              setState(() => _cronograma = null);
              _gerarCronograma([]);
            },
            onAceitar: _aceitarCronograma,
          ),
        ],
      ),
    );
  }

  Widget _buildStepInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Informacoes da obra",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nomeController,
            decoration: const InputDecoration(labelText: "Nome da obra *"),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _localController,
            decoration: const InputDecoration(labelText: "Localizacao"),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _orcamentoController,
            decoration: const InputDecoration(labelText: "Orcamento (R\$)"),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          const Text("Datas da obra",
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    "Inicio\n${_fmtDate(_dataInicio)}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _dataInicio ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      helpText: "Data de inicio",
                    );
                    if (d != null) setState(() => _dataInicio = d);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event, size: 16),
                  label: Text(
                    "Previsao fim\n${_fmtDate(_dataFim)}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _dataFim ??
                          (_dataInicio ?? DateTime.now())
                              .add(const Duration(days: 180)),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      helpText: "Previsao de termino",
                    );
                    if (d != null) setState(() => _dataFim = d);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _criandoObra ? null : _criarObra,
              child: _criandoObra
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Proximo"),
            ),
          ),
        ],
      ),
    );
  }
}
