import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../api/api.dart';
import '../../utils/auth_error_handler.dart';

class StepDocumentos extends StatefulWidget {
  const StepDocumentos({
    super.key,
    required this.obra,
    required this.onAnaliseCompleta,
  });

  final Obra obra;
  final ValueChanged<List<TipoProjetoIdentificado>> onAnaliseCompleta;

  @override
  State<StepDocumentos> createState() => _StepDocumentosState();
}

class _StepDocumentosState extends State<StepDocumentos>
    with AutomaticKeepAliveClientMixin {
  final ApiClient _api = ApiClient();
  final List<PlatformFile> _arquivosEnviados = [];
  final List<String> _arquivosStatus = [];
  bool _enviando = false;
  bool _analisando = false;
  List<TipoProjetoIdentificado> _tiposIdentificados = [];

  @override
  bool get wantKeepAlive => true;

  Future<void> _uploadDocumento() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: true,
      );
    } on Exception catch (e) {
      debugPrint('[Upload] pickFiles falhou: $e');
      final cached = await _tryReadCachedPdfs();
      if (cached.isNotEmpty) {
        await _doUploadFiles(cached);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Nao foi possivel acessar o arquivo. "
              "Baixe o PDF para o dispositivo e tente novamente.",
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    if (result == null || result.files.isEmpty) return;

    final files = <PlatformFile>[];
    for (final f in result.files) {
      if (!f.name.toLowerCase().endsWith('.pdf')) continue;
      if (f.bytes != null && f.bytes!.isNotEmpty) {
        files.add(f);
      } else if (f.path != null) {
        try {
          final bytes = await File(f.path!).readAsBytes();
          files.add(PlatformFile(
            name: f.name,
            size: bytes.length,
            bytes: bytes,
          ));
        } catch (e) {
          debugPrint('[Upload] falha ao ler ${f.name}: $e');
        }
      }
    }
    if (files.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Selecione apenas arquivos PDF.")),
        );
      }
      return;
    }
    await _doUploadFiles(files);
  }

  Future<List<PlatformFile>> _tryReadCachedPdfs() async {
    final files = <PlatformFile>[];
    try {
      final appCacheBase = Platform.isAndroid
          ? '/data/user/0/br.mestredaobra.app/cache/file_picker'
          : '${Directory.systemTemp.path}/file_picker';
      final dir = Directory(appCacheBase);
      if (!await dir.exists()) return files;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          final bytes = await entity.readAsBytes();
          files.add(PlatformFile(
            name: entity.uri.pathSegments.last,
            size: bytes.length,
            bytes: bytes,
          ));
        }
      }
    } catch (e) {
      debugPrint('[Upload] cache fallback falhou: $e');
    }
    return files;
  }

  Future<void> _doUploadFiles(List<PlatformFile> files) async {
    setState(() {
      _enviando = true;
      for (final file in files) {
        _arquivosEnviados.add(file);
        _arquivosStatus.add("Enviando...");
      }
    });

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final idx = _arquivosEnviados.length - files.length + i;
      try {
        await _api.uploadProjeto(obraId: widget.obra.id, file: file);
        if (mounted) setState(() => _arquivosStatus[idx] = "Enviado");
      } catch (e) {
        if (e is AuthExpiredException) {
          if (mounted) handleApiError(context, e);
          return;
        }
        if (mounted) {
          setState(() => _arquivosStatus[idx] = "Erro");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro ao enviar ${file.name}: $e")),
          );
        }
      }
    }

    if (mounted) {
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${files.length} arquivo(s) enviado(s)!")),
      );
    }
  }

  Future<void> _analisarProjetos() async {
    setState(() => _analisando = true);
    try {
      final projetos = await _api.listarProjetos(widget.obra.id);
      final pendentes = <({String id, int idx})>[];
      for (final projeto in projetos) {
        if (projeto.status == "pendente") {
          final idx = _arquivosEnviados
              .indexWhere((f) => f.name == projeto.arquivoNome);
          if (idx >= 0 && mounted) {
            setState(() => _arquivosStatus[idx] = "Analisando...");
          }
          await _api.dispararAnalise(projeto.id);
          pendentes.add((id: projeto.id, idx: idx));
        }
      }

      final futures = pendentes.map((p) async {
        final resultado = await _api.aguardarAnalise(p.id);
        if (p.idx >= 0 && mounted) {
          setState(() {
            _arquivosStatus[p.idx] =
                resultado.status == "concluido" ? "Analisado" : "Erro";
          });
        }
      });
      await Future.wait(futures);

      if (mounted) {
        setState(() {
          for (int i = 0; i < _arquivosStatus.length; i++) {
            if (_arquivosStatus[i] == "Enviado") {
              _arquivosStatus[i] = "Analisado";
            }
          }
        });
      }

      final response = await _api.identificarTiposProjeto(widget.obra.id);
      if (!mounted) return;
      setState(() => _tiposIdentificados = response.tipos);
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) handleApiError(context, e);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao analisar: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _analisando = false);
    }
  }

  Future<void> _perguntarComplementares() async {
    final adicionar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Projetos complementares"),
        content: const Text("Deseja adicionar projetos complementares?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Nao"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sim"),
          ),
        ],
      ),
    );

    if (adicionar == true) return;
    widget.onAnaliseCompleta(_tiposIdentificados);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Projetos da obra",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text("Envie os PDFs dos projetos para analise automatica."),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _enviando ? null : _uploadDocumento,
              icon: _enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(_enviando ? "Enviando..." : "Enviar PDF"),
            ),
          ),
          if (_arquivosEnviados.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...List.generate(_arquivosEnviados.length, (i) {
              final file = _arquivosEnviados[i];
              final status = _arquivosStatus[i];
              return ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined,
                    color: Colors.indigo),
                title: Text(
                  file.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    color: status == "Erro"
                        ? Colors.red
                        : status == "Analisado"
                            ? Colors.blue
                            : status == "Analisando..."
                                ? Colors.orange
                                : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_analisando || _arquivosEnviados.isEmpty)
                  ? null
                  : _analisarProjetos,
              icon: _analisando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label:
                  Text(_analisando ? "Analisando..." : "Analisar Projetos"),
            ),
          ),
          if (_tiposIdentificados.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              "Projetos identificados (${_tiposIdentificados.length})",
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              "Desmarque os que nao se aplicam.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ..._tiposIdentificados.map((tipo) {
              return CheckboxListTile(
                value: tipo.confirmado,
                onChanged: (v) =>
                    setState(() => tipo.confirmado = v ?? true),
                title: Text(
                  tipo.nome,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  tipo.projetoDocNome != null &&
                          tipo.projetoDocNome!.isNotEmpty
                      ? "Fonte: ${tipo.projetoDocNome} · ${tipo.confianca}% confianca"
                      : "${tipo.confianca}% confianca",
                  style: const TextStyle(fontSize: 12),
                ),
                secondary: Icon(
                  Icons.description_outlined,
                  color: tipo.confianca >= 80
                      ? Colors.green
                      : tipo.confianca >= 50
                          ? Colors.orange
                          : Colors.red,
                ),
                dense: true,
                controlAffinity: ListTileControlAffinity.trailing,
              );
            }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _perguntarComplementares,
                child: const Text("Continuar"),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
