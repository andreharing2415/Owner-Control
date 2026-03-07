# Checklist Async + Risk Details Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make checklist inteligente processing async (survives navigation), enrich risk detail screen with actionable owner instructions and norm links.

**Architecture:** Backend background thread processes checklist, saves results to DB incrementally. Frontend polls for status. Risk model gets new fields for owner-oriented guidance. AI prompts updated to generate richer output.

**Tech Stack:** FastAPI + SQLModel + Alembic (backend), React + TanStack Query + Tailwind + Shadcn (frontend), threading (Python stdlib)

---

## Task 1: Alembic Migration — New Table + New Columns

**Files:**
- Create: `server/alembic/versions/20260307_0009_async_checklist_risk_enrichment.py`

**Step 1: Create the migration file**

```python
"""async checklist processing + risk enrichment fields

Revision ID: 20260307_0009
Revises: 20260227_0008
Create Date: 2026-03-07 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "20260307_0009"
down_revision = "20260227_0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. New table: checklistgeracaoitem — stores suggested items per generation log
    op.create_table(
        "checklistgeracaoitem",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("log_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("etapa_nome", sa.String(), nullable=False),
        sa.Column("titulo", sa.String(), nullable=False),
        sa.Column("descricao", sa.Text(), nullable=False),
        sa.Column("norma_referencia", sa.String(), nullable=True),
        sa.Column("critico", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("risco_nivel", sa.String(), nullable=False, server_default="baixo"),
        sa.Column("requer_validacao_profissional", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("confianca", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("como_verificar", sa.Text(), nullable=False, server_default=""),
        sa.Column("medidas_minimas", sa.Text(), nullable=True),
        sa.Column("explicacao_leigo", sa.Text(), nullable=False, server_default=""),
        sa.Column("caracteristica_origem", sa.String(), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["log_id"], ["checklistgeracaolog.id"]),
    )
    op.create_index("ix_checklistgeracaoitem_id", "checklistgeracaoitem", ["id"])
    op.create_index("ix_checklistgeracaoitem_log_id", "checklistgeracaoitem", ["log_id"])

    # 2. New columns on checklistgeracaolog for progress tracking
    op.add_column("checklistgeracaolog", sa.Column("total_paginas", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("checklistgeracaolog", sa.Column("paginas_processadas", sa.Integer(), nullable=False, server_default="0"))

    # 3. New columns on risco for owner-oriented guidance
    op.add_column("risco", sa.Column("norma_url", sa.String(), nullable=True))
    op.add_column("risco", sa.Column("acao_proprietario", sa.Text(), nullable=True))
    op.add_column("risco", sa.Column("perguntas_para_profissional", sa.Text(), nullable=True))  # JSON string: list of {pergunta, resposta_esperada}
    op.add_column("risco", sa.Column("documentos_a_exigir", sa.Text(), nullable=True))  # JSON string: list of strings


def downgrade() -> None:
    op.drop_column("risco", "documentos_a_exigir")
    op.drop_column("risco", "perguntas_para_profissional")
    op.drop_column("risco", "acao_proprietario")
    op.drop_column("risco", "norma_url")
    op.drop_column("checklistgeracaolog", "paginas_processadas")
    op.drop_column("checklistgeracaolog", "total_paginas")
    op.drop_index("ix_checklistgeracaoitem_log_id", table_name="checklistgeracaoitem")
    op.drop_index("ix_checklistgeracaoitem_id", table_name="checklistgeracaoitem")
    op.drop_table("checklistgeracaoitem")
```

**Step 2: Run migration**

```bash
cd server && alembic upgrade head
```

Expected: Migration applies successfully, new table and columns created.

**Step 3: Commit**

```bash
git add server/alembic/versions/20260307_0009_async_checklist_risk_enrichment.py
git commit -m "feat: migration for async checklist + risk enrichment"
```

---

## Task 2: Backend Models — ChecklistGeracaoItem + Updated Risco + Updated ChecklistGeracaoLog

**Files:**
- Modify: `server/app/models.py:245-258` (ChecklistGeracaoLog — add progress fields)
- Modify: `server/app/models.py:155-166` (Risco — add guidance fields)
- Add new class after ChecklistGeracaoLog in `server/app/models.py`

**Step 1: Update ChecklistGeracaoLog model**

In `server/app/models.py`, add two fields to `ChecklistGeracaoLog` (after `total_itens_aplicados` line 253):

```python
    total_paginas: int = Field(default=0)
    paginas_processadas: int = Field(default=0)
```

**Step 2: Update Risco model**

In `server/app/models.py`, add four fields to `Risco` (after `confianca` line 164):

```python
    norma_url: Optional[str] = None
    acao_proprietario: Optional[str] = None
    perguntas_para_profissional: Optional[str] = None  # JSON string
    documentos_a_exigir: Optional[str] = None           # JSON string
```

**Step 3: Add ChecklistGeracaoItem model**

In `server/app/models.py`, after `ChecklistGeracaoLog` class, add:

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
    created_at: datetime = Field(default_factory=datetime.utcnow)
```

**Step 4: Commit**

```bash
git add server/app/models.py
git commit -m "feat: add ChecklistGeracaoItem model + Risco guidance fields"
```

---

## Task 3: Backend Schemas — New Read/Response Types

**Files:**
- Modify: `server/app/schemas.py:251-260` (RiscoRead — add new fields)
- Modify: `server/app/schemas.py:436-448` (ChecklistGeracaoLogRead — add progress)
- Add new schemas in `server/app/schemas.py` after ChecklistGeracaoLogRead

**Step 1: Update RiscoRead**

In `server/app/schemas.py`, add after `confianca: int` (line 259):

```python
    norma_url: Optional[str] = None
    acao_proprietario: Optional[str] = None
    perguntas_para_profissional: Optional[str] = None
    documentos_a_exigir: Optional[str] = None
```

**Step 2: Update ChecklistGeracaoLogRead**

In `server/app/schemas.py`, add after `erro_detalhe` (line 446):

```python
    total_paginas: int = 0
    paginas_processadas: int = 0
