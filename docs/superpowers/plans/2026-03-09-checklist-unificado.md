# Checklist Unificado Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify risks into checklist items so the checklist becomes the single hub for quality control, with 3 expandable blocks (detalhamento, verificação, norma/engenheiro) filled by AI analysis.

**Architecture:** Add 3-layer risk fields to ChecklistItem model. Create new verification endpoint. Modify AI pipeline to return enriched items. Rebuild Flutter detail screen with 3 expandable blocks. Remove standalone risk screens and endpoints.

**Tech Stack:** Python/FastAPI, SQLModel/Alembic, Flutter/Dart, Claude/OpenAI/Gemini AI APIs

---

## File Structure

### Backend files to modify:
- `server/app/models.py` — Add 3-layer fields to ChecklistItem, keep Risco temporarily
- `server/app/schemas.py` — Add fields to ChecklistItemRead/Create/Update, add RegistrarVerificacaoChecklistRequest
- `server/app/main.py` — Add POST `/api/checklist-items/{item_id}/verificar`, migrate data endpoint, remove risk endpoints later
- `server/app/checklist_inteligente.py` — Update Phase 2 prompt and output to include 3-layer data
- `server/alembic/versions/` — New migration for ChecklistItem fields

### Flutter files to modify:
- `mobile/lib/models/checklist_item.dart` — Add 3-layer fields + JSON parsing
- `mobile/lib/screens/checklist/detalhe_item_screen.dart` — Complete rewrite with 3 expandable blocks
- `mobile/lib/screens/checklist/checklist_screen.dart` — Add severity badge + AI icon to cards
- `mobile/lib/services/api_client.dart` — Add verificar method, update item schemas

### Flutter files to create:
- `mobile/lib/screens/checklist/verificacao_inline_widget.dart` — Reusable verification form widget

### Flutter files to remove (final task):
- `mobile/lib/screens/documentos/analise_documento_screen.dart`
- `mobile/lib/screens/documentos/detalhe_risco_screen.dart`
- `mobile/lib/screens/documentos/registrar_verificacao_screen.dart`
- `mobile/lib/models/documento.dart` (Risco class — keep AnaliseDocumento/ProjetoDoc if used)

---

## Chunk 1: Backend — Model + Migration + Schema

### Task 1: Add 3-layer fields to ChecklistItem model

**Files:**
- Modify: `server/app/models.py:52-65`

- [ ] **Step 1: Add new fields to ChecklistItem model**

In `server/app/models.py`, add these fields after `ordem` (line 63):

```python
class ChecklistItem(SQLModel, table=True):
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    etapa_id: UUID = Field(index=True, foreign_key="etapa.id")
    titulo: str
    descricao: Optional[str] = None
    status: str = Field(default="pendente")
    critico: bool = Field(default=False)
    observacao: Optional[str] = None
    norma_referencia: Optional[str] = None          # ex: "NBR 5410:2004"
    origem: str = Field(default="padrao")            # "padrao" | "ia"
    grupo: str = Field(default="Geral")              # ex: "Piscina", "Churrasqueira"
    ordem: int = Field(default=0)                    # ordenação cronológica dentro do grupo
    # ─── 3 Camadas (preenchido por IA) ─────────────────────────────────
    severidade: Optional[str] = None                 # "alto" | "medio" | "baixo"
    traducao_leigo: Optional[str] = None             # explicação simples para leigo
    dado_projeto: Optional[str] = None               # JSON: {descricao, especificacao, fonte, valor_referencia}
    verificacoes: Optional[str] = None               # JSON: [{instrucao, tipo, valor_esperado, como_medir}]
    pergunta_engenheiro: Optional[str] = None        # JSON: {contexto, pergunta, tom}
    documentos_a_exigir: Optional[str] = None        # JSON: ["doc1", "doc2"]
    registro_proprietario: Optional[str] = None      # JSON: {valor_medido, status, foto_ids, data_verificacao}
    resultado_cruzamento: Optional[str] = None       # JSON: {conclusao, resumo, acao, urgencia}
    status_verificacao: str = Field(default="pendente")  # "pendente" | "conforme" | "divergente" | "duvida"
    confianca: Optional[int] = None                  # 0-100, confiança da IA
    requer_validacao_profissional: bool = Field(default=False)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
```

- [ ] **Step 2: Commit**

```bash
git add server/app/models.py
git commit -m "feat(model): add 3-layer risk fields to ChecklistItem"
```

### Task 2: Create Alembic migration

**Files:**
- Create: `server/alembic/versions/20260309_0014_checklist_unificado.py`

- [ ] **Step 1: Create migration file**

```python
"""Checklist unificado: adiciona campos de 3 camadas ao ChecklistItem."""
from alembic import op
import sqlalchemy as sa

revision = "20260309_0014"
down_revision = "20260311_0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("checklistitem", sa.Column("severidade", sa.String(), nullable=True))
    op.add_column("checklistitem", sa.Column("traducao_leigo", sa.Text(), nullable=True))
    op.add_column("checklistitem", sa.Column("dado_projeto", sa.Text(), nullable=True))
    op.add_column("checklistitem", sa.Column("verificacoes", sa.Text(), nullable=True))
    op.add_column("checklistitem", sa.Column("pergunta_engenheiro", sa.Text(), nullable=True))
    op.add_column("checklistitem", sa.Column("documentos_a_exigir", sa.Text(), nullable=True))
    op.add_column("checklistitem", sa.Column("registro_proprietario", sa.Text(), nullable=True))
    op.add_column("checklistitem", sa.Column("resultado_cruzamento", sa.Text(), nullable=True))
    op.add_column("checklistitem", sa.Column("status_verificacao", sa.String(), server_default="pendente", nullable=False))
    op.add_column("checklistitem", sa.Column("confianca", sa.Integer(), nullable=True))
    op.add_column("checklistitem", sa.Column("requer_validacao_profissional", sa.Boolean(), server_default="false", nullable=False))


def downgrade() -> None:
    op.drop_column("checklistitem", "requer_validacao_profissional")
    op.drop_column("checklistitem", "confianca")
    op.drop_column("checklistitem", "status_verificacao")
    op.drop_column("checklistitem", "resultado_cruzamento")
    op.drop_column("checklistitem", "registro_proprietario")
    op.drop_column("checklistitem", "documentos_a_exigir")
    op.drop_column("checklistitem", "pergunta_engenheiro")
    op.drop_column("checklistitem", "verificacoes")
    op.drop_column("checklistitem", "dado_projeto")
    op.drop_column("checklistitem", "traducao_leigo")
    op.drop_column("checklistitem", "severidade")
```

- [ ] **Step 2: Commit**

