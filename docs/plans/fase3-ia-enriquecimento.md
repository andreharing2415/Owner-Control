# Fase 3: IA Enriquece Checklist Padrao

**Sessao independente — sem dependencias de outras fases.**
**Requer deploy backend + build Flutter.**

---

## Objetivo

Itens de checklist criados manualmente (padrao) podem ser enriquecidos pela IA com os 3 blocos (dado_projeto, verificacoes, pergunta_engenheiro). Dois modos: item individual e batch por etapa.

---

## 1. Backend: Funcao de enriquecimento unitario

**Arquivo:** `server/app/checklist_inteligente.py`

**Nova funcao** `enriquecer_item_unico()`:
- Recebe: titulo, descricao, etapa_nome, contexto dos documentos analisados da obra
- Reutiliza a cadeia de fallback existente (Claude → OpenAI → Gemini)
- Reutiliza o prompt de geracao de itens ja existente, adaptado para 1 item
- Retorna: dict com campos dos 3 blocos (severidade, traducao_leigo, dado_projeto, verificacoes, pergunta_engenheiro, norma_referencia, documentos_a_exigir, confianca)

**Logica:**
```python
def enriquecer_item_unico(
    titulo: str,
    descricao: str,
    etapa_nome: str,
    contexto_docs: str,  # texto concatenado dos docs analisados da obra
) -> dict:
    """Enriquece um item de checklist com analise IA baseada nos documentos do projeto."""
    prompt = f"""
    Analise este item de checklist de obra no contexto dos documentos do projeto.

    Item: {titulo}
    Descricao: {descricao or 'Sem descricao'}
    Etapa: {etapa_nome}

    Documentos do projeto:
    {contexto_docs}

    Retorne JSON com:
    - severidade: "alto" | "medio" | "baixo"
    - traducao_leigo: explicacao simples para proprietario leigo
    - dado_projeto: {{ descricao, especificacao, fonte, valor_referencia }}
    - verificacoes: [{{ instrucao, tipo, valor_esperado }}]
    - pergunta_engenheiro: {{ contexto, pergunta }}
    - norma_referencia: norma ABNT/NBR aplicavel (string)
    - documentos_a_exigir: [strings]
    - confianca: 0-100
    """
    # Usar cadeia de fallback existente (ver gerar_itens_para_caracteristica)
    ...
```

**Referencia existente:** Funcao `gerar_itens_para_caracteristica()` no mesmo arquivo — reutilizar o padrao de prompt e fallback.

---

## 2. Backend: Novos endpoints

**Arquivo:** `server/app/main.py`

### Endpoint 1: Enriquecer item individual
```python
@app.post("/api/checklist-items/{item_id}/enriquecer")
def enriquecer_item(
    item_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    # 1. Feature gate: apenas plano Dono
    check_feature(session, current_user, "checklist_ia")

    # 2. Buscar item + etapa
    item = session.get(ChecklistItem, item_id)
    etapa = session.get(Etapa, item.etapa_id)

    # 3. Buscar contexto dos docs analisados da obra
    docs = session.exec(
        select(ProjetoDoc).where(ProjetoDoc.obra_id == etapa.obra_id)
    ).all()
    contexto = "\n".join(d.conteudo_extraido or "" for d in docs)

    # 4. Chamar IA
    enrichment = enriquecer_item_unico(
        titulo=item.titulo,
        descricao=item.descricao or "",
        etapa_nome=etapa.nome,
        contexto_docs=contexto,
    )

    # 5. Atualizar item com campos dos 3 blocos
    for key, value in enrichment.items():
        setattr(item, key, value)
    item.origem = "ia"  # marcar como enriquecido
    session.add(item)
    session.commit()
    session.refresh(item)

    return item
```

### Endpoint 2: Enriquecer batch por etapa
```python
@app.post("/api/etapas/{etapa_id}/enriquecer-checklist")
def enriquecer_checklist_etapa(
    etapa_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    check_feature(session, current_user, "checklist_ia")

    etapa = session.get(Etapa, etapa_id)

    # Buscar items NAO enriquecidos (origem = "padrao" e sem dado_projeto)
    items = session.exec(
        select(ChecklistItem)
        .where(ChecklistItem.etapa_id == etapa_id)
        .where(ChecklistItem.origem == "padrao")
    ).all()

    if not items:
        return {"enriquecidos": 0, "mensagem": "Todos os itens ja foram enriquecidos."}

    # Buscar contexto docs
    docs = session.exec(
        select(ProjetoDoc).where(ProjetoDoc.obra_id == etapa.obra_id)
    ).all()
    contexto = "\n".join(d.conteudo_extraido or "" for d in docs)

    count = 0
    for item in items:
        try:
            enrichment = enriquecer_item_unico(
                titulo=item.titulo,
                descricao=item.descricao or "",
                etapa_nome=etapa.nome,
                contexto_docs=contexto,
            )
            for key, value in enrichment.items():
                setattr(item, key, value)
            item.origem = "ia"
            session.add(item)
            count += 1
        except Exception as e:
            logger.warning(f"Falha ao enriquecer item {item.id}: {e}")

    session.commit()
    return {"enriquecidos": count, "total": len(items)}
```