```

**Step 3: Add ChecklistGeracaoItemRead schema**

After `ChecklistGeracaoLogRead`, add:

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
    created_at: datetime


class ChecklistGeracaoStatusRead(SQLModel):
    log: ChecklistGeracaoLogRead
    itens: List[ChecklistGeracaoItemRead]
```

**Step 4: Commit**

```bash
git add server/app/schemas.py
git commit -m "feat: add schemas for async checklist + risk enrichment"
```

---

## Task 4: Backend — Background Checklist Processing Function

**Files:**
- Modify: `server/app/checklist_inteligente.py` — add `processar_checklist_background()` function

**Step 1: Add background processing function**

At the end of `server/app/checklist_inteligente.py`, add:

```python
def processar_checklist_background(
    log_id: "UUID",
    pdfs: list[tuple[bytes, str]],
    localizacao: Optional[str],
    database_url: str,
) -> None:
    """
    Runs the full checklist pipeline in a background thread.
    Creates its own DB session (threads cannot share SQLModel sessions).
    Saves results incrementally to ChecklistGeracaoItem.
    Updates ChecklistGeracaoLog with progress and final status.
    """
    from sqlmodel import Session, create_engine
    from .models import ChecklistGeracaoLog, ChecklistGeracaoItem

    engine = create_engine(database_url, echo=False)

    try:
        # Count total pages
        total_pages = 0
        pdf_page_counts: list[int] = []
        for pdf_bytes, nome in pdfs:
            count = contar_paginas(pdf_bytes)
            pdf_page_counts.append(count)
            total_pages += count

        with Session(engine) as session:
            log = session.get(ChecklistGeracaoLog, log_id)
            if log:
                log.total_paginas = total_pages
                log.total_docs_analisados = len(pdfs)
                session.add(log)
                session.commit()

        # Process pages
        caracteristicas_encontradas: dict[str, dict] = {}
        resumos_paginas: list[str] = []
        global_page = 0
        total_itens = 0

        for pdf_idx, (pdf_bytes, nome) in enumerate(pdfs):
            num_pages = pdf_page_counts[pdf_idx]

            for page_idx in range(num_pages):
                global_page += 1
                page_label = f"{nome} - Pagina {page_idx + 1}"

                try:
                    img_b64, page_num = extrair_pagina_individual(pdf_bytes, page_idx)
                    resultado = analisar_pagina(img_b64, page_label)
                    del img_b64

                    resumo = resultado.get("resumo_pagina", "")
                    if resumo:
                        resumos_paginas.append(f"[p{global_page}] {resumo}")

                    for carac in resultado.get("caracteristicas", []):
                        carac_id = carac.get("id", "")
                        if not carac_id or carac_id in caracteristicas_encontradas:
                            continue

                        caracteristicas_encontradas[carac_id] = carac

                        etapas_alvo = CARACTERISTICA_ETAPA_MAP.get(
                            carac_id, ["Instalacoes e Acabamentos"]
                        )

                        try:
                            itens_resultado = gerar_itens_para_caracteristica(
                                caracteristica_id=carac_id,
                                caracteristica_nome=carac.get("nome_legivel", carac_id),
                                descricao_no_projeto=carac.get("descricao_no_projeto", ""),
                                etapas_alvo=etapas_alvo,
                                localizacao=localizacao,
                            )
                            itens = itens_resultado.get("itens", [])

                            # Save items to DB incrementally
                            with Session(engine) as session:
                                for item_data in itens:
                                    item = ChecklistGeracaoItem(
                                        log_id=log_id,
                                        etapa_nome=item_data.get("etapa_nome", ""),
                                        titulo=item_data.get("titulo", ""),
                                        descricao=item_data.get("descricao", ""),
                                        norma_referencia=item_data.get("norma_referencia"),
                                        critico=bool(item_data.get("critico", False)),
                                        risco_nivel=item_data.get("risco_nivel", "baixo"),
                                        requer_validacao_profissional=bool(item_data.get("requer_validacao_profissional", False)),
                                        confianca=int(item_data.get("confianca", 0)),
                                        como_verificar=item_data.get("como_verificar", ""),
                                        medidas_minimas=item_data.get("medidas_minimas"),
                                        explicacao_leigo=item_data.get("explicacao_leigo", ""),
                                        caracteristica_origem=carac_id,
                                    )
                                    session.add(item)
                                    total_itens += 1
                                session.commit()

                        except Exception as exc:
                            logger.error("Erro ao gerar itens para %s: %s", carac_id, exc)

                except Exception as exc:
                    logger.error("Erro ao analisar %s: %s", page_label, exc)

                # Update progress
                with Session(engine) as session:
                    log = session.get(ChecklistGeracaoLog, log_id)
                    if log:
                        log.paginas_processadas = global_page
                        log.caracteristicas_identificadas = json.dumps(
                            list(caracteristicas_encontradas.keys())
                        )
                        log.total_itens_sugeridos = total_itens
                        log.updated_at = datetime.utcnow()
                        session.add(log)
                        session.commit()

        # Mark as completed
        resumo_projeto = "; ".join(resumos_paginas[:5]) if resumos_paginas else ""
        with Session(engine) as session:
            log = session.get(ChecklistGeracaoLog, log_id)
            if log:
                log.status = "concluido"
                log.resumo_geral = resumo_projeto
                log.aviso_legal = (
                    "Esta analise e informativa e NAO substitui parecer tecnico "
                    "de engenheiro ou arquiteto habilitado."
                )
                log.updated_at = datetime.utcnow()
                session.add(log)
                session.commit()

    except Exception as exc:
        logger.error("Erro fatal no background checklist: %s", exc)
        try:
            with Session(engine) as session:
                log = session.get(ChecklistGeracaoLog, log_id)
                if log:
                    log.status = "erro"
                    log.erro_detalhe = str(exc)
                    log.updated_at = datetime.utcnow()
                    session.add(log)
                    session.commit()
        except Exception:
            logger.error("Falha ao salvar erro no log %s", log_id)
```

