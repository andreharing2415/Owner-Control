# Architecture Patterns

**Domain:** AI-powered construction project management (obras residenciais de alto padrão)
**Researched:** 2026-04-06
**Focus:** Document-to-schedule pipeline, dual-role views, editable AI output

---

## The Core Problem: Generic vs. Document-Specific

The current `cronograma_ai.py` takes discipline names (`["Estrutural", "Eletrico"]`) as input and generates
a schedule from scratch using only the obra metadata (name, location, budget, dates). This makes it
**structurally impossible** to be document-specific — the LLM has nothing from the actual document to
anchor its output.

The document content IS available (stored in `ProjetoDoc.resumo_geral` and `Risco.dado_projeto`), but
it is not passed to the schedule generator. This is the gap to close.

---

## Recommended Architecture: Two-Stage Document-Driven Pipeline

### Stage 1 — Document Extraction (already partially exists, needs expansion)

The existing `analisar_documento()` extracts risks. A parallel extraction pass should produce
**construction activity signals** from the same document pages.

The critical insight from research: **vision-first is correct** for architectural PDFs. PyMuPDF
text extraction works well for digital PDFs but fails on scanned drawings (which constitute most
real architectural plans). The existing page-as-image approach in `extrair_paginas_como_imagens()`
is the right foundation.

### Stage 2 — Document-Grounded Schedule Generation (the missing piece)

Instead of prompting "generate a schedule for Estrutural + Eletrico work", prompt:
"Here is what the documents say. Generate activities that address EXACTLY these items."

---

## Data Model: Unified Cronograma+Checklist Source of Truth

### Current State

The codebase has a structural split:
- `Etapa` → `ChecklistItem` (legacy path, keyword-based assignment)
- `AtividadeCronograma` → `ChecklistItem.atividade_id` (new path, direct linkage)

Both paths exist simultaneously. `ChecklistItem` has both `etapa_id` and `atividade_id` fields,
meaning items can float between the two systems. This is the root cause of any "single source of
truth" problem.

### Recommended Data Model Changes

**DO NOT add a new table.** Extend `AtividadeCronograma` and `ChecklistItem` to be the single tree.

```python
# Add to AtividadeCronograma
class AtividadeCronograma(SQLModel, table=True):
    # ... existing fields ...

    # Provenance — track what the AI extracted
    fonte_doc_id: Optional[UUID] = Field(default=None, foreign_key="projetodoc.id")
    fonte_doc_trecho: Optional[str] = None    # quoted text/element from document that drove this activity
    fonte_pagina: Optional[int] = None        # page number in source document
    origem: str = Field(default="ia")         # "ia" | "usuario" | "template"
    is_modified: bool = Field(default=False)  # True if user changed AI-generated content
    confianca: Optional[int] = None           # 0-100, AI confidence in this activity

    # Construction sequence enforcement
    sequencia_ordem: int = Field(default=0)   # global ordering within the obra, immutable
    depends_on_fase: Optional[str] = None     # e.g. "Fundação" — enforces logical dep.
```

**The `Etapa` table should be deprecated** in favor of `AtividadeCronograma` (nivel=1). Migration:
map `Etapa.nome` → `AtividadeCronograma.nome` with `nivel=1`. All `ChecklistItem` records that
have only `etapa_id` should be migrated to also set `atividade_id` pointing to the corresponding
nivel-1 activity.

Until migration is complete, maintain both fields but always write to `atividade_id` in new code.

### ChecklistItem as the Verification Layer

`ChecklistItem` should be created automatically for each nivel-2 `AtividadeCronograma`, not manually:

```python
# Relationship: every micro-activity spawns a checklist item
class ChecklistItem(SQLModel, table=True):
    # ... existing fields ...
    atividade_id: Optional[UUID] = Field(...)  # primary link (already exists)
    # etapa_id kept for backward compat, but new code uses atividade_id only
    auto_gerado: bool = Field(default=True)    # True = created by pipeline, False = user-added
```

This creates the dual role naturally: the same `AtividadeCronograma` record is the **cronograma
entry** (schedule view) and its linked `ChecklistItem` is the **inspection gate** (checklist view).