**Feature gate:** Reutilizar `check_feature()` de `server/app/subscription.py`.

---

## 3. Flutter: API Client

**Arquivo:** `mobile/lib/services/api_client.dart`

**Novos metodos:**
```dart
Future<ChecklistItem> enriquecerItem(String itemId) async {
  final response = await _post("/api/checklist-items/$itemId/enriquecer");
  if (response.statusCode == 403) {
    onFeatureGate?.call();
    throw Exception("Funcionalidade exclusiva do plano Dono da Obra");
  }
  if (response.statusCode != 200) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(body["detail"] ?? "Erro ao enriquecer item");
  }
  return ChecklistItem.fromJson(jsonDecode(response.body));
}

Future<Map<String, dynamic>> enriquecerChecklist(String etapaId) async {
  final response = await _post("/api/etapas/$etapaId/enriquecer-checklist");
  if (response.statusCode == 403) {
    onFeatureGate?.call();
    throw Exception("Funcionalidade exclusiva do plano Dono da Obra");
  }
  if (response.statusCode != 200) {
    throw Exception("Erro ao enriquecer checklist");
  }
  return jsonDecode(response.body) as Map<String, dynamic>;
}
```

---

## 4. Flutter: Botao "Analisar com IA" no DetalheItemScreen

**Arquivo:** `mobile/lib/screens/checklist/detalhe_item_screen.dart`

**Modificacao:** Onde exibe banner estatico para items nao-enriquecidos, adicionar botao acionavel:

```dart
// Se item nao tem dados IA (nao e enriquecido)
if (!_item.isEnriquecido)
  Card(
    color: Colors.blue.shade50,
    child: ListTile(
      leading: Icon(Icons.auto_awesome, color: Colors.blue),
      title: Text("Analisar com IA"),
      subtitle: Text("Preencher os 3 blocos com analise inteligente"),
      trailing: _enriquecendo
          ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(Icons.arrow_forward_ios, size: 16),
      onTap: _enriquecendo ? null : _enriquecerItem,
    ),
  ),
```

**Novo metodo no state:**
```dart
bool _enriquecendo = false;

Future<void> _enriquecerItem() async {
  setState(() => _enriquecendo = true);
  try {
    final enriched = await widget.api.enriquecerItem(_item.id);
    setState(() => _item = enriched);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Item enriquecido com sucesso!")),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e")),
      );
    }
  } finally {
    if (mounted) setState(() => _enriquecendo = false);
  }
}
```

---

## 5. Flutter: Botao "Enriquecer com IA" no ChecklistScreen

**Arquivo:** `mobile/lib/screens/checklist/checklist_screen.dart`

**Adicionar no AppBar actions:**
```dart
IconButton(
  icon: const Icon(Icons.auto_awesome),
  tooltip: "Enriquecer todos com IA",
  onPressed: _enriquecerTodos,
),
```

**Novo metodo:**
```dart
Future<void> _enriquecerTodos() async {
  final confirma = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.auto_awesome, color: Colors.blue),
      title: Text("Enriquecer Checklist com IA?"),
      content: Text(
        "A IA vai analisar todos os itens padrao desta etapa e preencher "
        "os 3 blocos (projeto, verificacao, norma) com base nos documentos da obra."
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancelar")),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text("Enriquecer")),
      ],
    ),
  );
  if (confirma != true) return;

  // Mostrar loading
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Enriquecendo itens com IA..."), duration: Duration(seconds: 30)),
  );

  try {
    final result = await widget.api.enriquecerChecklist(widget.etapaId);
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${result['enriquecidos']} itens enriquecidos!")),
      );
      _refresh();
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e")),
      );
    }
  }
}
```

---

## Verificacao

1. **Backend:** POST `/api/checklist-items/{id}/enriquecer` com item padrao → retorna item com 3 blocos preenchidos.
2. **Backend:** POST `/api/etapas/{id}/enriquecer-checklist` → retorna contagem de enriquecidos.
3. **Flutter:** Abrir item padrao → botao "Analisar com IA" visivel → tap → blocos aparecem.
4. **Flutter:** Tela checklist → icone estrela no AppBar → confirmar → itens enriquecidos apos refresh.
5. **Feature gate:** Usuario gratuito → tap → paywall aparece.
6. Rodar `cd mobile && flutter analyze` — sem erros.

## Deploy

1. Backend: `bash server/deploy-cloudrun.sh`
2. Flutter: `cd mobile && flutter build apk --release`
