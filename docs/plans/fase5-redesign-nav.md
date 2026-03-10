# Fase 5: Redesign Completo da Navegacao

**DEPENDE das Fases 2, 3 e 4 estarem completas.**
**Apenas Flutter — sem mudancas no backend.**

---

## Objetivo

Simplificar a navegacao de 5 tabs condicionais para 4 tabs fixos:

```
ANTES:  [Inicio] [Etapas] [Documentos*] [Normas*] [Mais]
DEPOIS: [Inicio] [Obra]   [IA]          [Perfil]

* = visivel apenas para owner (confuso para convidados)
```

Principios de design:
- **Etapa-centrico:** Tudo flui a partir do contexto da etapa de construcao
- **IA como hub:** Todas funcionalidades de IA num so lugar
- **Menos taps:** Acoes rapidas acessiveis diretamente
- **Consistente:** Mesmas 4 tabs para todos os usuarios (owner e convidado)

---

## 1. Novo HomeScreen (reescrever tabs)

**Arquivo:** `mobile/lib/screens/home/home_screen.dart`

### Mudancas estruturais:

1. **Remover** condicional `if (!isConvidado)` dos tabs
2. **Remover** `_showMaisMenu()` completamente
3. **Fixar** `_navKeys = List.generate(4, ...)`

### Novos tabs:
```dart
final pages = <Widget>[
  // Tab 0: Inicio (Dashboard) — manter existente
  Navigator(
    key: _navKeys[0],
    onGenerateRoute: (_) => MaterialPageRoute(
      builder: (_) => _DashboardPage(obra: obra, api: _api, onSelectObra: _selecionarObra),
    ),
  ),
  // Tab 1: Obra (Etapas com financeiro inline)
  Navigator(
    key: _navKeys[1],
    onGenerateRoute: (_) => MaterialPageRoute(
      builder: (_) => EtapasScreen(obra: obra, api: _api),
    ),
  ),
  // Tab 2: IA (Hub de funcionalidades IA) — NOVO
  Navigator(
    key: _navKeys[2],
    onGenerateRoute: (_) => MaterialPageRoute(
      builder: (_) => IAHubScreen(obra: obra, api: _api),
    ),
  ),
  // Tab 3: Perfil — NOVO
  Navigator(
    key: _navKeys[3],
    onGenerateRoute: (_) => MaterialPageRoute(
      builder: (_) => PerfilScreen(api: _api, onSelectObra: _selecionarObra),
    ),
  ),
];

final navItems = const <BottomNavigationBarItem>[
  BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
  BottomNavigationBarItem(icon: Icon(Icons.construction), label: 'Obra'),
  BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'IA'),
  BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
];
```

4. **Simplificar onTap:** Remover o caso especial do "Mais" menu:
```dart
onTap: (index) {
  if (index == safeTab) {
    _navKeys[safeTab].currentState?.popUntil((r) => r.isFirst);
  } else {
    setState(() => _currentTab = index);
  }
},
```

### Novos imports:
```dart
import '../ia/ia_hub_screen.dart';
import '../perfil/perfil_screen.dart';
```

### Remover imports nao mais necessarios:
```dart
// Remover (movidos para IAHubScreen/PerfilScreen):
// import '../normas/normas_screen.dart';
// import '../documentos/documentos_screen.dart';
// import '../financeiro/financeiro_screen.dart';
// import '../prestadores/prestadores_screen.dart';
// import '../conta/minha_conta_screen.dart';
// import '../convites/convites_screen.dart';
```

---

## 2. Nova tela: IAHubScreen

**Novo arquivo:** `mobile/lib/screens/ia/ia_hub_screen.dart`

**Design:** Grid de cards com icone, titulo e descricao curta. Visual limpo e moderno.

