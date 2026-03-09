import "package:flutter/material.dart";

import "../../services/api_client.dart";

class AceitarConviteScreen extends StatefulWidget {
  const AceitarConviteScreen({
    super.key,
    required this.token,
    required this.api,
  });

  final String token;
  final ApiClient api;

  @override
  State<AceitarConviteScreen> createState() => _AceitarConviteScreenState();
}

class _AceitarConviteScreenState extends State<AceitarConviteScreen> {
  final _nomeCtrl = TextEditingController();
  bool _loading = false;
  String? _erro;
  bool _sucesso = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _aceitar() async {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = "Informe seu nome");
      return;
    }

    setState(() {
      _loading = true;
      _erro = null;
    });

    try {
      await widget.api.aceitarConvite(token: widget.token, nome: nome);
      if (mounted) {
        setState(() {
          _sucesso = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.toString().replaceFirst("Exception: ", "");
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_sucesso) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 72, color: Colors.green),
                const SizedBox(height: 20),
                Text(
                  "Convite aceito!",
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  "Você já tem acesso à obra. Faça login para visualizar.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () => Navigator.of(context).popUntil(
                    (route) => route.isFirst,
                  ),
                  child: const Text("Ir para o app"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Aceitar Convite")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mail_outline,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                "Você foi convidado!",
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Um proprietário convidou você para colaborar na obra dele. Informe seu nome para aceitar.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(
                  labelText: "Seu nome completo",
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                enabled: !_loading,
              ),
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Text(
                  _erro!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _aceitar,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Aceitar Convite"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