Also add the missing import at the top of the file:

```python
from datetime import datetime
```

**Step 2: Commit**

```bash
git add server/app/checklist_inteligente.py
git commit -m "feat: add background checklist processing function"
```

---

## Task 5: Backend — New Endpoints (iniciar, status)

**Files:**
- Modify: `server/app/main.py` — add imports and two new endpoints

**Step 1: Update imports**

In `server/app/main.py`, line 24 — add `ChecklistGeracaoItem` to models import:

```python
from .models import User, Obra, Etapa, ChecklistItem, Evidencia, NormaLog, NormaResultado, OrcamentoEtapa, Despesa, AlertaConfig, ProjetoDoc, Risco, AnaliseVisual, Achado, DeviceToken, Prestador, Avaliacao, ChecklistGeracaoLog, ChecklistGeracaoItem
```

In schemas import block (lines 26-72), add:

```python
    ChecklistGeracaoItemRead,
    ChecklistGeracaoStatusRead,
```

In line 81, add the background function import:

```python
from .checklist_inteligente import gerar_checklist_stream, processar_checklist_background
```

Add threading import at the top of file:

```python
import threading
```

**Step 2: Add POST /iniciar endpoint**

After the existing `stream_checklist_inteligente` endpoint (after line 1433), add:

```python
@app.post(
    "/api/obras/{obra_id}/checklist-inteligente/iniciar",
    response_model=ChecklistGeracaoLogRead,
)
def iniciar_checklist_inteligente(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """
    Inicia o processamento do checklist inteligente em background.
    Retorna imediatamente o log_id para acompanhamento.
    """
    obra = _verify_obra_ownership(obra_id, current_user, session)

    # Check if there's already one processing
    existing = session.exec(
        select(ChecklistGeracaoLog)
        .where(ChecklistGeracaoLog.obra_id == obra_id)
        .where(ChecklistGeracaoLog.status == "processando")
    ).first()
    if existing:
        raise HTTPException(
            status_code=409,
            detail="Ja existe um processamento em andamento para esta obra.",
        )

    projetos = session.exec(
        select(ProjetoDoc).where(ProjetoDoc.obra_id == obra_id)
    ).all()
    if not projetos:
        raise HTTPException(
            status_code=400,
            detail="Nenhum documento de projeto enviado para esta obra. "
                   "Envie pelo menos um PDF antes de gerar o checklist inteligente.",
        )

    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise HTTPException(status_code=500, detail="S3_BUCKET nao configurado")

    # Download PDFs before launching thread
    pdfs: list[tuple[bytes, str]] = []
    for projeto in projetos:
        object_key = _extract_object_key(projeto.arquivo_url, bucket)
        pdf_bytes = download_by_url(projeto.arquivo_url, bucket, object_key)
        pdfs.append((pdf_bytes, projeto.arquivo_nome))

    # Create log entry
    log = ChecklistGeracaoLog(
        obra_id=obra_id,
        status="processando",
        total_docs_analisados=len(projetos),
    )
    session.add(log)
    session.commit()
    session.refresh(log)

    # Launch background thread
    from .db import get_database_url
    thread = threading.Thread(
        target=processar_checklist_background,
        args=(log.id, pdfs, obra.localizacao, get_database_url()),
        daemon=True,
    )
    thread.start()

    return log
```

**Step 3: Add GET /status endpoint**

```python
@app.get(
    "/api/obras/{obra_id}/checklist-inteligente/{log_id}/status",
    response_model=ChecklistGeracaoStatusRead,
)
def status_checklist_inteligente(
    obra_id: UUID,
    log_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """
    Retorna o status atual do processamento e os itens ja gerados.
    Frontend faz polling neste endpoint.
    """
    _verify_obra_ownership(obra_id, current_user, session)

    log = session.get(ChecklistGeracaoLog, log_id)
    if not log or log.obra_id != obra_id:
        raise HTTPException(status_code=404, detail="Log de geracao nao encontrado")

    itens = session.exec(
        select(ChecklistGeracaoItem)
        .where(ChecklistGeracaoItem.log_id == log_id)
        .order_by(ChecklistGeracaoItem.created_at)
    ).all()

    return ChecklistGeracaoStatusRead(
        log=ChecklistGeracaoLogRead.model_validate(log),
        itens=[ChecklistGeracaoItemRead.model_validate(i) for i in itens],
    )
```

**Step 4: Commit**

```bash
git add server/app/main.py
git commit -m "feat: add async checklist endpoints (iniciar + status)"
```

---

## Task 6: Backend — Enrich Document AI Prompt + Persist New Risco Fields

**Files:**
- Modify: `server/app/documentos.py:29-57` (SYSTEM_PROMPT — add new output fields)
- Modify: `server/app/main.py:993-1002` (analisar_projeto — persist new fields)

**Step 1: Update SYSTEM_PROMPT in documentos.py**

Replace the JSON format section in the SYSTEM_PROMPT (lines 43-57) with:

