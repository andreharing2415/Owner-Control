# Fase 2: Financeiro Inline nas Etapas

**Sessao independente — sem dependencias de outras fases.**
**Requer deploy backend + build Flutter.**

---

## Objetivo

Cada card de etapa mostra valor previsto/gasto direto. Usuario pode lancar despesa sem sair do contexto da etapa. Elimina necessidade de navegar ao menu "Mais" para acessar financeiro.

---

## 1. Backend: Enriquecer resposta de etapas com dados financeiros

**Arquivo:** `server/app/main.py`

**Endpoint a modificar:** `GET /api/obras/{obra_id}` (usado por `listarEtapas` no Flutter)

**Implementacao:**
- No endpoint que retorna a obra com etapas, para cada etapa fazer LEFT JOIN com `orcamentoetapa` e SUM de `despesa`:
  ```python
  # Pseudo-codigo dentro do endpoint GET /api/obras/{obra_id}
  for etapa in obra.etapas:
      orcamento = session.exec(
          select(OrcamentoEtapa)
          .where(OrcamentoEtapa.etapa_id == etapa.id)
      ).first()

      total_gasto = session.exec(
          select(func.coalesce(func.sum(Despesa.valor), 0))
          .where(Despesa.etapa_id == etapa.id)
      ).scalar()

      etapa_dict["valor_previsto"] = orcamento.valor_previsto if orcamento else None
      etapa_dict["valor_gasto"] = float(total_gasto)
  ```

**Modelos existentes a reutilizar:**
- `OrcamentoEtapa` em `server/app/models.py` — tem `etapa_id`, `valor_previsto`
- `Despesa` em `server/app/models.py` — tem `etapa_id`, `valor`

---

## 2. Flutter: Model Etapa

**Arquivo:** `mobile/lib/models/etapa.dart`

**Adicionar campos:**
```dart
class Etapa {
  // ... campos existentes ...
  final double? valorPrevisto;  // NOVO
  final double? valorGasto;     // NOVO

  Etapa({
    // ... existentes ...
    this.valorPrevisto,
    this.valorGasto,
  });

  factory Etapa.fromJson(Map<String, dynamic> json) {
    return Etapa(
      // ... existentes ...
      valorPrevisto: (json["valor_previsto"] as num?)?.toDouble(),
      valorGasto: (json["valor_gasto"] as num?)?.toDouble(),
    );
  }
}
```

---

## 3. Flutter: Etapas Screen — cards com financeiro inline

**Arquivo:** `mobile/lib/screens/etapas/etapas_screen.dart`

**Modificacoes no card de etapa:**

1. Abaixo do subtitle (status/score), adicionar widget de barra orcamentaria:
   ```dart
   Widget _buildOrcamentoBar(Etapa etapa) {
     if (etapa.valorPrevisto == null || etapa.valorPrevisto! <= 0) {
       return const SizedBox.shrink();
     }
     final pct = (etapa.valorGasto ?? 0) / etapa.valorPrevisto!;
     final estourado = pct > 1.0;
     return Padding(
       padding: const EdgeInsets.only(top: 8),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           LinearProgressIndicator(
             value: pct.clamp(0.0, 1.0),
             backgroundColor: Colors.grey[200],
             color: estourado ? Colors.red : Colors.green,
           ),
           const SizedBox(height: 4),
           Text(
             "R\$ ${(etapa.valorGasto ?? 0).toStringAsFixed(0)} / R\$ ${etapa.valorPrevisto!.toStringAsFixed(0)}",
             style: TextStyle(
               fontSize: 12,
               color: estourado ? Colors.red : Colors.grey[600],
             ),
           ),
         ],
       ),
     );
   }
   ```

2. No PopupMenuButton da etapa, adicionar opcao "+ Despesa":
   ```dart
   PopupMenuItem(
     value: "despesa",
     child: Row(children: [
       Icon(Icons.attach_money, size: 20),
       SizedBox(width: 8),
       Text("Lancar despesa"),
     ]),
   ),
   ```

3. No handler do PopupMenu, tratar "despesa":
   ```dart
   case "despesa":
     final adicionou = await Navigator.push<bool>(context,
       MaterialPageRoute(builder: (_) => LancarDespesaScreen(
         api: widget.api,
         obraId: widget.obra.id,
         etapaId: etapa.id,    // PRE-SELECIONA
         etapaNome: etapa.nome,
       )),
     );
     if (adicionou == true) _refresh();
     break;
   ```

**Import a adicionar:** `import '../financeiro/lancar_despesa_screen.dart';`

---

## 4. Flutter: LancarDespesaScreen — aceitar etapaId pre-selecionado

**Arquivo:** `mobile/lib/screens/financeiro/lancar_despesa_screen.dart`

**Modificacao:**
- Adicionar parametros opcionais ao construtor: `String? etapaId`, `String? etapaNome`
- Se `etapaId` fornecido, pre-selecionar no dropdown de etapa e desabilitar mudanca (ou permitir mas iniciar selecionado)

---

## Verificacao

1. **Backend:** Apos deploy, chamar `GET /api/obras/{id}` e verificar que cada etapa retorna `valor_previsto` e `valor_gasto`.
2. **Flutter:** Abrir aba Etapas — cards com orcamento mostram barra de progresso verde/vermelha.
3. **Flutter:** Menu da etapa → "Lancar despesa" → form abre com etapa pre-selecionada.
4. **Flutter:** Lancar despesa, voltar → barra atualizada apos refresh.
5. Rodar `cd mobile && flutter analyze` — sem erros.

## Deploy

1. Backend: `bash server/deploy-cloudrun.sh`
2. Flutter: `cd mobile && flutter build apk --release`