```dart
class IAHubScreen extends StatelessWidget {
  final Obra obra;
  final ApiClient api;

  const IAHubScreen({super.key, required this.obra, required this.api});

  @override
  Widget build(BuildContext context) {
    final isConvidado = context.read<AuthProvider>().user?.isConvidado ?? false;

    final acoes = <_IAAction>[
      if (!isConvidado) ...[
        _IAAction(
          icon: Icons.camera_alt,
          titulo: "Analisar Foto",
          descricao: "Tire uma foto da obra e a IA identifica problemas",
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => VisualAiScreen(obra: obra, api: api),
          )),
        ),
        _IAAction(
          icon: Icons.description,
          titulo: "Documentos",
          descricao: "Upload e analise de projetos PDF",
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => DocumentosScreen(obraId: obra.id, api: api),
          )),
        ),
        _IAAction(
          icon: Icons.checklist,
          titulo: "Gerar Checklist IA",
          descricao: "Checklist inteligente a partir dos documentos",
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChecklistInteligenteScreen(
              obraId: obra.id, api: api, autoStart: false,
            ),
          )),
        ),
        _IAAction(
          icon: Icons.auto_awesome,
          titulo: "Enriquecer Checklist",
          descricao: "IA analisa itens existentes e preenche 3 blocos",
          onTap: () => _selecionarEtapaParaEnriquecer(context),
        ),
      ],
      _IAAction(
        icon: Icons.menu_book,
        titulo: "Normas Tecnicas",
        descricao: "Consulte normas ABNT/NBR em linguagem simples",
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => NormasScreen(api: api),
        )),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text("Inteligencia Artificial"),
      ),
      body: ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: acoes.length,
        separatorBuilder: (_, __) => SizedBox(height: 12),
        itemBuilder: (ctx, i) => _buildActionCard(context, acoes[i]),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, _IAAction acao) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(acao.icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(acao.titulo, style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(acao.descricao),
        trailing: Icon(Icons.chevron_right),
        onTap: acao.onTap,
      ),
    );
  }

  void _selecionarEtapaParaEnriquecer(BuildContext context) async {
    // Carregar etapas, mostrar dialog de selecao, depois chamar batch enrich
    final etapas = await api.listarEtapas(obra.id);
    if (!context.mounted) return;
    final etapa = await showDialog<Etapa>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text("Selecione a etapa"),
        children: etapas.map((e) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, e),
          child: Text(e.nome),
        )).toList(),
      ),
    );
    if (etapa == null || !context.mounted) return;
    // Chamar enriquecerChecklist (Fase 3)
    try {
      final result = await api.enriquecerChecklist(etapa.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${result['enriquecidos']} itens enriquecidos!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e")),
      );
    }
  }
}

class _IAAction {
  final IconData icon;
  final String titulo;
  final String descricao;
  final VoidCallback onTap;

  _IAAction({
    required this.icon,
    required this.titulo,
    required this.descricao,
    required this.onTap,
  });
}
```

**Imports necessarios:**
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/obra.dart';
import '../../models/etapa.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../visual_ai/visual_ai_screen.dart';
import '../documentos/documentos_screen.dart';
import '../checklist_inteligente/checklist_inteligente_screen.dart';
import '../normas/normas_screen.dart';
```

---

## 3. Nova tela: PerfilScreen

**Novo arquivo:** `mobile/lib/screens/perfil/perfil_screen.dart`

```dart
class PerfilScreen extends StatelessWidget {
  final ApiClient api;
  final VoidCallback onSelectObra;

  const PerfilScreen({super.key, required this.api, required this.onSelectObra});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sub = context.watch<SubscriptionProvider>();
    final user = auth.user;
    final isConvidado = user?.isConvidado ?? false;

    return Scaffold(
      appBar: AppBar(title: Text("Perfil")),
      body: ListView(
        children: [
          // Header do usuario
          Container(
            padding: EdgeInsets.all(24),
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  child: Text(
                    (user?.nome ?? "?")[0].toUpperCase(),
                    style: TextStyle(fontSize: 28),
                  ),
                ),
                SizedBox(height: 12),
                Text(user?.nome ?? "", style: Theme.of(context).textTheme.titleLarge),
                Text(user?.email ?? "", style: Theme.of(context).textTheme.bodyMedium),
                SizedBox(height: 8),
                Chip(
                  label: Text(sub.isDono ? "Plano Dono da Obra" : "Plano Gratuito"),
                  backgroundColor: sub.isDono ? Colors.green.shade100 : Colors.grey.shade200,
                ),
              ],
            ),
          ),