```bash
git add server/alembic/versions/20260309_0014_checklist_unificado.py
git commit -m "feat(migration): add 3-layer fields to checklistitem table"
```

### Task 3: Update schemas

**Files:**
- Modify: `server/app/schemas.py:108-144`

- [ ] **Step 1: Update ChecklistItemCreate to accept 3-layer fields**

Add optional fields to `ChecklistItemCreate` (after `ordem`):

```python
class ChecklistItemCreate(SQLModel):
    titulo: str
    descricao: Optional[str] = None
    status: ChecklistStatus = ChecklistStatus.PENDENTE
    critico: Optional[bool] = False
    observacao: Optional[str] = None
    norma_referencia: Optional[str] = None
    origem: str = "padrao"
    grupo: str = "Geral"
    ordem: int = 0
    # 3 Camadas (optional, filled by AI)
    severidade: Optional[str] = None
    traducao_leigo: Optional[str] = None
    dado_projeto: Optional[str] = None
    verificacoes: Optional[str] = None
    pergunta_engenheiro: Optional[str] = None
    documentos_a_exigir: Optional[str] = None
    confianca: Optional[int] = None
    requer_validacao_profissional: bool = False
```

- [ ] **Step 2: Update ChecklistItemRead to include 3-layer fields**

Add fields to `ChecklistItemRead` (after `ordem`):

```python
class ChecklistItemRead(SQLModel):
    id: UUID
    etapa_id: UUID
    titulo: str
    descricao: Optional[str] = None
    status: ChecklistStatus
    critico: bool
    observacao: Optional[str] = None
    norma_referencia: Optional[str] = None
    origem: str
    grupo: str
    ordem: int
    # 3 Camadas
    severidade: Optional[str] = None
    traducao_leigo: Optional[str] = None
    dado_projeto: Optional[str] = None
    verificacoes: Optional[str] = None
    pergunta_engenheiro: Optional[str] = None
    documentos_a_exigir: Optional[str] = None
    registro_proprietario: Optional[str] = None
    resultado_cruzamento: Optional[str] = None
    status_verificacao: str = "pendente"
    confianca: Optional[int] = None
    requer_validacao_profissional: bool = False
    created_at: datetime
    updated_at: datetime
```

- [ ] **Step 3: Update ChecklistItemUpdate to allow setting 3-layer fields**

Add fields to `ChecklistItemUpdate`:

```python
class ChecklistItemUpdate(SQLModel):
    titulo: Optional[str] = None
    descricao: Optional[str] = None
    status: Optional[ChecklistStatus] = None
    critico: Optional[bool] = None
    observacao: Optional[str] = None
    norma_referencia: Optional[str] = None
    grupo: Optional[str] = None
    ordem: Optional[int] = None
    # 3 Camadas
    severidade: Optional[str] = None
    traducao_leigo: Optional[str] = None
    dado_projeto: Optional[str] = None
    verificacoes: Optional[str] = None
    pergunta_engenheiro: Optional[str] = None
    documentos_a_exigir: Optional[str] = None
    confianca: Optional[int] = None
    requer_validacao_profissional: Optional[bool] = None
```

- [ ] **Step 4: Update ItemParaAplicar schema to include 3-layer fields**

```python
class ItemParaAplicar(SQLModel):
    etapa_nome: str
    titulo: str
    descricao: str
    norma_referencia: Optional[str] = None
    critico: bool = False
    grupo: str = "Geral"
    ordem: int = 0
    # 3 Camadas
    severidade: Optional[str] = None
    traducao_leigo: Optional[str] = None
    dado_projeto: Optional[str] = None
    verificacoes: Optional[str] = None
    pergunta_engenheiro: Optional[str] = None
    documentos_a_exigir: Optional[str] = None
    confianca: Optional[int] = None
    requer_validacao_profissional: bool = False
```

- [ ] **Step 5: Update ChecklistGeracaoItemRead to include 3-layer fields**

Add to `ChecklistGeracaoItemRead`:

```python
class ChecklistGeracaoItemRead(SQLModel):
    id: UUID
    log_id: UUID
    etapa_nome: str
    titulo: str
    descricao: str
    norma_referencia: Optional[str] = None
    critico: bool
    risco_nivel: str
    requer_validacao_profissional: bool
    confianca: int
    como_verificar: str
    medidas_minimas: Optional[str] = None
    explicacao_leigo: str
    caracteristica_origem: str
    # 3 Camadas (new)
    dado_projeto: Optional[str] = None
    verificacoes: Optional[str] = None
    pergunta_engenheiro: Optional[str] = None
    documentos_a_exigir: Optional[str] = None
    created_at: datetime
```

- [ ] **Step 6: Commit**

```bash
git add server/app/schemas.py
git commit -m "feat(schemas): add 3-layer fields to checklist schemas"
```

---

## Chunk 2: Backend — Verification Endpoint + Apply Endpoint Update

### Task 4: Add checklist item verification endpoint

**Files:**
- Modify: `server/app/main.py`

- [ ] **Step 1: Add POST /api/checklist-items/{item_id}/verificar endpoint**

Add after the existing checklist item endpoints (around line 740). This is essentially the same logic as the risk verification endpoint:

```python
@app.post("/api/checklist-items/{item_id}/verificar", response_model=ChecklistItemRead)
def verificar_checklist_item(
    item_id: UUID,
    body: RegistrarVerificacaoRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> ChecklistItemRead:
    """Registra verificação do proprietário num item do checklist e cruza com dados do projeto."""
    item = session.get(ChecklistItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item nao encontrado")

    # Salva registro do proprietário
    registro = {
        "valor_medido": body.valor_medido,
        "status": body.status,
        "foto_ids": body.foto_ids or [],
        "data_verificacao": datetime.utcnow().isoformat(),
    }
    item.registro_proprietario = json.dumps(registro, ensure_ascii=False)
    item.status_verificacao = body.status

    # Cruzamento com dados do projeto
    dado_projeto = json.loads(item.dado_projeto) if item.dado_projeto else None
    if dado_projeto and body.valor_medido:
        valor_ref = dado_projeto.get("valor_referencia", "")
        especificacao = dado_projeto.get("especificacao", "")
        descricao_proj = dado_projeto.get("descricao", "")

        if body.status == "conforme":
            resultado = {
                "conclusao": "conforme",
                "resumo": f"A verificacao esta de acordo com o projeto ({especificacao}).",
                "acao": None,
                "urgencia": "baixa",
            }
        elif body.status == "divergente":
            resultado = {
                "conclusao": "divergente",
                "resumo": (
                    f"{descricao_proj}: medido {body.valor_medido}, "
                    f"projeto indica {valor_ref}."
                ),
                "acao": "Pergunte ao engenheiro usando a sugestao abaixo.",
                "urgencia": "alta",
            }
        else:
            resultado = {
                "conclusao": "duvida",
                "resumo": (
                    f"Duvida sobre {descricao_proj}. "
                    f"Valor de referencia: {valor_ref}."
                ),
                "acao": "Converse com o engenheiro para esclarecer.",
                "urgencia": "media",
            }
        item.resultado_cruzamento = json.dumps(resultado, ensure_ascii=False)

    item.updated_at = datetime.utcnow()
    session.add(item)
    session.commit()
    session.refresh(item)
    return ChecklistItemRead.model_validate(item)
```