```python
SYSTEM_PROMPT = """Voce e um especialista em analise de projetos de construcao civil, com foco em conformidade normativa e gestao de riscos para proprietarios de obras de alto padrao.

Sua funcao e analisar as paginas de um documento de projeto e identificar riscos, inconsistencias e pontos de atencao em linguagem acessivel ao proprietario leigo.

CONTEXTO IMPORTANTE: O usuario e o PROPRIETARIO da obra. Ele NAO e engenheiro, arquiteto, nem tem formacao tecnica. Ele precisa saber EXATAMENTE o que fazer e o que cobrar dos profissionais contratados.

REGRAS OBRIGATORIAS:
1. Identifique riscos concretos e especificos do documento analisado
2. Para cada risco, indique a norma tecnica aplicavel quando houver (ABNT, NR, codigo de obras municipal)
3. Classifique a severidade: "alto" (impacto financeiro ou de seguranca elevado), "medio" (exige atencao), "baixo" (observacao)
4. Traduza o risco tecnico em linguagem clara e objetiva para o proprietario — SEM termos tecnicos
5. Indique nivel de confianca (0-100) baseado na clareza do documento analisado
6. Riscos de nivel "alto" DEVEM ter requer_validacao_profissional: true
7. NUNCA apresente como parecer tecnico ou opiniao juridica
8. Se o documento nao for um projeto de construcao civil, retorne uma lista de riscos vazia com resumo explicativo
9. Para cada risco, forneca instrucoes PRATICAS e CONCRETAS para o proprietario, incluindo:
   - O que pedir ao engenheiro/arquiteto (sem jargao tecnico)
   - Perguntas prontas para fazer ao profissional, COM a resposta que o proprietario deve esperar ouvir para saber que esta tudo certo
   - Documentos e laudos que deve exigir (ART, RRT, laudos, revisoes de projeto, etc.)

FORMATO DE RESPOSTA (JSON obrigatorio):
{
  "resumo_geral": "resumo em 2-3 frases do documento analisado e dos principais achados",
  "aviso_legal": "Esta analise e informativa e NAO substitui parecer tecnico de engenheiro ou arquiteto habilitado.",
  "riscos": [
    {
      "descricao": "descricao tecnica do risco ou ponto de atencao encontrado no documento",
      "severidade": "alto" | "medio" | "baixo",
      "norma_referencia": "norma aplicavel (ex: NBR 6118:2023, NR-18) ou null",
      "norma_url": "URL para consulta da norma (site da ABNT, planalto.gov.br, etc.) ou null se nao souber a URL exata",
      "traducao_leigo": "o que isso significa para voce como proprietario, em linguagem simples, sem termos tecnicos (max 300 chars)",
      "acao_proprietario": "instrucao direta do que pedir ao engenheiro/arquiteto, sem linguagem tecnica. Ex: 'Peca ao engenheiro que revise a protecao do ferro na fundacao para que dure mais tempo sem enferrujar' (max 300 chars)",
      "perguntas_para_profissional": [
        {
          "pergunta": "pergunta pronta que o proprietario deve fazer ao engenheiro",
          "resposta_esperada": "resumo da mensagem-chave que deve estar na resposta do engenheiro para indicar que esta ok. Nao precisa ser a frase exata, mas o conceito"
        }
      ],
      "documentos_a_exigir": ["documento ou laudo que o proprietario deve cobrar. Ex: 'Revisao do projeto estrutural com ART atualizada', 'Laudo de sondagem do solo', 'Solicite ART/RRT para esta atividade'"],
      "requer_validacao_profissional": true | false,
      "confianca": numero 0-100
    }
  ]
}

Retorne SOMENTE o JSON, sem markdown, sem texto adicional."""
```

**Step 2: Update analisar_projeto in main.py**

In `server/app/main.py`, update the risk persistence loop (around lines 993-1002). Replace:

```python
        for risco_data in resultado.get("riscos", []):
            risco = Risco(
                projeto_id=projeto_id,
                descricao=risco_data.get("descricao", ""),
                severidade=risco_data.get("severidade", "baixo"),
                norma_referencia=risco_data.get("norma_referencia"),
                traducao_leigo=risco_data.get("traducao_leigo", ""),
                requer_validacao_profissional=bool(risco_data.get("requer_validacao_profissional", False)),
                confianca=int(risco_data.get("confianca", 50)),
            )
            session.add(risco)
```

With:

```python
        for risco_data in resultado.get("riscos", []):
            perguntas = risco_data.get("perguntas_para_profissional")
            documentos = risco_data.get("documentos_a_exigir")
            risco = Risco(
                projeto_id=projeto_id,
                descricao=risco_data.get("descricao", ""),
                severidade=risco_data.get("severidade", "baixo"),
                norma_referencia=risco_data.get("norma_referencia"),
                norma_url=risco_data.get("norma_url"),
                traducao_leigo=risco_data.get("traducao_leigo", ""),
                acao_proprietario=risco_data.get("acao_proprietario", ""),
                perguntas_para_profissional=json.dumps(perguntas, ensure_ascii=False) if perguntas else None,
                documentos_a_exigir=json.dumps(documentos, ensure_ascii=False) if documentos else None,
                requer_validacao_profissional=bool(risco_data.get("requer_validacao_profissional", False)),
                confianca=int(risco_data.get("confianca", 50)),
            )
            session.add(risco)
```

Also add `import json` at the top of `main.py` if not already present (check first — it may already be there from other usage).

**Step 3: Commit**

```bash
git add server/app/documentos.py server/app/main.py
git commit -m "feat: enrich document AI prompt with owner-oriented guidance"
```

---

## Task 7: Frontend — Update Mock Data

**Files:**
- Modify: `client/src/lib/mock-data.ts`

**Step 1: Update ANALYSIS_MOCK findings with new fields**

Replace the `ANALYSIS_MOCK` object (lines 180-211) with:

```typescript
export const ANALYSIS_MOCK = {
  documentId: "d2",
  fileName: "Projeto Estrutural - Fundacao.pdf",
  overallRisk: "high",
  summary: "O projeto apresenta divergencias com a norma NBR 6122 em relacao ao recobrimento das armaduras em solo agressivo.",
  findings: [
    {
      id: 1,
      severity: "high",
      title: "Recobrimento Insuficiente",
      description: "O detalhe 04/02 especifica recobrimento de 3cm, mas a NBR 6122 exige 4cm para este tipo de solo.",
      page: 12,
      location: "Blocos B4 e B5",
      normaReferencia: "NBR 6122:2022",
      normaUrl: "https://www.abntcatalogo.com.br/pnm.aspx?Q=NBR6122",
      traducaoLeigo: "O \"recobrimento\" e a camada de concreto que protege o ferro da fundacao. Se for fino demais, a ferragem pode enferrujar com o tempo e comprometer a estrutura da casa.",
      acaoProprietario: "Peca ao seu engenheiro estrutural que revise o detalhe 04/02 do projeto e corrija a protecao do ferro para no minimo 4cm, como exige a norma para o tipo de solo do seu terreno.",
      perguntasParaProfissional: [
        {
          pergunta: "O recobrimento dos blocos B4 e B5 esta adequado para o tipo de solo do nosso terreno?",
          respostaEsperada: "Ele deve confirmar que o recobrimento atende a norma NBR 6122 para a classe de agressividade do solo do seu terreno. Se ele disser que 3cm e suficiente sem justificativa, insista."
        },
        {
          pergunta: "Voce pode emitir uma revisao do projeto corrigindo esse ponto?",
          respostaEsperada: "Sim, e a revisao deve vir acompanhada de uma nova ART (Anotacao de Responsabilidade Tecnica) registrada no CREA."
        }
      ],
      documentosAExigir: [
        "Revisao do projeto estrutural (detalhe 04/02) com ART atualizada",
        "Laudo de sondagem do solo (se nao houver um recente)"
      ],
      requerValidacaoProfissional: true,
      confianca: 92
    },
    {
      id: 2,
      severity: "medium",
      title: "Especificacao de Concreto",
      description: "Fck especificado (25MPa) esta no limite inferior para classe de agressividade II.",
      page: 3,
      location: "Notas Gerais",
      normaReferencia: "NBR 6118:2023",
      normaUrl: "https://www.abntcatalogo.com.br/pnm.aspx?Q=NBR6118",
      traducaoLeigo: "O concreto especificado no projeto tem a resistencia minima permitida para o tipo de ambiente do seu terreno. Funciona, mas nao tem margem de seguranca extra.",
      acaoProprietario: "Pergunte ao seu engenheiro se vale a pena usar um concreto um pouco mais forte (30MPa em vez de 25MPa) para ter mais seguranca, e qual seria o custo adicional.",
      perguntasParaProfissional: [
        {
          pergunta: "O concreto de 25MPa e realmente suficiente para o nosso caso, ou seria melhor usar 30MPa?",
          respostaEsperada: "Ele deve explicar o motivo da escolha e se a classe de agressividade do solo foi considerada. Se recomendar 30MPa, peca que atualize o projeto."
        }
      ],
      documentosAExigir: [
        "Solicite ao engenheiro que documente por escrito a justificativa para a escolha do concreto 25MPa"
      ],
      requerValidacaoProfissional: false,
      confianca: 78
    },
    {
      id: 3,
      severity: "low",
      title: "Ausencia de Cotas",
      description: "Faltam cotas de nivel na planta de locacao para os blocos da divisa.",
      page: 5,
      location: "Eixo 1-A",
      normaReferencia: null,
      normaUrl: null,
      traducaoLeigo: "Faltam algumas medidas de altura no desenho do projeto, o que pode causar confusao na hora de construir os blocos perto do muro.",
      acaoProprietario: "Peca ao engenheiro que complete o projeto com todas as medidas de altura (cotas de nivel) que estao faltando, principalmente nos blocos perto da divisa.",
      perguntasParaProfissional: [
        {
          pergunta: "As cotas de nivel dos blocos da divisa estao completas no projeto?",
          respostaEsperada: "Ele deve reconhecer que faltam e prometer incluir na proxima revisao do projeto."
        }
      ],
      documentosAExigir: [
        "Revisao da planta de locacao com todas as cotas de nivel"
      ],
      requerValidacaoProfissional: false,
      confianca: 85
    }
  ]
};
```

**Step 2: Add CHECKLIST_JOBS_MOCK**

After `ANALYSIS_MOCK`, add:

```typescript
export const CHECKLIST_JOBS_MOCK = [
  {
    id: "log-1",
    obraId: "1",
    status: "concluido",
    totalDocsAnalisados: 2,
    caracteristicasIdentificadas: '["piscina","ar_condicionado","automacao_residencial"]',
    totalItensSugeridos: 18,
    totalItensAplicados: 12,
    totalPaginas: 45,
    paginasProcessadas: 45,
    resumoGeral: "Projeto residencial de alto padrao com piscina, climatizacao central e automacao.",
    avisoLegal: "Esta analise e informativa e NAO substitui parecer tecnico de engenheiro ou arquiteto habilitado.",
    erroDetalhe: null,
    createdAt: "2026-03-05T14:30:00Z",
  },
  {
    id: "log-2",
    obraId: "1",
    status: "processando",
    totalDocsAnalisados: 1,
    caracteristicasIdentificadas: '["elevador"]',
    totalItensSugeridos: 4,
    totalItensAplicados: 0,
    totalPaginas: 30,
    paginasProcessadas: 12,
    resumoGeral: null,
    avisoLegal: null,
    erroDetalhe: null,
    createdAt: "2026-03-07T10:00:00Z",
  },
];
```

**Step 3: Commit**

```bash
git add client/src/lib/mock-data.ts
git commit -m "feat: update mock data with enriched risk fields + checklist jobs"
```

---

## Task 8: Frontend — Rewrite Checklists.tsx as Checklist Jobs Dashboard

**Files:**
- Modify: `client/src/pages/Checklists.tsx` (full rewrite)

**Step 1: Rewrite the Checklists page**

Replace the entire content of `client/src/pages/Checklists.tsx` with a jobs dashboard that shows:
- Header with "Checklist Inteligente" title and "Gerar Novo Checklist" button
- List of jobs (from CHECKLIST_JOBS_MOCK) showing:
  - Status badge: spinning icon + "Processando" (blue) / checkmark + "Concluido" (green) / X + "Erro" (red)
  - Date of creation
  - Progress bar (paginas processadas / total) for in-progress jobs
  - Characteristics found as small badges
  - Total items suggested / applied
  - "Ver Itens" button for completed jobs
- For a processing job, simulated progress bar
- Click on completed job expands to show a placeholder for suggested items

