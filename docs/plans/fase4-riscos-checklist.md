# Fase 4: Riscos dos Documentos → Checklist Automatico

**Sessao independente — sem dependencias de outras fases.**
**Requer deploy backend + build Flutter.**

---

## Objetivo

Apos analise de documento (PDF), riscos identificados sao automaticamente sugeridos como itens de checklist nas etapas relevantes. O usuario revisa e aplica com um clique, sem precisar navegar manualmente ao Checklist Inteligente.

---

## 1. Backend: Endpoint de riscos pendentes

**Arquivo:** `server/app/main.py`

**Novo endpoint:**
```python
@app.get("/api/obras/{obra_id}/riscos-pendentes")
def listar_riscos_pendentes(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Retorna riscos de documentos analisados que ainda nao viraram checklist items."""
    # 1. Buscar todos os ProjetoDoc analisados da obra
    docs = session.exec(
        select(ProjetoDoc)
        .where(ProjetoDoc.obra_id == obra_id)
        .where(ProjetoDoc.status == "concluido")
    ).all()

    # 2. Extrair riscos de cada doc
    riscos_pendentes = []
    for doc in docs:
        if not doc.riscos:
            continue
        for risco in doc.riscos:
            # Verificar se ja existe item com mesmo titulo na obra
            existe = session.exec(
                select(ChecklistItem)
                .join(Etapa)
                .where(Etapa.obra_id == obra_id)
                .where(ChecklistItem.titulo == risco.descricao)
            ).first()
            if not existe:
                riscos_pendentes.append({
                    "id": str(risco.id),
                    "descricao": risco.descricao,
                    "severidade": risco.severidade,
                    "norma_referencia": risco.norma_referencia,
                    "traducao_leigo": risco.traducao_leigo,
                    "etapa_sugerida": risco.etapa_sugerida,  # se existir no model
                    "documento_nome": doc.nome,
                })

    return {"riscos": riscos_pendentes, "total": len(riscos_pendentes)}
```

**Nota:** Verificar model `Risco` em `server/app/models.py` para campos exatos. O campo `etapa_sugerida` pode precisar ser inferido do `CARACTERISTICA_ETAPA_MAP` em `checklist_inteligente.py`.

---

## 2. Flutter: API Client

**Arquivo:** `mobile/lib/services/api_client.dart`

**Novo metodo:**
```dart
Future<Map<String, dynamic>> listarRiscosPendentes(String obraId) async {
  final response = await _get("/api/obras/$obraId/riscos-pendentes");
  if (response.statusCode != 200) {
    throw Exception("Erro ao buscar riscos pendentes");
  }
  return jsonDecode(response.body) as Map<String, dynamic>;
}
```

---

## 3. Flutter: Banner de riscos na DocumentosScreen

**Arquivo:** `mobile/lib/screens/documentos/documentos_screen.dart`

**Modificacoes:**

1. Adicionar estado para riscos pendentes:
   ```dart
   int _riscosPendentes = 0;

   Future<void> _checkRiscosPendentes() async {
     try {
       final result = await widget.api.listarRiscosPendentes(widget.obraId);
       if (mounted) {
         setState(() => _riscosPendentes = result["total"] as int);
       }
     } catch (_) {}
   }
   ```

2. Chamar `_checkRiscosPendentes()` no `initState()` e apos `_refresh()`.

3. No body, antes da lista de documentos, se `_riscosPendentes > 0`:
   ```dart
   if (_riscosPendentes > 0)
     Card(
       color: Colors.orange.shade50,
       margin: const EdgeInsets.all(16),
       child: ListTile(
         leading: Icon(Icons.warning_amber, color: Colors.orange),
         title: Text("$_riscosPendentes riscos identificados"),
         subtitle: Text("Adicionar ao checklist das etapas?"),
         trailing: FilledButton(
           onPressed: () => Navigator.push(context,
             MaterialPageRoute(builder: (_) => RiscosReviewScreen(
               api: widget.api,
               obraId: widget.obraId,
             )),
           ).then((_) => _refresh()),
           child: Text("Revisar"),
         ),
       ),
     ),
   ```

---

## 4. Flutter: Nova tela RiscosReviewScreen

**Novo arquivo:** `mobile/lib/screens/documentos/riscos_review_screen.dart`