- [ ] **Step 2: Commit**

```bash
git add server/app/main.py
git commit -m "feat(api): add POST /api/checklist-items/{item_id}/verificar endpoint"
```

### Task 5: Update aplicar_checklist_inteligente to pass 3-layer fields

**Files:**
- Modify: `server/app/main.py:1938-1950`

- [ ] **Step 1: Add 3-layer fields when creating items in aplicar endpoint**

Update the `novo_item = ChecklistItem(...)` block to include:

```python
        novo_item = ChecklistItem(
            etapa_id=etapa_id,
            titulo=item_data.titulo,
            descricao=item_data.descricao,
            critico=item_data.critico,
            norma_referencia=item_data.norma_referencia,
            origem="ia",
            status=ChecklistStatus.PENDENTE.value,
            grupo=grupo,
            ordem=getattr(item_data, "ordem", 0),
            # 3 Camadas
            severidade=getattr(item_data, "severidade", None),
            traducao_leigo=getattr(item_data, "traducao_leigo", None),
            dado_projeto=getattr(item_data, "dado_projeto", None),
            verificacoes=getattr(item_data, "verificacoes", None),
            pergunta_engenheiro=getattr(item_data, "pergunta_engenheiro", None),
            documentos_a_exigir=getattr(item_data, "documentos_a_exigir", None),
            confianca=getattr(item_data, "confianca", None),
            requer_validacao_profissional=getattr(item_data, "requer_validacao_profissional", False),
        )
```

- [ ] **Step 2: Commit**

```bash
git add server/app/main.py
git commit -m "feat(api): pass 3-layer fields when applying intelligent checklist items"
```

### Task 6: Add data migration endpoint (Risco → ChecklistItem)

**Files:**
- Modify: `server/app/main.py`

- [ ] **Step 1: Add one-time migration endpoint**

Add an admin endpoint to migrate existing Risco data into ChecklistItems:

```python
@app.post("/api/admin/migrar-riscos-para-checklist")
def migrar_riscos_para_checklist(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """One-time migration: converts Risco records into ChecklistItems."""
    if current_user.role != "admin" and current_user.role != "owner":
        raise HTTPException(status_code=403, detail="Sem permissao")

    riscos = session.exec(select(Risco)).all()
    migrados = 0

    for risco in riscos:
        # Find the obra via ProjetoDoc
        projeto = session.get(ProjetoDoc, risco.projeto_id)
        if not projeto:
            continue

        # Find first etapa of the obra (default: "Fundacoes e Estrutura")
        etapas = session.exec(
            select(Etapa).where(Etapa.obra_id == projeto.obra_id)
        ).all()
        etapa_alvo = None
        for e in etapas:
            if e.nome == "Fundacoes e Estrutura":
                etapa_alvo = e
                break
        if not etapa_alvo and etapas:
            etapa_alvo = etapas[0]
        if not etapa_alvo:
            continue

        novo = ChecklistItem(
            etapa_id=etapa_alvo.id,
            titulo=risco.descricao[:120] if risco.descricao else "Risco importado",
            descricao=risco.descricao,
            critico=risco.severidade == "alto",
            norma_referencia=risco.norma_referencia,
            origem="ia",
            severidade=risco.severidade,
            traducao_leigo=risco.traducao_leigo,
            dado_projeto=risco.dado_projeto,
            verificacoes=risco.verificacoes,
            pergunta_engenheiro=risco.pergunta_engenheiro,
            documentos_a_exigir=risco.documentos_a_exigir,
            registro_proprietario=risco.registro_proprietario,
            resultado_cruzamento=risco.resultado_cruzamento,
            status_verificacao=risco.status_verificacao,
            confianca=risco.confianca,
            requer_validacao_profissional=risco.requer_validacao_profissional,
        )
        session.add(novo)
        migrados += 1

    session.commit()
    return {"migrados": migrados, "total_riscos": len(riscos)}
```

- [ ] **Step 2: Commit**

```bash
git add server/app/main.py
git commit -m "feat(api): add admin endpoint to migrate riscos to checklist items"
```

---

## Chunk 3: Backend — AI Pipeline Update

### Task 7: Update ChecklistGeracaoItem model with 3-layer fields

**Files:**
- Modify: `server/app/models.py:280-297`

- [ ] **Step 1: Add 3-layer fields to ChecklistGeracaoItem**

```python
class ChecklistGeracaoItem(SQLModel, table=True):
    """Item sugerido pela IA durante geracao de checklist inteligente."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    log_id: UUID = Field(index=True, foreign_key="checklistgeracaolog.id")
    etapa_nome: str
    titulo: str
    descricao: str
    norma_referencia: Optional[str] = None
    critico: bool = Field(default=False)
    risco_nivel: str = Field(default="baixo")
    requer_validacao_profissional: bool = Field(default=False)
    confianca: int = Field(default=0)
    como_verificar: str = Field(default="")
    medidas_minimas: Optional[str] = None
    explicacao_leigo: str = Field(default="")
    caracteristica_origem: str = Field(default="")
    # 3 Camadas
    dado_projeto: Optional[str] = None
    verificacoes: Optional[str] = None
    pergunta_engenheiro: Optional[str] = None
    documentos_a_exigir: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
```

- [ ] **Step 2: Add migration for ChecklistGeracaoItem new columns**

In the same migration file `20260309_0014_checklist_unificado.py`, add:

```python
    op.add_column("checklistgeracaoitem", sa.Column("dado_projeto", sa.Text(), nullable=True))
    op.add_column("checklistgeracaoitem", sa.Column("verificacoes", sa.Text(), nullable=True))
    op.add_column("checklistgeracaoitem", sa.Column("pergunta_engenheiro", sa.Text(), nullable=True))
    op.add_column("checklistgeracaoitem", sa.Column("documentos_a_exigir", sa.Text(), nullable=True))
```

And in downgrade:

```python
    op.drop_column("checklistgeracaoitem", "documentos_a_exigir")
    op.drop_column("checklistgeracaoitem", "pergunta_engenheiro")
    op.drop_column("checklistgeracaoitem", "verificacoes")
    op.drop_column("checklistgeracaoitem", "dado_projeto")
```

