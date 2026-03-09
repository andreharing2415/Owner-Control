import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../models/convite.dart";
import "../../providers/convite_provider.dart";
import "../../providers/subscription_provider.dart";
import "../../services/api_client.dart";
import "../subscription/paywall_screen.dart";

class ConvitesScreen extends StatefulWidget {
  const ConvitesScreen({super.key, required this.obraId, required this.obraNome});

  final String obraId;
  final String obraNome;

  @override
  State<ConvitesScreen> createState() => _ConvitesScreenState();
}

class _ConvitesScreenState extends State<ConvitesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConviteProvider>().carregarConvites(widget.obraId);
    });
  }

  Future<void> _adicionarConvite() async {
    final sub = context.read<SubscriptionProvider>();
    if (sub.isGratuito) {
      PaywallScreen.show(context,
          message: "Convites disponíveis apenas para assinantes");
      return;
    }

    final conviteProvider = context.read<ConviteProvider>();
    if (conviteProvider.convitesAtivos >= sub.maxConvites) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("Limite de ${sub.maxConvites} convidado(s) atingido")),
      );
      return;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _NovoConviteDialog(),
    );
    if (result == null || !mounted) return;

    try {
      await conviteProvider.criarConvite(
        obraId: widget.obraId,
        email: result["email"]!,
        papel: result["papel"]!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Convite enviado para ${result["email"]}")),
        );
      }
    } on FeatureGateException catch (e) {
      if (mounted) PaywallScreen.show(context, message: e.message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _removerConvite(ObraConvite convite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remover convidado"),
        content: Text(
            "Remover ${convite.convidadoNome ?? convite.email}? O acesso será revogado imediatamente."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Remover")),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<ConviteProvider>().removerConvite(convite.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Convites - ${widget.obraNome}"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adicionarConvite,
        icon: const Icon(Icons.person_add),
        label: const Text("Convidar"),
      ),
      body: Consumer<ConviteProvider>(
        builder: (context, provider, _) {
          if (provider.loadingConvites) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.convites.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline,
                        size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      "Nenhum profissional convidado",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Convide arquitetos, engenheiros ou empreiteiros para colaborar na sua obra.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.convites.length,
            itemBuilder: (context, index) {
              final convite = provider.convites[index];
              return _ConviteCard(
                convite: convite,
                onRemover: () => _removerConvite(convite),
              );
            },
          );
        },
      ),
    );
  }
}

class _ConviteCard extends StatelessWidget {
  const _ConviteCard({required this.convite, required this.onRemover});
  final ObraConvite convite;
  final VoidCallback onRemover;

  Color _statusColor() {
    switch (convite.status) {
      case "aceito":
        return Colors.green;
      case "pendente":
        return Colors.orange;
      case "removido":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel() {
    switch (convite.status) {
      case "aceito":
        return "Aceito";
      case "pendente":
        return "Pendente";
      case "removido":
        return "Removido";
      default:
        return convite.status;
    }
  }

  IconData _papelIcon() {
    switch (convite.papel) {
      case "arquiteto":
        return Icons.architecture;
      case "engenheiro":
        return Icons.engineering;
      case "empreiteiro":
        return Icons.construction;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = convite.isPendente || convite.isAceito;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor().withAlpha(30),
          child: Icon(_papelIcon(), color: _statusColor()),
        ),
        title: Text(convite.convidadoNome ?? convite.email),
        subtitle: Text(
            "${convite.papel[0].toUpperCase()}${convite.papel.substring(1)} • ${_statusLabel()}"),
        trailing: isActive
            ? IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                tooltip: "Remover",
                onPressed: onRemover,
              )
            : null,
      ),
    );
  }
}

class _NovoConviteDialog extends StatefulWidget {
  const _NovoConviteDialog();

  @override
  State<_NovoConviteDialog> createState() => _NovoConviteDialogState();
}

class _NovoConviteDialogState extends State<_NovoConviteDialog> {
  final _emailCtrl = TextEditingController();
  String _papel = "engenheiro";

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Convidar Profissional"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: "E-mail do profissional",
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _papel,
            decoration: const InputDecoration(
              labelText: "Papel",
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            items: const [
              DropdownMenuItem(
                  value: "arquiteto", child: Text("Arquiteto(a)")),
              DropdownMenuItem(
                  value: "engenheiro", child: Text("Engenheiro(a)")),
              DropdownMenuItem(
                  value: "empreiteiro", child: Text("Empreiteiro(a)")),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _papel = v);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        FilledButton(
          onPressed: () {
            final email = _emailCtrl.text.trim();
            if (email.isEmpty || !email.contains("@")) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Informe um e-mail válido")),
              );
              return;
            }
            Navigator.pop(context, {"email": email, "papel": _papel});
          },
          child: const Text("Enviar Convite"),
        ),
      ],
    );
  }
}