          // Opcoes
          ListTile(
            leading: Icon(Icons.swap_horiz),
            title: Text("Trocar Obra"),
            onTap: onSelectObra,
          ),
          Divider(height: 1),

          if (!isConvidado) ...[
            ListTile(
              leading: Icon(Icons.people),
              title: Text("Convites"),
              subtitle: Text("Convide profissionais para a obra"),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ConvitesScreen(api: api),
              )),
            ),
            Divider(height: 1),

            ListTile(
              leading: Icon(Icons.engineering),
              title: Text("Prestadores"),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => PrestadoresScreen(api: api),
              )),
            ),
            Divider(height: 1),
          ],

          if (!sub.isDono) ...[
            ListTile(
              leading: Icon(Icons.star, color: Colors.amber),
              title: Text("Assinar Plano Dono"),
              subtitle: Text("Desbloqueie todas as funcionalidades"),
              onTap: () => PaywallScreen.show(context),
            ),
            Divider(height: 1),
          ],

          ListTile(
            leading: Icon(Icons.settings),
            title: Text("Minha Conta"),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => MinhaContaScreen(api: api),
            )),
          ),
          Divider(height: 1),

          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text("Sair", style: TextStyle(color: Colors.red)),
            onTap: () async {
              await context.read<AuthProvider>().logout();
            },
          ),
        ],
      ),
    );
  }
}
```

**Imports:**
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/api_client.dart';
import '../convites/convites_screen.dart';
import '../prestadores/prestadores_screen.dart';
import '../conta/minha_conta_screen.dart';
import '../subscription/paywall_screen.dart';
```

---

## 4. Limpar EtapasScreen

**Arquivo:** `mobile/lib/screens/etapas/etapas_screen.dart`

**Mudancas no AppBar:**
- Remover icone de "Normas" (agora no tab IA)
- Remover icone de "Checklist IA" (agora no tab IA)
- Manter: refresh + export PDF

**Popup menu da etapa — adicionar "Documentos":**
```dart
PopupMenuItem(
  value: "documentos",
  child: Row(children: [
    Icon(Icons.description, size: 20),
    SizedBox(width: 8),
    Text("Documentos"),
  ]),
),
```
Handler:
```dart
case "documentos":
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => DocumentosScreen(obraId: widget.obra.id, api: widget.api),
  ));
  break;
```

---

## 5. Atualizar Dashboard (opcional)

**Arquivo:** `mobile/lib/screens/home/home_screen.dart` (`_DashboardPage`)

Considerar adicionar quick action buttons no dashboard:
```dart
// Acoes rapidas
Wrap(
  spacing: 8,
  children: [
    ActionChip(label: Text("Nova Despesa"), avatar: Icon(Icons.attach_money, size: 18), onPressed: ...),
    ActionChip(label: Text("Analisar Foto"), avatar: Icon(Icons.camera_alt, size: 18), onPressed: ...),
    ActionChip(label: Text("Upload PDF"), avatar: Icon(Icons.upload_file, size: 18), onPressed: ...),
  ],
),
```

---

## Verificacao

1. **Navegacao:** 4 tabs visiveis (Inicio, Obra, IA, Perfil) para owner E convidado.
2. **Tab Obra:** Etapas com financeiro inline (da Fase 2).
3. **Tab IA:** Todas funcionalidades IA acessiveis (Analisar Foto, Documentos, Gerar Checklist, Enriquecer, Normas).
4. **Tab Perfil:** Info usuario, trocar obra, convites, prestadores, conta, sair.
5. **Convidado:** Tab IA mostra apenas "Normas Tecnicas". Tab Perfil sem convites/prestadores.
6. **Back button:** Funciona corretamente em cada tab (pop interno antes de mudar tab).
7. **Todas funcionalidades acessiveis:** Testar cada caminho de navegacao antigo para garantir que nada ficou inacessivel.
8. Rodar `cd mobile && flutter analyze` — sem erros.

## Deploy

- Apenas build Flutter (APK): `cd mobile && flutter build apk --release`
- **NAO precisa deploy backend** — nenhuma mudanca no server.