- [ ] **Step 3: Commit**

```bash
git add server/app/models.py server/alembic/versions/20260309_0014_checklist_unificado.py
git commit -m "feat(model): add 3-layer fields to ChecklistGeracaoItem"
```

### Task 8: Update AI pipeline Phase 2 prompt to generate 3-layer data

**Files:**
- Modify: `server/app/checklist_inteligente.py:180-231`

- [ ] **Step 1: Update PHASE2_SYSTEM_PROMPT to include 3-layer output**

Replace PHASE2_SYSTEM_PROMPT with an updated version that asks the AI to also return `dado_projeto`, `verificacoes`, `pergunta_engenheiro`, and `documentos_a_exigir` for each item:

```python
PHASE2_SYSTEM_PROMPT = """\
Voce e um especialista em normas tecnicas brasileiras de construcao civil com \
foco em fiscalizacao de obras de alto padrao pelo proprietario.

Sua funcao e, dada uma CARACTERISTICA especifica de um projeto de construcao, \
gerar itens de checklist que o proprietario deve verificar durante a obra.

REGRAS OBRIGATORIAS:
1. Cada item deve ser uma ACAO CONCRETA que o proprietario pode verificar ou solicitar
2. Inclua a norma tecnica aplicavel (ABNT, NR, codigo de obras) quando houver
3. Escreva em linguagem SIMPLES e DIRETA para leigo
4. Indique COMO o proprietario deve verificar (o que olhar, o que perguntar, que documento pedir)
5. Classifique o risco: "alto" (seguranca/estrutural), "medio" (funcional), "baixo" (estetico/preventivo)
6. Itens de risco "alto" DEVEM ter requer_validacao_profissional: true
7. Distribua os itens nas etapas corretas da obra
8. Indique nivel de confianca (0-100) baseado na qualidade da fonte normativa
9. NUNCA apresente como parecer tecnico
10. Para cada item, inclua MEDIDAS MINIMAS exigidas pela norma e uma EXPLICACAO \
para leigo do que significa na pratica
11. Para cada item, gere os 3 blocos de orientacao ao proprietario:
    - dado_projeto: dados concretos que o proprietario deve encontrar no projeto
    - verificacoes: lista de verificacoes praticas que o proprietario pode fazer na obra
    - pergunta_engenheiro: pergunta colaborativa para o engenheiro caso algo pareça diferente
    - documentos_a_exigir: documentos que o proprietario deve solicitar

As 6 etapas da obra sao:
- Planejamento e Projeto
- Preparacao do Terreno
- Fundacoes e Estrutura
- Alvenaria e Cobertura
- Instalacoes e Acabamentos
- Entrega e Pos-obra

FORMATO DE RESPOSTA (JSON obrigatorio):
{
  "caracteristica": "id da caracteristica",
  "itens": [
    {
      "etapa_nome": "nome exato da etapa (uma das 6 acima)",
      "titulo": "titulo curto do item de checklist (max 80 chars)",
      "descricao": "descricao detalhada: o que verificar, como verificar, que documento pedir (max 300 chars)",
      "norma_referencia": "norma aplicavel (ex: NBR 5410:2004) ou null",
      "critico": true | false,
      "risco_nivel": "alto" | "medio" | "baixo",
      "requer_validacao_profissional": true | false,
      "confianca": numero 0-100,
      "como_verificar": "instrucao pratica em 1-2 frases de COMO o proprietario verifica este item",
      "medidas_minimas": "exigencias normativas concretas ou null",
      "explicacao_leigo": "explicacao simples do POR QUE e importante (max 200 chars)",
      "dado_projeto": {
        "descricao": "o que este item representa no projeto (max 150 chars)",
        "especificacao": "especificacao tecnica esperada (ex: espessura 19cm)",
        "fonte": "onde encontrar no projeto (ex: Planta Estrutural - Folha 3)",
        "valor_referencia": "valor numerico ou descritivo de referencia"
      },
      "verificacoes": [
        {
          "instrucao": "instrucao simples do que fazer (max 100 chars)",
          "tipo": "medicao | visual | documento",
          "valor_esperado": "o que esperar (ex: minimo 19cm)",
          "como_medir": "como realizar a verificacao na pratica (max 150 chars)"
        }
      ],
      "pergunta_engenheiro": {
        "contexto": "contexto para o engenheiro (max 150 chars)",
        "pergunta": "pergunta colaborativa e respeitosa (max 150 chars)",
        "tom": "colaborativo"
      },
      "documentos_a_exigir": ["nome do documento 1", "nome do documento 2"]
    }
  ]
}

Retorne SOMENTE o JSON, sem markdown, sem texto adicional."""
```

- [ ] **Step 2: Update background processing to save 3-layer fields**

In `processar_checklist_background`, update the item creation block (around line 683) to also save:

```python
                                    item = ChecklistGeracaoItem(
                                        log_id=log_id,
                                        etapa_nome=item_data.get("etapa_nome", ""),
                                        titulo=item_data.get("titulo", ""),
                                        descricao=item_data.get("descricao", ""),
                                        norma_referencia=item_data.get("norma_referencia"),
                                        critico=bool(item_data.get("critico", False)),
                                        risco_nivel=item_data.get("risco_nivel", "baixo"),
                                        requer_validacao_profissional=bool(
                                            item_data.get("requer_validacao_profissional", False)
                                        ),
                                        confianca=int(item_data.get("confianca", 0)),
                                        como_verificar=item_data.get("como_verificar", ""),
                                        medidas_minimas=item_data.get("medidas_minimas"),
                                        explicacao_leigo=item_data.get("explicacao_leigo", ""),
                                        caracteristica_origem=carac_id,
                                        # 3 Camadas
                                        dado_projeto=json.dumps(item_data["dado_projeto"], ensure_ascii=False) if item_data.get("dado_projeto") else None,
                                        verificacoes=json.dumps(item_data["verificacoes"], ensure_ascii=False) if item_data.get("verificacoes") else None,
                                        pergunta_engenheiro=json.dumps(item_data["pergunta_engenheiro"], ensure_ascii=False) if item_data.get("pergunta_engenheiro") else None,
                                        documentos_a_exigir=json.dumps(item_data["documentos_a_exigir"], ensure_ascii=False) if item_data.get("documentos_a_exigir") else None,
                                    )
```

- [ ] **Step 3: Commit**

```bash
git add server/app/checklist_inteligente.py
git commit -m "feat(ai): update checklist pipeline to generate 3-layer data per item"
```

---

## Chunk 4: Flutter — Model + API Client

### Task 9: Update Flutter ChecklistItem model

**Files:**
- Modify: `mobile/lib/models/checklist_item.dart`

- [ ] **Step 1: Add 3-layer fields and JSON parsing**

