import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../providers/auth_provider.dart';
import '../utils/auth_error_handler.dart';
import '../services/auth_service.dart';

class AceitarConviteScreen extends StatefulWidget {
  const AceitarConviteScreen({super.key, this.token});
  final String? token;

  @override
  State<AceitarConviteScreen> createState() => _AceitarConviteScreenState();
}

class _AceitarConviteScreenState extends State<AceitarConviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  bool _loading = false;
  bool _sucesso = false;

  @override
  void initState() {
    super.initState();
    if (widget.token != null) {
      _tokenCtrl.text = widget.token!;
    }
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _aceitar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final api = ApiClient();
      final result = await api.aceitarConvite(
        token: _tokenCtrl.text.trim(),
        nome: _nomeCtrl.text.trim(),
      );

      // Salvar tokens e autenticar
      await AuthService.instance.saveTokens(
        accessToken: result['access_token'] as String,
        refreshToken: result['refresh_token'] as String,
        user: result['user'] as Map<String, dynamic>,
      );

      if (mounted) {
        // Recarregar auth para navegar ao app
        await context.read<AuthProvider>().checkAuth();
        setState(() => _sucesso = true);
      }
    } catch (e) {
      if (mounted) handleApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_sucesso) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              Text('Convite aceito!', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Você já pode acessar a obra.'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Ir para o app'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Aceitar Convite')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.mail_outline, size: 56, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                'Você recebeu um convite para acompanhar uma obra.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _tokenCtrl,
                decoration: const InputDecoration(
                  labelText: 'Código do convite',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe o código' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Seu nome completo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe seu nome' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _aceitar,
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white,
                          ),
                        )
                      : const Text('Aceitar Convite'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