---

## Prompt Architecture: Making the AI Use the Document

### The Root Cause of Generic Output

Current prompt in `cronograma_ai.py` passes only:
```
TIPOS DE PROJETO IDENTIFICADOS: Estrutural, Eletrico, Hidraulico
```

The LLM has no document content to be specific about. It falls back to its training data of
generic Brazilian construction templates.

### Fix: Document-Evidence Prompt Pattern

Replace the discipline-list input with **extracted evidence blocks**. This is a two-prompt design:

**Prompt A — Extraction Pass (new, runs after document analysis)**

```python
EXTRACTION_PROMPT = """\
Você é um Coordenador de Obras especialista em leitura de pranchas técnicas.

Analise a prancha [Página {page_num}] do projeto "{arquivo_nome}".

Extraia APENAS elementos construtivos concretos presentes NESTA PRANCHA.
Não infira. Não complete com conhecimento geral. Apenas o que está escrito ou desenhado.

Retorne JSON:
{{
  "elementos_construtivos": [
    {{
      "tipo": "fundação|estrutura|alvenaria|cobertura|instalação_elétrica|instalação_hidráulica|revestimento|esquadria|pintura|paisagismo|outro",
      "descricao_exata": "texto exato ou elemento identificado na prancha",
      "especificacao": "norma, dimensão, material citados (null se não houver)",
      "prancha_referencia": "{arquivo_nome} p.{page_num}"
    }}
  ],
  "disciplinas_identificadas": ["lista de disciplinas presentes nesta prancha"],
  "tem_planta_baixa": true,
  "tem_corte_ou_elevacao": false
}}
Se não há elementos construtivos identificáveis, retorne {{"elementos_construtivos": []}}
Retorne APENAS JSON válido.
"""
```

**Prompt B — Schedule Generation (replaces current GERAR_CRONOGRAMA_SYSTEM_PROMPT)**

```python
GERAR_CRONOGRAMA_COM_EVIDENCIAS_PROMPT = """\
Você é um Engenheiro de Planejamento de Obras especializado em construção civil brasileira.

REGRA ABSOLUTA: Gere APENAS atividades que sejam sustentadas pelos ELEMENTOS CONSTRUTIVOS
abaixo, extraídos dos documentos de projeto. Não adicione fases genéricas que não apareçam
nos documentos. Se um elemento específico aparece (ex: "piscina"), inclua sua fase.
Se não aparece (ex: "automação"), NÃO inclua.

ELEMENTOS EXTRAÍDOS DOS DOCUMENTOS:
{elementos_json}

SEQUÊNCIA CONSTRUTIVA OBRIGATÓRIA (respeite esta ordem global):
1. Serviços Preliminares / Sondagem / Projeto Executivo
2. Fundação (se identificada nos documentos)
3. Estrutura (se identificada nos documentos)
4. Alvenaria / Vedação
5. Cobertura (se identificada)
6. Impermeabilização
7. Instalações Elétricas (se identificadas)
8. Instalações Hidráulicas e Sanitárias (se identificadas)
9. Revestimentos (específicos do projeto: {lista_comodos_com_revestimento})
10. Esquadrias (se especificadas)
11. Pintura
12. Acabamentos e Elementos Especiais (piscina, lareira, etc. — apenas se no projeto)
13. Paisagismo (se no projeto)
14. Limpeza e Entrega

Para cada atividade de nível 2 (micro), inclua o campo "fonte_doc_trecho" com a
descrição exata do elemento do documento que gerou essa atividade.

INFORMAÇÕES DA OBRA:
- Nome: {nome}
- Orçamento: {orcamento}
- Período: {data_inicio} a {data_fim}

{formato_json_output}
"""
```

The key additions are:
1. `elementos_json` — the evidence from Prompt A, merged across all document pages
2. `fonte_doc_trecho` — forces the LLM to cite its source, dramatically reducing hallucination
3. Explicit "APENAS" (ONLY) language — strong negative constraint
4. `lista_comodos_com_revestimento` — populated from `ObraDetalhamento.comodos` (already extracted)

### Merging Evidence Across Pages

