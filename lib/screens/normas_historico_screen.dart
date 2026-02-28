import 'package:flutter/material.dart';
import '../api/api.dart';

class NormasHistoricoScreen extends StatefulWidget {
  const NormasHistoricoScreen({super.key});

  @override
  State<NormasHistoricoScreen> createState() => _NormasHistoricoScreenState();
}

class _NormasHistoricoScreenState extends State<NormasHistoricoScreen> {
  final ApiClient _api = ApiClient();
  late Future<List<NormaLogResumido>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.listarHistoricoNormas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Histórico de consultas")),
      body: FutureBuilder<List<NormaLogResumido>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }
          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text("Nenhuma consulta realizada ainda."),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.menu_book)),
                title: Text(log.etapaNome),
                subtitle: Text(
                    "${log.totalNormas} normas · ${log.localizacao ?? 'Sem localização'}"),
                trailing: Text(
                  log.dataConsulta.length >= 10
                      ? log.dataConsulta.substring(0, 10)
                      : log.dataConsulta,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
