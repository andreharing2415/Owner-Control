import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../providers/auth_provider.dart";

/// Exibida a usuários Google novos para completar nome e telefone.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  final _telefoneController = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nomeController = TextEditingController(text: user?.nome ?? "");
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await context.read<AuthProvider>().updateProfile(
            nome: _nomeController.text.trim(),
            telefone: _telefoneController.text.trim().isEmpty
                ? null
                : _telefoneController.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e.toString().replaceFirst("Exception: ", ""));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Complete seu perfil"),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Precisamos de mais algumas informações para criar sua conta.",
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 24),
              if (_erro != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(_erro!,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: "Nome completo *",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outlined),
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Informe seu nome";
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(
                  labelText: "Telefone (opcional)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _salvar(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _salvando ? null : _salvar,
                  child: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Salvar e continuar"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