```python
def extrair_elementos_construtivos(
    pdf_bytes: bytes,
    arquivo_nome: str,
    max_pages: int = 15,
) -> list[dict]:
    """
    Pass 1: Extract construction elements from each page independently.
    Returns deduplicated list of elements across all pages.
    """
    pages = extrair_paginas_como_imagens(pdf_bytes, dpi=150, max_pages=max_pages)
    all_elements = []
    seen_descriptions: set[str] = set()

    for img_b64, page_num in pages:
        content_parts = [
            {"type": "image", "media_type": "image/jpeg", "data": img_b64},
            {"type": "text", "text": EXTRACTION_PROMPT.format(
                page_num=page_num, arquivo_nome=arquivo_nome
            )},
        ]
        try:
            result = call_vision_with_fallback(
                providers=get_document_vision_chain(),
                content_parts=content_parts,
                task_label=f"Extração elementos p.{page_num}",
            )
            for elem in result.get("elementos_construtivos", []):
                # Deduplicate by normalized description
                key = (elem.get("tipo", ""), elem.get("descricao_exata", "")[:50].lower())
                if key not in seen_descriptions:
                    seen_descriptions.add(key)
                    all_elements.append(elem)
        except Exception:
            continue  # page-level failure does not abort pipeline

    return all_elements
```

This function runs **in parallel** with the existing risk analysis pass — same pages, different prompt.
Do not run sequentially; both passes can share the same page images (already in memory as base64).

---

## Architecture for Document-to-Schedule Pipeline

```
ProjetoDoc (PDF uploaded)
    │
    ├── [Existing] analisar_documento()
    │       └── Produces: Risco[] (risk analysis)
    │
    └── [New] extrair_elementos_construtivos()  ← run concurrently
            └── Produces: ElementoConstrutivo[] (construction evidence)
                    │
                    └── [New] gerar_cronograma_com_evidencias()
                            └── Produces: AtividadeCronograma[] (L1 + L2)
                                    └── auto-spawns: ChecklistItem[] per L2
```

The pipeline trigger should be:
1. User uploads PDF → `ProjetoDoc` created (status: PENDENTE)
2. User clicks "Analisar" → BOTH passes run concurrently via `asyncio.gather()`
3. Risk pass → `Risco[]` stored (existing flow, unchanged)
4. Element pass → `ElementoConstrutivo[]` stored (new intermediate table OR JSON in `ProjetoDoc.elementos_extraidos`)
5. User clicks "Gerar Cronograma" → reads extracted elements, generates schedule

### Storing Extracted Elements

Option A (recommended): Add `elementos_extraidos: Optional[str]` (JSON) to `ProjetoDoc`.
Simple, no migration needed. The field stores the merged element list.

Option B: New `ElementoConstrutivo` table. More queryable but adds schema complexity for a
milestone-scoped deliverable.

**Use Option A.** The elements are intermediate data consumed once to generate the schedule.
They do not need to be independently queried.

---

## Editable AI-Generated Schedule: The Modification Pattern

### The Problem

When a user edits an AI-generated activity name or date, you need to:
1. Preserve the user's edit (don't overwrite on re-generate)
2. Track which activities were user-modified (for trust/audit)
3. Allow re-generation from scratch when user explicitly requests it

### Pattern: Provenance Flags + Selective Regeneration

```python
class AtividadeCronograma(SQLModel, table=True):
    # ... existing fields ...
    origem: str = Field(default="ia")         # "ia" | "usuario" | "template"
    is_modified: bool = Field(default=False)  # set True when user PATCH-es any field
    locked: bool = Field(default=False)       # user explicitly locks this activity
```

**On PATCH `/api/cronograma/{atividade_id}`:**
```python
# In atualizar_atividade()
updates = payload.model_dump(exclude_unset=True)
if updates:
    atividade.is_modified = True  # mark as user-modified
    for key, value in updates.items():
        setattr(atividade, key, value)
```