Rewrite with parsing logic adapted from the existing Risco model in `mobile/lib/models/documento.dart`:

```dart
import 'dart:convert';

class ChecklistItem {
  ChecklistItem({
    required this.id,
    required this.etapaId,
    required this.titulo,
    this.descricao,
    required this.status,
    required this.critico,
    this.observacao,
    this.normaReferencia,
    this.grupo = 'Geral',
    this.ordem = 0,
    this.criadoEm,
    // 3 Camadas
    this.severidade,
    this.traducaoLeigo,
    this.dadoProjeto,
    this.verificacoes,
    this.perguntaEngenheiro,
    this.documentosAExigir,
    this.registroProprietario,
    this.resultadoCruzamento,
    this.statusVerificacao = 'pendente',
    this.confianca,
    this.requerValidacaoProfissional = false,
  });

  final String id;
  final String etapaId;
  final String titulo;
  final String? descricao;
  final String status;
  final bool critico;
  final String? observacao;
  final String? normaReferencia;
  final String grupo;
  final int ordem;
  final DateTime? criadoEm;
  // 3 Camadas
  final String? severidade;
  final String? traducaoLeigo;
  final Map<String, dynamic>? dadoProjeto;
  final List<Map<String, dynamic>>? verificacoes;
  final Map<String, dynamic>? perguntaEngenheiro;
  final List<String>? documentosAExigir;
  final Map<String, dynamic>? registroProprietario;
  final Map<String, dynamic>? resultadoCruzamento;
  final String statusVerificacao;
  final int? confianca;
  final bool requerValidacaoProfissional;

  bool get isEnriquecido => dadoProjeto != null || verificacoes != null;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json["id"] as String,
      etapaId: json["etapa_id"] as String,
      titulo: json["titulo"] as String,
      descricao: json["descricao"] as String?,
      status: json["status"] as String? ?? "pendente",
      critico: json["critico"] as bool? ?? false,
      observacao: json["observacao"] as String?,
      normaReferencia: json["norma_referencia"] as String?,
      grupo: json["grupo"] as String? ?? "Geral",
      ordem: json["ordem"] as int? ?? 0,
      criadoEm: json["created_at"] != null
          ? DateTime.tryParse(json["created_at"] as String)
          : null,
      // 3 Camadas
      severidade: json["severidade"] as String?,
      traducaoLeigo: json["traducao_leigo"] as String?,
      dadoProjeto: _parseJsonObj(json["dado_projeto"]),
      verificacoes: _parseJsonList(json["verificacoes"]),
      perguntaEngenheiro: _parseJsonObj(json["pergunta_engenheiro"]),
      documentosAExigir: _parseStringList(json["documentos_a_exigir"]),
      registroProprietario: _parseJsonObj(json["registro_proprietario"]),
      resultadoCruzamento: _parseJsonObj(json["resultado_cruzamento"]),
      statusVerificacao: json["status_verificacao"] as String? ?? "pendente",
      confianca: json["confianca"] as int?,
      requerValidacaoProfissional:
          json["requer_validacao_profissional"] as bool? ?? false,
    );
  }

  static Map<String, dynamic>? _parseJsonObj(dynamic val) {
    if (val == null) return null;
    if (val is Map) return Map<String, dynamic>.from(val);
    if (val is String) {
      try {
        final decoded = jsonDecode(val);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  static List<Map<String, dynamic>>? _parseJsonList(dynamic val) {
    if (val == null) return null;
    if (val is List) {
      return val
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    if (val is String) {
      try {
        final decoded = jsonDecode(val);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
      } catch (_) {}
    }
    return null;
  }

  static List<String>? _parseStringList(dynamic val) {
    if (val == null) return null;
    if (val is List) return val.map((e) => e.toString()).toList();
    if (val is String) {
      try {
        final decoded = jsonDecode(val);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return null;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add mobile/lib/models/checklist_item.dart
git commit -m "feat(flutter): add 3-layer fields to ChecklistItem model"
```

### Task 10: Add verification API method

**Files:**
- Modify: `mobile/lib/services/api_client.dart`

- [ ] **Step 1: Add verificarChecklistItem method**

Add after the existing `atualizarItem` method:

```dart
  Future<ChecklistItem> verificarChecklistItem({
    required String itemId,
    String? valorMedido,
    required String status,
    List<String>? fotoIds,
  }) async {
    final response = await _post(
      "/api/checklist-items/$itemId/verificar",
      body: {
        "status": status,
        if (valorMedido != null && valorMedido.isNotEmpty)
          "valor_medido": valorMedido,
        if (fotoIds != null) "foto_ids": fotoIds,
      },
    );
    return ChecklistItem.fromJson(jsonDecode(response.body));
  }
```

- [ ] **Step 2: Commit**

```bash
git add mobile/lib/services/api_client.dart
git commit -m "feat(flutter): add verificarChecklistItem API method"
```

---

## Chunk 5: Flutter — UI Rebuild

### Task 11: Update checklist card to show severity + AI badges

**Files:**
- Modify: `mobile/lib/screens/checklist/checklist_screen.dart:456-567` (the `_ItemCard` widget)

- [ ] **Step 1: Add severity badge and AI icon to _ItemCard**

Update the `_ItemCard` widget's Column of badges (around line 488) to include severity and AI indicator:

```dart
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Severity badge
                  if (item.severidade != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _severidadeColor(item.severidade!).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.severidade!.toUpperCase(),
                        style: TextStyle(
                          color: _severidadeColor(item.severidade!),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  // Critical badge
                  if (item.critico) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "Crítico",
                        style: TextStyle(color: Colors.red, fontSize: 10),
                      ),
                    ),
                  ],
                  // AI enriched icon
                  if (item.isEnriquecido) ...[
                    const SizedBox(height: 4),
                    Icon(Icons.auto_awesome, size: 14, color: Colors.amber[700]),
                  ],
                ],
              ),
```

- [ ] **Step 2: Add _severidadeColor helper**

Add as a top-level function or inside the widget:

```dart
Color _severidadeColor(String severidade) {
  switch (severidade) {
    case "alto": return Colors.red;
    case "medio": return Colors.orange;
    case "baixo": return Colors.green;
    default: return Colors.grey;
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/screens/checklist/checklist_screen.dart
git commit -m "feat(flutter): add severity badge and AI icon to checklist cards"
```

### Task 12: Create inline verification widget

**Files:**
- Create: `mobile/lib/screens/checklist/verificacao_inline_widget.dart`

- [ ] **Step 1: Create the verification form widget**