```tsx
import { CHECKLIST_JOBS_MOCK } from "@/lib/mock-data";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { ScrollArea } from "@/components/ui/scroll-area";
import {
  CheckCircle2,
  Loader2,
  XCircle,
  Sparkles,
  Play,
  ChevronDown,
  ChevronUp,
  FileCheck,
  Clock,
} from "lucide-react";
import { useState } from "react";

function StatusBadge({ status }: { status: string }) {
  if (status === "processando") {
    return (
      <Badge className="bg-blue-500/10 text-blue-400 border-blue-500/20 gap-1.5">
        <Loader2 className="h-3 w-3 animate-spin" />
        Processando
      </Badge>
    );
  }
  if (status === "concluido") {
    return (
      <Badge className="bg-emerald-500/10 text-emerald-400 border-emerald-500/20 gap-1.5">
        <CheckCircle2 className="h-3 w-3" />
        Concluido
      </Badge>
    );
  }
  return (
    <Badge className="bg-red-500/10 text-red-400 border-red-500/20 gap-1.5">
      <XCircle className="h-3 w-3" />
      Erro
    </Badge>
  );
}

function parseCaracteristicas(json: string | null): string[] {
  if (!json) return [];
  try {
    return JSON.parse(json);
  } catch {
    return [];
  }
}

function formatDate(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString("pt-BR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export default function Checklists() {
  const [expandedId, setExpandedId] = useState<string | null>(null);

  return (
    <div className="space-y-6 max-w-4xl mx-auto">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="text-3xl font-display font-bold tracking-tight">
            Checklist Inteligente
          </h2>
          <p className="text-sm text-muted-foreground mt-1">
            A IA analisa seus projetos e gera checklists personalizados para
            cada etapa da obra.
          </p>
        </div>
        <Button className="bg-primary hover:bg-primary/90 text-white gap-2">
          <Sparkles className="h-4 w-4" />
          Gerar Novo Checklist
        </Button>
      </div>

      {/* Info Card */}
      <Card className="border-primary/20 bg-gradient-to-r from-primary/5 to-transparent">
        <CardContent className="p-4 flex items-start gap-3">
          <FileCheck className="h-5 w-5 text-primary mt-0.5 shrink-0" />
          <p className="text-sm text-muted-foreground">
            O processamento continua mesmo que voce saia desta tela. Voce pode
            acompanhar o progresso e revisar os itens quando voltar.
          </p>
        </CardContent>
      </Card>

      {/* Jobs List */}
      <div className="space-y-4">
        {CHECKLIST_JOBS_MOCK.length === 0 ? (
          <Card className="border-dashed border-border/50">
            <CardContent className="p-12 text-center">
              <Sparkles className="h-10 w-10 text-muted-foreground/40 mx-auto mb-4" />
              <p className="text-muted-foreground">
                Nenhum checklist gerado ainda. Clique em "Gerar Novo Checklist"
                para comecar.
              </p>
            </CardContent>
          </Card>
        ) : (
          CHECKLIST_JOBS_MOCK.map((job) => {
            const caracs = parseCaracteristicas(
              job.caracteristicasIdentificadas
            );
            const isExpanded = expandedId === job.id;
            const progress =
              job.totalPaginas > 0
                ? Math.round(
                    (job.paginasProcessadas / job.totalPaginas) * 100
                  )
                : 0;

            return (
              <Card
                key={job.id}
                className="border-border/50 bg-card/40 hover:bg-card/60 transition-colors"
              >
                <CardContent className="p-5">
                  {/* Job Header */}
                  <div className="flex items-start justify-between gap-4">
                    <div className="flex-1 space-y-3">
                      <div className="flex items-center gap-3 flex-wrap">
                        <StatusBadge status={job.status} />
                        <span className="text-xs text-muted-foreground flex items-center gap-1">
                          <Clock className="h-3 w-3" />
                          {formatDate(job.createdAt)}
                        </span>
                        <span className="text-xs text-muted-foreground">
                          {job.totalDocsAnalisados} documento
                          {job.totalDocsAnalisados !== 1 ? "s" : ""} analisado
                          {job.totalDocsAnalisados !== 1 ? "s" : ""}
                        </span>
                      </div>

                      {/* Progress for processing jobs */}
                      {job.status === "processando" && (
                        <div className="space-y-1.5">
                          <div className="flex justify-between text-xs text-muted-foreground">
                            <span>
                              Pagina {job.paginasProcessadas} de{" "}
                              {job.totalPaginas}
                            </span>
                            <span>{progress}%</span>
                          </div>
                          <Progress value={progress} className="h-2" />
                        </div>
                      )}

                      {/* Summary for completed jobs */}
                      {job.status === "concluido" && job.resumoGeral && (
                        <p className="text-sm text-muted-foreground line-clamp-2">
                          {job.resumoGeral}
                        </p>
                      )}

                      {/* Error detail */}
                      {job.status === "erro" && job.erroDetalhe && (
                        <p className="text-sm text-red-400">
                          {job.erroDetalhe}
                        </p>
                      )}

                      {/* Characteristics badges */}
                      {caracs.length > 0 && (
                        <div className="flex flex-wrap gap-1.5">
                          {caracs.map((c) => (
                            <Badge
                              key={c}
                              variant="outline"
                              className="text-[10px] h-5 border-border/50 capitalize"
                            >
                              {c.replace(/_/g, " ")}
                            </Badge>
                          ))}
                        </div>
                      )}

                      {/* Stats */}
                      <div className="flex items-center gap-4 text-xs text-muted-foreground">
                        <span>
                          <strong className="text-foreground">
                            {job.totalItensSugeridos}
                          </strong>{" "}
                          itens sugeridos
                        </span>
                        {job.totalItensAplicados > 0 && (
                          <span>
                            <strong className="text-emerald-400">
                              {job.totalItensAplicados}
                            </strong>{" "}
                            aplicados
                          </span>
                        )}
                      </div>
                    </div>

                    {/* Expand button for completed */}
                    {job.status === "concluido" && (
                      <Button
                        variant="ghost"
                        size="sm"
                        className="shrink-0"
                        onClick={() =>
                          setExpandedId(isExpanded ? null : job.id)
                        }
                      >
                        {isExpanded ? (
                          <ChevronUp className="h-4 w-4" />
                        ) : (
                          <ChevronDown className="h-4 w-4" />
                        )}
                      </Button>
                    )}
                  </div>

                  {/* Expanded: show items placeholder */}
                  {isExpanded && (
                    <div className="mt-4 pt-4 border-t border-border/40">
                      <p className="text-sm text-muted-foreground mb-3">
                        Itens sugeridos pela IA para aplicar ao checklist da
                        obra:
                      </p>
                      <div className="rounded-lg bg-muted/10 border border-border/30 p-6 text-center">
                        <p className="text-sm text-muted-foreground">
                          Conecte ao backend para ver os itens gerados.
                        </p>
                        <Button
                          size="sm"
                          className="mt-3 gap-2"
                          variant="secondary"
                        >
                          <Play className="h-3 w-3" />
                          Aplicar Itens Selecionados
                        </Button>
                      </div>
                    </div>
                  )}
                </CardContent>
              </Card>
            );
          })
        )}
      </div>
    </div>
  );
}
```