**On regeneration (`POST /api/obras/{obra_id}/cronograma/gerar`):**
```python
# Only delete activities that are NOT locked AND NOT user-modified
atividades_antigas = session.exec(
    select(AtividadeCronograma)
    .where(AtividadeCronograma.obra_id == obra_id)
    .where(AtividadeCronograma.locked == False)
    .where(AtividadeCronograma.is_modified == False)
).all()
# Delete only these; preserve locked/modified activities
```

This gives users a "pin" mechanism: any activity they edit is automatically preserved on
re-generation. Activities they haven't touched are freely replaced by a new AI pass.

### UI Contract (Flutter)

The API should return `is_modified` and `locked` in `AtividadeCronogramaRead`. The Flutter
client renders a visual indicator (e.g., a pencil icon) on modified activities and prevents
the "Re-generate" action from deleting them without explicit user confirmation.

---

## Dual-Role View Architecture: Engineer vs. Owner

### The Core Pattern: Projection, Not Duplication

Do NOT create two separate data models or two separate APIs. Instead, use **response projections**
controlled by the authenticated user's role and the access path.

**Roles already in the system:**
```python
User.role: str  # "owner" | "admin" | "convidado"
ObraConvite.papel: str  # "arquiteto" | "engenheiro" | "empreiteiro"
```

The `convidado` role with `papel="engenheiro"` is the engineer. The obra's `user_id` owner is the dono.

### Two-View Strategy

**Owner View (Dono da Obra)**
- Language: Portuguese leigo ("A fundação está 80% concluída")
- Data shown: `traducao_leigo`, simplified status, budget deviation in BRL
- Hidden: Technical specifications, norma references, `dado_projeto` raw data
- ChecklistItem fields shown: `titulo`, `traducao_leigo`, `status`, `observacao`
- ChecklistItem fields hidden: `norma_referencia`, `dado_projeto`, `verificacoes`, `pergunta_engenheiro`

**Engineer View (Engenheiro/Arquiteto)**
- Language: Technical Portuguese ("NBR 6118 — armadura mínima não atendida")
- Data shown: all fields including norma references, dado_projeto, confianca
- Additional: ability to mark items `conforme` or `divergente`
- Additional: ability to add `pergunta_engenheiro` responses

### Implementation: Projection via Response Schema, Not Role-Gated Endpoints

```python
# In schemas.py — add two projections of ChecklistItem

class ChecklistItemOwnerView(BaseModel):
    """Simplified view for property owner (dono da obra)."""
    id: UUID
    titulo: str
    traducao_leigo: Optional[str]
    status: str
    status_verificacao: str
    observacao: Optional[str]
    critico: bool
    # NOT included: norma_referencia, dado_projeto, verificacoes, pergunta_engenheiro

class ChecklistItemEngineerView(BaseModel):
    """Full technical view for engineering professionals."""
    id: UUID
    titulo: str
    descricao: Optional[str]
    norma_referencia: Optional[str]
    dado_projeto: Optional[str]    # JSON blob
    verificacoes: Optional[str]    # JSON blob
    pergunta_engenheiro: Optional[str]  # JSON blob
    status: str
    status_verificacao: str
    confianca: Optional[int]
    requer_validacao_profissional: bool
    # ... all fields
```

```python
# In the checklist endpoint — resolve view based on caller
@router.get("/api/cronograma/{atividade_id}/checklist")
def listar_checklist_atividade(
    atividade_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    atividade = session.get(AtividadeCronograma, atividade_id)
    obra = session.get(Obra, atividade.obra_id)

    # Determine view: dono gets owner view, professionals get engineer view
    is_dono = (obra.user_id == current_user.id)
    items = session.exec(
        select(ChecklistItem).where(ChecklistItem.atividade_id == atividade_id)
    ).all()

    if is_dono:
        return [ChecklistItemOwnerView.model_validate(i) for i in items]
    else:
        return [ChecklistItemEngineerView.model_validate(i) for i in items]
```

**Why this pattern, not separate endpoints:** The single source of truth principle holds. There
is one `ChecklistItem`, and the view is a runtime projection. Separate endpoints would require
synchronizing two parallel data structures, which historically leads to drift bugs.

### Engineer Write-Back Pattern

Engineers need to annotate items. Add a PATCH endpoint scoped to convidados:

```python
class ChecklistItemEngineerUpdate(BaseModel):
    """Fields an engineer is allowed to update."""
    status_verificacao: Optional[str] = None  # "conforme" | "divergente" | "duvida"
    observacao: Optional[str] = None
    # Engineers cannot change: titulo, norma_referencia, AI-generated dados

@router.patch("/api/checklist/{item_id}/engenheiro")
def engenheiro_atualizar_item(
    item_id: UUID,
    payload: ChecklistItemEngineerUpdate,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    # Verify caller is a convidado (not the dono)
    item = session.get(ChecklistItem, item_id)
    # ... verify access via ObraConvite ...
    # Apply only allowed fields
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(item, key, value)
    session.commit()
```

---

## Construction Sequence Enforcement

The sequence is not enforced at the database level in the current system. The AI is instructed
to respect it via the prompt, but nothing prevents out-of-order generation.

### Recommended: Soft Enforcement via `sequencia_ordem`

Add a canonical sequence map that the pipeline uses to sort and validate AI output:

```python
# In helpers.py or constants.py
SEQUENCIA_CONSTRUTIVA = [
    "Serviços Preliminares",
    "Sondagem",
    "Fundação",
    "Estrutura",
    "Alvenaria",
    "Cobertura",
    "Impermeabilização",
    "Instalações Elétricas",
    "Instalações Hidráulicas",
    "Instalações de Gás",
    "Revestimentos",
    "Esquadrias",
    "Pintura",
    "Acabamentos",
    "Paisagismo",
    "Limpeza e Entrega",
]

SEQUENCIA_INDEX = {name: i for i, name in enumerate(SEQUENCIA_CONSTRUTIVA)}

def normalizar_sequencia(atividades: list[dict]) -> list[dict]:
    """
    Sort AI-generated activities by canonical construction sequence.
    Activities not in the canonical map are placed at the end in original order.
    """
    def sort_key(a):
        nome = a.get("nome", "")
        # Match by prefix (e.g. "Instalações Elétricas Externas" → index of "Instalações Elétricas")
        for canonical, idx in SEQUENCIA_INDEX.items():
            if nome.lower().startswith(canonical.lower()):
                return (idx, a.get("ordem", 999))
        return (len(SEQUENCIA_CONSTRUTIVA), a.get("ordem", 999))

    return sorted(atividades, key=sort_key)
```

Apply `normalizar_sequencia()` in `gerar_cronograma_endpoint()` before persisting, and set
`AtividadeCronograma.sequencia_ordem` to the canonical index value. This allows the Flutter
client to always render in correct order regardless of what the AI returned.

---

## Background Processing Architecture

The current system runs document analysis synchronously within the HTTP request to avoid Cloud Run
termination (see comment in `documentos.py`). This is the correct approach for Cloud Run.

For the two-pass pipeline (risk extraction + element extraction), use `asyncio.gather()`:

```python
async def _run_full_analysis(projeto_id: UUID) -> None:
    """Runs both analysis passes concurrently."""
    from ..db import engine
    with Session(engine) as session:
        await asyncio.gather(
            asyncio.to_thread(analisar_documento_e_persistir, session, projeto_id),
            asyncio.to_thread(extrair_elementos_e_persistir, session, projeto_id),
        )
```

**Warning:** Both threads share the same `Session`. Use `session.flush()` + `session.refresh()`
carefully, or give each thread its own session. The safer pattern is two separate sessions:

```python
async def _run_full_analysis(projeto_id: UUID) -> None:
    from ..db import engine
    async def run_risk():
        with Session(engine) as s:
            analisar_documento_e_persistir(s, projeto_id)
    async def run_elements():
        with Session(engine) as s:
            extrair_elementos_e_persistir(s, projeto_id)
    await asyncio.gather(
        asyncio.to_thread(lambda: run_risk()),  # type: ignore
        asyncio.to_thread(lambda: run_elements()),
    )
```