```dart
import "package:flutter/material.dart";

import "../../models/checklist_item.dart";
import "../../services/api_client.dart";

class VerificacaoInlineWidget extends StatefulWidget {
  const VerificacaoInlineWidget({
    super.key,
    required this.item,
    required this.api,
    required this.onVerificado,
  });

  final ChecklistItem item;
  final ApiClient api;
  final ValueChanged<ChecklistItem> onVerificado;

  @override
  State<VerificacaoInlineWidget> createState() =>
      _VerificacaoInlineWidgetState();
}

class _VerificacaoInlineWidgetState extends State<VerificacaoInlineWidget> {
  final _valorController = TextEditingController();
  String _status = "conforme";
  bool _salvando = false;

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    setState(() => _salvando = true);
    try {
      final atualizado = await widget.api.verificarChecklistItem(
        itemId: widget.item.id,
        valorMedido: _valorController.text.trim(),
        status: _status,
      );
      widget.onVerificado(atualizado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verificação registrada.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dp = widget.item.dadoProjeto;
    final valorRef = dp?["valor_referencia"] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (valorRef != null) ...[
          Text("Referência do projeto: $valorRef",
              style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _valorController,
          decoration: const InputDecoration(
            labelText: "Valor medido",
            hintText: "Ex: 15cm, 2.5m, etc.",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        _VerificacaoOption(
          label: "Conforme",
          subtitle: "Está de acordo com o projeto",
          icon: Icons.check_circle_outline,
          color: Colors.green,
          selected: _status == "conforme",
          onTap: () => setState(() => _status = "conforme"),
        ),
        const SizedBox(height: 6),
        _VerificacaoOption(
          label: "Divergente",
          subtitle: "Algo está diferente do projeto",
          icon: Icons.error_outline,
          color: Colors.red,
          selected: _status == "divergente",
          onTap: () => setState(() => _status = "divergente"),
        ),
        const SizedBox(height: 6),
        _VerificacaoOption(
          label: "Dúvida",
          subtitle: "Não tenho certeza, preciso de ajuda",
          icon: Icons.help_outline,
          color: Colors.orange,
          selected: _status == "duvida",
          onTap: () => setState(() => _status = "duvida"),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _salvando ? null : _registrar,
            child: _salvando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text("Registrar Verificação"),
          ),
        ),
      ],
    );
  }
}

class _VerificacaoOption extends StatelessWidget {
  const _VerificacaoOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.w500,
                        color: selected ? color : null,
                      )),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add mobile/lib/screens/checklist/verificacao_inline_widget.dart
git commit -m "feat(flutter): create inline verification form widget"
```

### Task 13: Rebuild DetalheItemScreen with 3 expandable blocks

**Files:**
- Modify: `mobile/lib/screens/checklist/detalhe_item_screen.dart`

- [ ] **Step 1: Rewrite DetalheItemScreen**

Replace the entire file. Keep the existing functionality (header, status, evidence, observation) and add the 3 expandable blocks between description and status sections:

```dart
import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../../models/checklist_item.dart";
import "../../services/api_client.dart";
import "../normas/normas_screen.dart";
import "verificacao_inline_widget.dart";

class DetalheItemScreen extends StatefulWidget {
  const DetalheItemScreen({
    super.key,
    required this.item,
    required this.api,
    required this.etapaNome,
  });

  final ChecklistItem item;
  final ApiClient api;
  final String etapaNome;

  @override
  State<DetalheItemScreen> createState() => _DetalheItemScreenState();
}

class _DetalheItemScreenState extends State<DetalheItemScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  late ChecklistItem _item;
  late TextEditingController _obsController;
  bool _salvandoObs = false;
  bool _salvandoStatus = false;
  bool _mostrarFormVerificacao = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _obsController = TextEditingController(text: _item.observacao ?? "");
  }

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _atualizarStatus(String novoStatus) async {
    setState(() => _salvandoStatus = true);
    try {
      final atualizado = await widget.api.atualizarItem(
        itemId: _item.id,
        status: novoStatus,
      );
      if (mounted) setState(() => _item = atualizado);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    } finally {
      if (mounted) setState(() => _salvandoStatus = false);
    }
  }

  Future<void> _salvarObservacao() async {
    setState(() => _salvandoObs = true);
    try {
      final atualizado = await widget.api.atualizarItem(
        itemId: _item.id,
        observacao: _obsController.text.trim(),
      );
      if (mounted) {
        setState(() => _item = atualizado);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Observação salva.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    } finally {
      if (mounted) setState(() => _salvandoObs = false);
    }
  }

  Future<void> _adicionarEvidencia() async {
    final opcao = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Adicionar evidência"),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "camera"),
            child: const Row(children: [
              Icon(Icons.camera_alt), SizedBox(width: 12), Text("Tirar foto"),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "galeria"),
            child: const Row(children: [
              Icon(Icons.photo_library), SizedBox(width: 12), Text("Da galeria"),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "arquivo"),
            child: const Row(children: [
              Icon(Icons.attach_file), SizedBox(width: 12), Text("Arquivo"),
            ]),
          ),
        ],
      ),
    );
    if (opcao == null) return;
    try {
      if (opcao == "camera") {
        final img = await _imagePicker.pickImage(
            source: ImageSource.camera, imageQuality: 85);
        if (img == null) return;
        await widget.api.uploadEvidenciaImagem(itemId: _item.id, image: img);
      } else if (opcao == "galeria") {
        final img = await _imagePicker.pickImage(
            source: ImageSource.gallery, imageQuality: 85);
        if (img == null) return;
        await widget.api.uploadEvidenciaImagem(itemId: _item.id, image: img);
      } else {
        final result = await FilePicker.platform.pickFiles(withReadStream: true);
        if (result == null || result.files.isEmpty) return;
        await widget.api.uploadEvidencia(itemId: _item.id, file: result.files.first);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Evidência enviada.")));
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Detalhe do Item")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(_item.titulo,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              if (_item.critico)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text("Crítico",
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              if (_item.severidade != null) ...[
                const SizedBox(width: 6),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _severidadeColor(_item.severidade!)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _item.severidade!.toUpperCase(),
                    style: TextStyle(
                      color: _severidadeColor(_item.severidade!),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text("${_item.grupo} · ${widget.etapaNome}",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              if (_item.statusVerificacao != "pendente") ...[
                const SizedBox(width: 8),
                _VerificacaoBadge(status: _item.statusVerificacao),
              ],
            ],
          ),

          // ── Descrição ───────────────────────────────────────────────
          if (_item.descricao != null && _item.descricao!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text("Descrição", style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(_item.descricao!, style: const TextStyle(fontSize: 14)),
          ],

          // ── Tradução leigo ──────────────────────────────────────────
          if (_item.traducaoLeigo != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 18, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_item.traducaoLeigo!,
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],

          // ═══ BLOCO 1: O que o projeto diz ═══════════════════════════
          if (_item.dadoProjeto != null) ...[
            const SizedBox(height: 20),
            _BlocoExpansivel(
              titulo: "O que o projeto diz",
              icon: Icons.architecture,
              cor: Colors.teal,
              children: [
                if (_item.dadoProjeto!["descricao"] != null)
                  Text(_item.dadoProjeto!["descricao"],
                      style: const TextStyle(fontSize: 14)),
                if (_item.dadoProjeto!["especificacao"] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.straighten,
                            size: 16, color: Colors.teal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _item.dadoProjeto!["especificacao"],
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_item.dadoProjeto!["fonte"] != null) ...[
                  const SizedBox(height: 6),
                  Text("Fonte: ${_item.dadoProjeto!["fonte"]}",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ],
            ),
          ],

          // ═══ BLOCO 2: Verifique na obra ═════════════════════════════
          if (_item.verificacoes != null && _item.verificacoes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _BlocoExpansivel(
              titulo: "Verifique na obra",
              icon: Icons.checklist_rtl,
              cor: Colors.blue,
              initiallyExpanded: true,
              children: [
                for (final v in _item.verificacoes!) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _tipoVerificacaoIcon(v["tipo"] as String? ?? "visual"),
                        size: 18,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v["instrucao"] ?? "",
                                style: const TextStyle(fontSize: 14)),
                            if (v["valor_esperado"] != null)
                              Text("Esperado: ${v["valor_esperado"]}",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600])),
                            if (v["como_medir"] != null)
                              Text(v["como_medir"],
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                // Resultado do cruzamento (se já registrado)
                if (_item.resultadoCruzamento != null) ...[
                  const Divider(),
                  _ResultadoCruzamentoCard(
                      resultado: _item.resultadoCruzamento!),
                ],
                // Botão/form de verificação
                const SizedBox(height: 8),
                if (_mostrarFormVerificacao)
                  VerificacaoInlineWidget(
                    item: _item,
                    api: widget.api,
                    onVerificado: (atualizado) {
                      setState(() {
                        _item = atualizado;
                        _mostrarFormVerificacao = false;
                      });
                    },
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _mostrarFormVerificacao = true),
                    icon: Icon(
                      _item.registroProprietario != null
                          ? Icons.edit
                          : Icons.assignment_turned_in,
                      size: 18,
                    ),
                    label: Text(
                      _item.registroProprietario != null
                          ? "Atualizar Verificação"
                          : "Registrar Verificação",
                    ),
                  ),
              ],
            ),
          ],

          // ═══ BLOCO 3: Norma & Engenheiro ════════════════════════════
          if (_item.perguntaEngenheiro != null ||
              _item.normaReferencia != null ||
              (_item.documentosAExigir != null &&
                  _item.documentosAExigir!.isNotEmpty)) ...[
            const SizedBox(height: 12),
            _BlocoExpansivel(
              titulo: "Norma & Engenheiro",
              icon: Icons.engineering,
              cor: Colors.deepPurple,
              children: [
                // Norma
                if (_item.normaReferencia != null) ...[
                  Row(
                    children: [
                      Icon(Icons.menu_book_outlined,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_item.normaReferencia!,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NormasScreen(
                              api: widget.api,
                              etapaInicial: widget.etapaNome,
                            ),
                          ),
                        ),
                        child: const Text("Ver biblioteca"),
                      ),
                    ],
                  ),
                ],
                // Pergunta para engenheiro
                if (_item.perguntaEngenheiro != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_item.perguntaEngenheiro!["contexto"] != null)
                          Text(_item.perguntaEngenheiro!["contexto"],
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[700])),
                        if (_item.perguntaEngenheiro!["pergunta"] != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            "\"${_item.perguntaEngenheiro!["pergunta"]}\"",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                // Documentos a exigir
                if (_item.documentosAExigir != null &&
                    _item.documentosAExigir!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text("Documentos a exigir:",
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  for (final doc in _item.documentosAExigir!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined,
                              size: 14, color: Colors.deepPurple),
                          const SizedBox(width: 6),
                          Expanded(
                              child:
                                  Text(doc, style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ],

          // ── Mensagem se não enriquecido ─────────────────────────────
          if (!_item.isEnriquecido &&
              _item.normaReferencia == null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: Colors.amber[700]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Solicite análise por IA para preencher detalhes.",
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (!_item.isEnriquecido &&
              _item.normaReferencia != null) ...[
            // Item with norma but no 3-layer data — show norma section standalone
            const SizedBox(height: 16),
            Text("Norma de referência", style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.menu_book_outlined,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_item.normaReferencia!,
                      style: const TextStyle(fontSize: 13)),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NormasScreen(
                        api: widget.api,
                        etapaInicial: widget.etapaNome,
                      ),
                    ),
                  ),
                  child: const Text("Ver biblioteca"),
                ),
              ],
            ),
          ],

          // ── Status ──────────────────────────────────────────────────
          const SizedBox(height: 20),
          Text("Status", style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          _salvandoStatus
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    _StatusButton(
                      label: "Pendente",
                      icon: Icons.radio_button_unchecked,
                      color: Colors.grey,
                      selected: _item.status == "pendente",
                      onTap: () => _atualizarStatus("pendente"),
                    ),
                    const SizedBox(width: 8),
                    _StatusButton(
                      label: "OK",
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                      selected: _item.status == "ok",
                      onTap: () => _atualizarStatus("ok"),
                    ),
                    const SizedBox(width: 8),
                    _StatusButton(
                      label: "Não conforme",
                      icon: Icons.cancel_outlined,
                      color: Colors.red,
                      selected: _item.status == "nao_conforme",
                      onTap: () => _atualizarStatus("nao_conforme"),
                    ),
                  ],
                ),

          // ── Confiança IA ────────────────────────────────────────────
          if (_item.confianca != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text("Confiança da IA: ", style: theme.textTheme.titleSmall),
                Text("${_item.confianca}%",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: _item.confianca! / 100.0,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
            ),
          ],

          // ── Validação profissional ──────────────────────────────────
          if (_item.requerValidacaoProfissional) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      size: 20, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Este item requer validação de engenheiro ou arquiteto.",
                      style: TextStyle(fontSize: 13, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Evidências ──────────────────────────────────────────────
          const SizedBox(height: 24),
          Row(
            children: [
              Text("Evidências", style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: _adicionarEvidencia,
                icon: const Icon(Icons.add_a_photo, size: 18),
                label: const Text("Adicionar"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder(
            future: widget.api.listarEvidencias(_item.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final evidencias = snapshot.data ?? [];
              if (evidencias.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text("Nenhuma evidência ainda.",
                        style: TextStyle(color: Colors.grey)),
                  ),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: evidencias.length,
                itemBuilder: (context, i) {
                  final ev = evidencias[i];
                  final isImage =
                      ev.mimeType?.startsWith("image/") == true;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: isImage
                        ? Image.network(ev.arquivoUrl, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.attach_file,
                                color: Colors.grey),
                          ),
                  );
                },
              );
            },
          ),

          // ── Observação ──────────────────────────────────────────────
          const SizedBox(height: 24),
          Text("Observação", style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _obsController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: "Anotações sobre este item...",
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _salvandoObs ? null : _salvarObservacao,
              child: _salvandoObs
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text("Salvar observação"),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Helper functions ────────────────────────────────────────────────────────

Color _severidadeColor(String severidade) {
  switch (severidade) {
    case "alto":
      return Colors.red;
    case "medio":
      return Colors.orange;
    case "baixo":
      return Colors.green;
    default:
      return Colors.grey;
  }
}

IconData _tipoVerificacaoIcon(String tipo) {
  switch (tipo) {
    case "medicao":
      return Icons.straighten;
    case "visual":
      return Icons.visibility;
    case "documento":
      return Icons.description;
    default:
      return Icons.check;
  }
}

// ─── Widgets auxiliares ──────────────────────────────────────────────────────

class _BlocoExpansivel extends StatelessWidget {
  const _BlocoExpansivel({
    required this.titulo,
    required this.icon,
    required this.cor,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String titulo;
  final IconData icon;
  final Color cor;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cor.withValues(alpha: 0.3)),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon, color: cor),
        title: Text(titulo,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: cor, fontSize: 15)),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _VerificacaoBadge extends StatelessWidget {
  const _VerificacaoBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      "conforme" => ("Conforme", Colors.green, Icons.check_circle),
      "divergente" => ("Divergente", Colors.red, Icons.error),
      "duvida" => ("Dúvida", Colors.orange, Icons.help),
      _ => ("Pendente", Colors.grey, Icons.pending),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ResultadoCruzamentoCard extends StatelessWidget {
  const _ResultadoCruzamentoCard({required this.resultado});

  final Map<String, dynamic> resultado;

  @override
  Widget build(BuildContext context) {
    final conclusao = resultado["conclusao"] as String? ?? "duvida";
    final cor = switch (conclusao) {
      "conforme" => Colors.green,
      "divergente" => Colors.red,
      _ => Colors.orange,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                conclusao == "conforme"
                    ? Icons.check_circle
                    : conclusao == "divergente"
                        ? Icons.error
                        : Icons.help,
                size: 18,
                color: cor,
              ),
              const SizedBox(width: 6),
              Text("Resultado da verificação",
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: cor, fontSize: 13)),
            ],
          ),
          if (resultado["resumo"] != null) ...[
            const SizedBox(height: 6),
            Text(resultado["resumo"], style: const TextStyle(fontSize: 13)),
          ],
          if (resultado["acao"] != null) ...[
            const SizedBox(height: 4),
            Text(resultado["acao"],
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.grey.withValues(alpha: 0.3),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : Colors.grey, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? color : Colors.grey,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add mobile/lib/screens/checklist/detalhe_item_screen.dart
git commit -m "feat(flutter): rebuild detail screen with 3 expandable blocks"
```