**Funcionalidade:**
- Lista riscos pendentes agrupados por etapa sugerida
- Cada risco tem checkbox (pre-selecionado), severidade badge, descricao
- Botao "Aplicar selecionados" que:
  - Para cada risco selecionado, chama endpoint existente de criacao de checklist item
  - OU reutiliza `aplicarChecklistInteligente()` se a API suportar
- Mostra resultado (N itens criados)
- Pop com refresh

**Estrutura:**
```dart
class RiscosReviewScreen extends StatefulWidget {
  final ApiClient api;
  final String obraId;
  // ...
}

class _RiscosReviewScreenState extends State<RiscosReviewScreen> {
  List<Map<String, dynamic>> _riscos = [];
  Set<String> _selecionados = {};
  bool _loading = true;
  bool _aplicando = false;

  @override
  void initState() {
    super.initState();
    _carregarRiscos();
  }

  Future<void> _carregarRiscos() async {
    final result = await widget.api.listarRiscosPendentes(widget.obraId);
    final riscos = (result["riscos"] as List).cast<Map<String, dynamic>>();
    setState(() {
      _riscos = riscos;
      _selecionados = riscos.map((r) => r["id"] as String).toSet();
      _loading = false;
    });
  }

  Future<void> _aplicar() async {
    setState(() => _aplicando = true);
    try {
      // Chamar endpoint para aplicar riscos selecionados como checklist items
      // Pode ser um novo endpoint POST /api/obras/{id}/aplicar-riscos
      // ou reutilizar o fluxo de aplicarChecklistInteligente
      // ...
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // error handling
    } finally {
      if (mounted) setState(() => _aplicando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Riscos Identificados")),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _riscos.length,
              itemBuilder: (ctx, i) {
                final risco = _riscos[i];
                final id = risco["id"] as String;
                return CheckboxListTile(
                  value: _selecionados.contains(id),
                  onChanged: (v) => setState(() {
                    v == true ? _selecionados.add(id) : _selecionados.remove(id);
                  }),
                  title: Text(risco["descricao"]),
                  subtitle: Text("${risco["severidade"]} • ${risco["etapa_sugerida"] ?? 'Sem etapa'}"),
                  secondary: _severidadeBadge(risco["severidade"]),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _selecionados.isEmpty || _aplicando ? null : _aplicar,
            child: _aplicando
                ? CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                : Text("Aplicar ${_selecionados.length} ao checklist"),
          ),
        ),
      ),
    );
  }
}
```

---

## 5. Backend: Endpoint para aplicar riscos

**Arquivo:** `server/app/main.py`

**Novo endpoint (se necessario):**
```python
@app.post("/api/obras/{obra_id}/aplicar-riscos")
def aplicar_riscos(
    obra_id: UUID,
    body: dict,  # { "risco_ids": ["uuid1", "uuid2", ...] }
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Converte riscos selecionados em ChecklistItems nas etapas sugeridas."""
    risco_ids = body.get("risco_ids", [])
    criados = 0
    for risco_id in risco_ids:
        risco = session.get(Risco, UUID(risco_id))
        if not risco:
            continue

        # Determinar etapa alvo
        etapa = _encontrar_etapa_para_risco(session, obra_id, risco)
        if not etapa:
            continue

        # Criar ChecklistItem a partir do risco
        item = ChecklistItem(
            etapa_id=etapa.id,
            titulo=risco.descricao,
            descricao=risco.traducao_leigo,
            origem="ia",
            severidade=risco.severidade,
            traducao_leigo=risco.traducao_leigo,
            norma_referencia=risco.norma_referencia,
            dado_projeto=risco.dado_projeto,
            verificacoes=risco.verificacoes,
            pergunta_engenheiro=risco.pergunta_engenheiro,
            documentos_a_exigir=risco.documentos_a_exigir,
            confianca=risco.confianca,
        )
        session.add(item)
        criados += 1

    session.commit()
    return {"criados": criados}
```

---

## Verificacao

1. **Backend:** Upload + analise de PDF → `GET /api/obras/{id}/riscos-pendentes` retorna riscos.
2. **Flutter:** DocumentosScreen mostra banner laranja "N riscos identificados".
3. **Flutter:** Tap "Revisar" → tela com checkboxes.
4. **Flutter:** Selecionar riscos → "Aplicar" → itens criados nas etapas.
5. **Flutter:** Voltar → banner desaparece (riscos aplicados).
6. Rodar `cd mobile && flutter analyze` — sem erros.

## Deploy

1. Backend: `bash server/deploy-cloudrun.sh`
2. Flutter: `cd mobile && flutter build apk --release`