Both passes read the same PDF from S3 (download separately within each thread to avoid
shared mutable bytes state).

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Discipline Names as Schedule Input
**What goes wrong:** Passing only `["Estrutural", "Eletrico"]` to the schedule generator.
**Why bad:** Forces the LLM to hallucinate activities from training data instead of the document.
**Instead:** Always pass extracted `elementos_construtivos` from the actual documents.

### Anti-Pattern 2: Shared SQLAlchemy Session Across Threads
**What goes wrong:** Two `asyncio.to_thread()` calls sharing one `Session` object.
**Why bad:** SQLAlchemy sessions are not thread-safe. Leads to race conditions on flush/commit.
**Instead:** Each thread gets its own `Session(engine)` instance.

### Anti-Pattern 3: Two Separate APIs for Owner vs Engineer
**What goes wrong:** `/api/owner/checklist` and `/api/engineer/checklist` as separate routes.
**Why bad:** Data diverges over time. Auth logic duplicated. Two response schemas to maintain.
**Instead:** Single endpoint, runtime projection based on `User.role` and `ObraConvite.papel`.

### Anti-Pattern 4: Deleting All Activities on Re-generate
**What goes wrong:** Current code deletes ALL `AtividadeCronograma` records on re-generate.
**Why bad:** Loses all user modifications (edited names, dates, manually added activities).
**Instead:** `is_modified=True` and `locked=True` activities are preserved on re-generation.

### Anti-Pattern 5: Etapa + AtividadeCronograma Coexistence Long-Term
**What goes wrong:** Keeping both `Etapa` and `AtividadeCronograma` as parallel structures forever.
**Why bad:** `ChecklistItem` can be attached to either, leading to ambiguous queries and
inconsistent UIs.
**Instead:** Plan a migration to `AtividadeCronograma`-only. Bridge during transition by auto-creating
a nivel-1 `AtividadeCronograma` for each `Etapa` when accessed via new APIs.

### Anti-Pattern 6: Sending All PDF Pages to One Prompt Call
**What goes wrong:** Current `analisar_documento()` sends all pages in one call (up to 15 images).
**Why bad:** For element extraction, specificity requires page-level context. A prompt covering
15 pages simultaneously cannot cite "Prancha 05 — Instalações Hidráulicas" accurately.
**Instead:** Page-per-call extraction (already used in `extrair_detalhamento_obra()`), with
results merged via deduplication like `_merge_comodos()`.

---

## Scalability Considerations

| Concern | Current Scale | At 1K obras | At 10K obras |
|---------|--------------|-------------|-------------|
| PDF analysis latency | ~30-90s per doc (Cloud Run 300s limit) | Same (per-request) | Queue-based worker pool |
| AI provider costs | Gemini free tier + fallback | Monitor token usage, add caching | Cache extracted elements; skip re-extraction if doc unchanged |
| Session concurrency | ThreadPoolExecutor(max_workers=4) | Adequate | Cloud Run concurrency scaling |
| S3 storage | Per-obra PDF storage | Fine | Lifecycle policy for old versions |
| Element deduplication | In-memory per-request | Fine | Fine |

The **most important optimization** at any scale: cache `ProjetoDoc.elementos_extraidos`. If the
field is populated, skip the extraction pass entirely when re-generating the schedule. Only
re-extract when the document changes (new upload) or user explicitly requests fresh extraction.

---

## Sources

- Codebase analysis: `server/app/cronograma_ai.py`, `server/app/documentos.py`, `server/app/models.py`, `server/app/services/documento_service.py`
- LLM PDF extraction approaches: https://unstract.com/blog/comparing-approaches-for-using-llms-for-structured-data-extraction-from-pdfs/
- Construction schedule AI research: https://www.sciencedirect.com/science/article/abs/pii/S1474034625007189
- Gemini vision accuracy on architectural plans: https://www.kreo.net/news-2d-takeoff/floor-plan-recognition-technologies
- Two-pass extraction pattern: https://towardsdatascience.com/extracting-structured-data-with-langextract-a-deep-dive-into-llm-orchestrated-workflows/
- WBS in construction: https://www.smartsheet.com/content/construction-work-breakdown-structure
- PyMuPDF4LLM hybrid OCR: https://pymupdf.readthedocs.io/en/latest/pymupdf4llm/