---

## Chunk 6: Cleanup — Remove Risk Screens + Endpoints

### Task 14: Remove risk navigation from documentos_screen

**Files:**
- Modify: `mobile/lib/screens/documentos/documentos_screen.dart`

- [ ] **Step 1: Remove import and navigation to analise_documento_screen**

Remove the import of `analise_documento_screen.dart` and any navigation that opens it. The document upload screen should remain — only remove the risk analysis navigation.

- [ ] **Step 2: Commit**

```bash
git add mobile/lib/screens/documentos/documentos_screen.dart
git commit -m "refactor(flutter): remove risk analysis navigation from documentos screen"
```

### Task 15: Remove standalone risk screens

**Files:**
- Delete: `mobile/lib/screens/documentos/analise_documento_screen.dart`
- Delete: `mobile/lib/screens/documentos/detalhe_risco_screen.dart`
- Delete: `mobile/lib/screens/documentos/registrar_verificacao_screen.dart`

- [ ] **Step 1: Delete the 3 risk screen files**

```bash
rm mobile/lib/screens/documentos/analise_documento_screen.dart
rm mobile/lib/screens/documentos/detalhe_risco_screen.dart
rm mobile/lib/screens/documentos/registrar_verificacao_screen.dart
```

- [ ] **Step 2: Remove Risco class from documento.dart (keep AnaliseDocumento if used)**

Check if `AnaliseDocumento` or `ProjetoDoc` are still used. If only `Risco` is unused, remove just the `Risco` class.

- [ ] **Step 3: Remove risk API methods from api_client.dart**

Remove `obterAnaliseProjeto` and `registrarVerificacaoRisco` methods.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor(flutter): remove standalone risk screens and unused Risco model"
```

### Task 16: Remove risk endpoints from backend (keep model temporarily)

**Files:**
- Modify: `server/app/main.py`

- [ ] **Step 1: Remove GET /api/projetos/{projeto_id}/analise endpoint**

Comment out or remove the `obter_analise` function (lines 1293-1311).

- [ ] **Step 2: Remove POST /api/riscos/{risco_id}/verificar endpoint**

Comment out or remove the `registrar_verificacao` function (lines 1314-1376).

- [ ] **Step 3: Keep Risco model and table for now** (data migration safety)

The `Risco` model in `models.py` stays until the migration endpoint has been used in production. Can be removed in a future cleanup.

- [ ] **Step 4: Commit**

```bash
git add server/app/main.py
git commit -m "refactor(api): remove standalone risk endpoints (data now in checklist)"
```

### Task 17: Verify build

- [ ] **Step 1: Run Flutter analyze**

```bash
cd mobile && flutter analyze
```

Expected: No errors related to removed risk screens.

- [ ] **Step 2: Fix any import errors**

If there are remaining references to deleted files, remove those imports.

- [ ] **Step 3: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve import errors after risk screen removal"
```

---

## Chunk 7: Deploy

### Task 18: Apply migration and deploy

- [ ] **Step 1: Apply migration to Supabase**

```bash
cd server && DATABASE_URL="..." alembic upgrade head
```

- [ ] **Step 2: Run data migration**

Call `POST /api/admin/migrar-riscos-para-checklist` in production to convert existing risks.

- [ ] **Step 3: Deploy backend to Cloud Run**

```bash
bash server/deploy-cloudrun.sh
```

- [ ] **Step 4: Build Flutter APK**

```bash
cd mobile && flutter build apk --release --dart-define=API_BASE_URL=https://mestreobra-backend-530484413221.us-central1.run.app
```