**Step 2: Commit**

```bash
git add client/src/pages/Checklists.tsx
git commit -m "feat: rewrite Checklists as async jobs dashboard"
```

---

## Task 9: Frontend — Rewrite DocumentAnalysis.tsx with Rich Risk Details

**Files:**
- Modify: `client/src/pages/DocumentAnalysis.tsx` (enhance findings display)

**Step 1: Rewrite DocumentAnalysis.tsx**

Replace the entire content with an enhanced version that shows the enriched risk details:

```tsx
import { ANALYSIS_MOCK } from "@/lib/mock-data";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  AlertTriangle,
  ArrowLeft,
  FileText,
  Share2,
  Download,
  AlertOctagon,
  ExternalLink,
  MessageCircleQuestion,
  FileCheck2,
  HandHelping,
  ChevronDown,
  ChevronUp,
  HelpCircle,
} from "lucide-react";
import { Link } from "wouter";
import { ScrollArea } from "@/components/ui/scroll-area";
import { useState } from "react";

function NormaLink({
  normaReferencia,
  normaUrl,
}: {
  normaReferencia: string | null;
  normaUrl: string | null;
}) {
  if (!normaReferencia) return null;

  const url =
    normaUrl ||
    `https://www.google.com/search?q=ABNT+${encodeURIComponent(normaReferencia)}`;

  return (
    <a
      href={url}
      target="_blank"
      rel="noopener noreferrer"
      className="inline-flex items-center gap-1.5 text-xs text-primary hover:text-primary/80 transition-colors font-medium"
    >
      <ExternalLink className="h-3 w-3" />
      {normaReferencia}
    </a>
  );
}

export default function DocumentAnalysis() {
  const [expandedId, setExpandedId] = useState<number | null>(null);

  return (
    <div className="h-[calc(100vh-8rem)] flex flex-col space-y-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 shrink-0">
        <div className="flex items-center gap-4">
          <Button asChild variant="ghost" size="icon" className="rounded-full">
            <Link href="/documents">
              <ArrowLeft className="h-5 w-5" />
            </Link>
          </Button>
          <div>
            <h2 className="text-2xl font-display font-bold tracking-tight flex items-center gap-2">
              Analise IA: {ANALYSIS_MOCK.fileName}
            </h2>
            <div className="flex items-center gap-2 mt-1">
              <Badge
                variant="outline"
                className="border-red-500/30 text-red-500 bg-red-500/5"
              >
                Risco Geral: Alto
              </Badge>
              <span className="text-sm text-muted-foreground">
                Processado em 15/02/2026
              </span>
            </div>
          </div>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="sm" className="gap-2">
            <Share2 className="h-4 w-4" /> Compartilhar
          </Button>
          <Button variant="secondary" size="sm" className="gap-2">
            <Download className="h-4 w-4" /> Baixar Relatorio
          </Button>
        </div>
      </div>

      {/* Disclaimer */}
      <Card className="border-amber-500/20 bg-amber-500/5 shrink-0">
        <CardContent className="p-3 flex items-start gap-2">
          <AlertTriangle className="h-4 w-4 text-amber-500 mt-0.5 shrink-0" />
          <p className="text-xs text-amber-200/80">
            Esta analise e informativa e NAO substitui parecer tecnico de
            engenheiro ou arquiteto habilitado. Use as orientacoes abaixo para
            conversar com seus profissionais.
          </p>
        </CardContent>
      </Card>

      {/* Findings */}
      <ScrollArea className="flex-1">
        <div className="space-y-4 pb-6">
          {ANALYSIS_MOCK.findings.map((finding: any) => {
            const isExpanded = expandedId === finding.id;
            const perguntas = finding.perguntasParaProfissional || [];
            const documentos = finding.documentosAExigir || [];

            return (
              <Card
                key={finding.id}
                className="border-border/50 bg-card/40 overflow-hidden"
              >
                {/* Finding Header — always visible */}
                <div
                  className="p-5 cursor-pointer hover:bg-card/60 transition-colors"
                  onClick={() =>
                    setExpandedId(isExpanded ? null : finding.id)
                  }
                >
                  <div className="flex gap-4 items-start">
                    <div
                      className={
                        finding.severity === "high"
                          ? "text-red-500 bg-red-500/10 p-2 rounded-md"
                          : finding.severity === "medium"
                            ? "text-amber-500 bg-amber-500/10 p-2 rounded-md"
                            : "text-blue-500 bg-blue-500/10 p-2 rounded-md"
                      }
                    >
                      {finding.severity === "high" ? (
                        <AlertOctagon className="h-5 w-5" />
                      ) : finding.severity === "medium" ? (
                        <AlertTriangle className="h-5 w-5" />
                      ) : (
                        <FileText className="h-5 w-5" />
                      )}
                    </div>

                    <div className="flex-1 space-y-2">
                      <div className="flex justify-between items-start">
                        <h4 className="font-semibold text-sm">
                          {finding.title}
                        </h4>
                        <div className="flex items-center gap-2 shrink-0">
                          <NormaLink
                            normaReferencia={finding.normaReferencia}
                            normaUrl={finding.normaUrl}
                          />
                          <Badge variant="secondary" className="text-[10px] h-5">
                            Pg. {finding.page}
                          </Badge>
                          {isExpanded ? (
                            <ChevronUp className="h-4 w-4 text-muted-foreground" />
                          ) : (
                            <ChevronDown className="h-4 w-4 text-muted-foreground" />
                          )}
                        </div>
                      </div>

                      {/* traducao_leigo — always visible */}
                      <div className="flex items-start gap-2 rounded-lg bg-muted/20 p-3">
                        <HelpCircle className="h-4 w-4 text-primary shrink-0 mt-0.5" />
                        <div>
                          <span className="text-xs font-semibold text-primary block mb-0.5">
                            O que isso significa?
                          </span>
                          <p className="text-sm text-muted-foreground leading-relaxed">
                            {finding.traducaoLeigo}
                          </p>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Expanded Details */}
                {isExpanded && (
                  <div className="px-5 pb-5 space-y-4 border-t border-border/30 pt-4 ml-14">
                    {/* O que voce deve fazer */}
                    {finding.acaoProprietario && (
                      <div className="flex items-start gap-2 rounded-lg bg-emerald-500/5 border border-emerald-500/10 p-3">
                        <HandHelping className="h-4 w-4 text-emerald-400 shrink-0 mt-0.5" />
                        <div>
                          <span className="text-xs font-semibold text-emerald-400 block mb-0.5">
                            O que voce deve fazer
                          </span>
                          <p className="text-sm text-muted-foreground leading-relaxed">
                            {finding.acaoProprietario}
                          </p>
                        </div>
                      </div>
                    )}

                    {/* Perguntas para o profissional */}
                    {perguntas.length > 0 && (
                      <div className="rounded-lg bg-blue-500/5 border border-blue-500/10 p-3">
                        <div className="flex items-center gap-2 mb-3">
                          <MessageCircleQuestion className="h-4 w-4 text-blue-400" />
                          <span className="text-xs font-semibold text-blue-400">
                            Pergunte ao seu engenheiro
                          </span>
                        </div>
                        <div className="space-y-3">
                          {perguntas.map(
                            (
                              p: {
                                pergunta: string;
                                respostaEsperada: string;
                              },
                              idx: number
                            ) => (
                              <div key={idx} className="space-y-1">
                                <p className="text-sm text-foreground/90 font-medium">
                                  "{p.pergunta}"
                                </p>
                                <p className="text-xs text-muted-foreground/70 pl-3 border-l-2 border-blue-500/20">
                                  Resposta esperada: {p.respostaEsperada}
                                </p>
                              </div>
                            )
                          )}
                        </div>
                      </div>
                    )}

                    {/* Documentos a exigir */}
                    {documentos.length > 0 && (
                      <div className="rounded-lg bg-amber-500/5 border border-amber-500/10 p-3">
                        <div className="flex items-center gap-2 mb-2">
                          <FileCheck2 className="h-4 w-4 text-amber-400" />
                          <span className="text-xs font-semibold text-amber-400">
                            Documentos a exigir
                          </span>
                        </div>
                        <ul className="space-y-1.5">
                          {documentos.map((doc: string, idx: number) => (
                            <li
                              key={idx}
                              className="text-sm text-muted-foreground flex items-start gap-2"
                            >
                              <span className="text-amber-400/60 mt-1">•</span>
                              {doc}
                            </li>
                          ))}
                        </ul>
                      </div>
                    )}

                    {/* Validation warning */}
                    {finding.requerValidacaoProfissional && (
                      <div className="flex items-center gap-2 text-xs text-red-400 bg-red-500/5 rounded-md px-3 py-2">
                        <AlertOctagon className="h-3.5 w-3.5 shrink-0" />
                        Este item requer validacao de engenheiro ou arquiteto
                        antes de qualquer acao.
                      </div>
                    )}

                    {/* Location */}
                    <div className="text-xs text-muted-foreground/60">
                      <span className="font-medium text-foreground/60">
                        Local no projeto:
                      </span>{" "}
                      {finding.location} — Pagina {finding.page}
                    </div>
                  </div>
                )}
              </Card>
            );
          })}
        </div>
      </ScrollArea>
    </div>
  );
}
```

**Step 2: Commit**

```bash
git add client/src/pages/DocumentAnalysis.tsx
git commit -m "feat: rewrite DocumentAnalysis with rich owner-oriented risk details"
```

---

## Task 10: Smoke Test + Final Commit

**Step 1: Verify backend starts**

```bash
cd server && python -c "from app.models import ChecklistGeracaoItem, Risco, ChecklistGeracaoLog; print('Models OK')"
```

Expected: `Models OK`

**Step 2: Verify frontend builds**

```bash
cd .. && npx vite build 2>&1 | tail -5
```

Expected: Build succeeds without errors.

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: async checklist processing + enriched risk details for property owners"
```

---

## Summary of All Files Changed

### Backend (server/app/)
| File | Action | What |
|------|--------|------|
| `alembic/versions/20260307_0009_...py` | Create | Migration: new table + columns |
| `models.py` | Modify | ChecklistGeracaoItem model, Risco new fields, Log progress fields |
| `schemas.py` | Modify | New read schemas, updated RiscoRead + LogRead |
| `checklist_inteligente.py` | Modify | Add `processar_checklist_background()` |
| `main.py` | Modify | New endpoints (iniciar, status), updated risk persistence |
| `documentos.py` | Modify | Enriched AI prompt with owner guidance |

### Frontend (client/src/)
| File | Action | What |
|------|--------|------|
| `lib/mock-data.ts` | Modify | Enriched findings, new jobs mock |
| `pages/Checklists.tsx` | Rewrite | Async jobs dashboard |
| `pages/DocumentAnalysis.tsx` | Rewrite | Rich risk details with owner instructions |
