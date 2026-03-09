import json
import logging
import os
import re
import threading
import unicodedata
from datetime import datetime
from pathlib import Path
from typing import List
from uuid import UUID

logger = logging.getLogger(__name__)

from dotenv import load_dotenv

# Carrega .env do diretório raiz do servidor
load_dotenv(Path(__file__).resolve().parent.parent / ".env")

from fastapi import FastAPI, Depends, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from sqlmodel import Session, select

from .db import get_session, init_db
from .models import User, Obra, Etapa, ChecklistItem, Evidencia, NormaLog, NormaResultado, OrcamentoEtapa, Despesa, AlertaConfig, ProjetoDoc, Risco, AnaliseVisual, Achado, DeviceToken, Prestador, Avaliacao, ChecklistGeracaoLog, ChecklistGeracaoItem
from .enums import EtapaStatus, ChecklistStatus, CategoriaPrestador, SubcategoriaPrestadorServico, SubcategoriaMateriais
from .schemas import (
    ObraCreate,
    ObraRead,
    EtapaRead,
    EtapaStatusUpdate,
    ChecklistItemCreate,
    ChecklistItemRead,
    ChecklistItemUpdate,
    EvidenciaRead,
    NormaBuscarRequest,
    NormaBuscarResponse,
    NormaResultadoRead,
    NormaLogRead,
    OrcamentoEtapaCreate,
    OrcamentoEtapaRead,
    DespesaCreate,
    DespesaRead,
    AlertaConfigUpdate,
    AlertaConfigRead,
    EtapaFinanceiroItem,
    RelatorioFinanceiro,
    DeviceTokenCreate,
    DeviceTokenRead,
    ProjetoDocRead,
    RiscoRead,
    ProjetoAnaliseRead,
    AnaliseVisualRead,
    AchadoRead,
    AnaliseVisualComAchadosRead,
    PrestadorCreate,
    PrestadorRead,
    PrestadorUpdate,
    AvaliacaoCreate,
    AvaliacaoRead,
    PrestadorDetalheRead,
    CaracteristicaIdentificada,
    ChecklistInteligenteResponse,
    AplicarChecklistRequest,
    AplicarChecklistResponse,
    ItemParaAplicar,
    ChecklistGeracaoLogRead,
    ChecklistGeracaoItemRead,
    ChecklistGeracaoStatusRead,
    UserRegister,
    UserLogin,
    UserRead,
    TokenResponse,
    TokenRefreshRequest,
    EtapaPrazoUpdate,
    EtapaNormasChecklistRead,
    SugerirGrupoRequest,
    SugerirGrupoResponse,
)
from .auth import hash_password, verify_password, create_access_token, create_refresh_token, decode_token, get_current_user
from .storage import ensure_bucket, upload_file, download_file, download_by_url, extract_object_key
from .pdf import render_obra_pdf
from .seed_checklists import get_itens_padrao
from .normas import buscar_normas
from .documentos import analisar_documento
from .visual_ai import analisar_imagem
from .push import enviar_push_multiplos
from .checklist_inteligente import gerar_checklist_stream, processar_checklist_background


APP_NAME = "O Mestre da Obra API"

ETAPAS_PADRAO = [
    "Planejamento e Projeto",
    "Preparacao do Terreno",
    "Fundacoes e Estrutura",
    "Alvenaria e Cobertura",
    "Instalacoes e Acabamentos",
    "Entrega e Pos-obra",
]


def _sanitize_filename(name: str) -> str:
    """Remove accents, replace spaces and unsafe chars for S3-compatible keys."""
    name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode("ascii")
    name = name.replace(" ", "_")
    name = re.sub(r"[^\w.\-]", "", name)
    return name or "file"



app = FastAPI(title=APP_NAME)

# CORS: com allow_credentials=True o browser não aceita "*"; é preciso origem explícita ou regex.
# Permitir Flutter web em dev (localhost com qualquer porta).
app.add_middleware(
    CORSMiddleware,
    allow_origins=[],
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?$|https://mestreobra-[a-z0-9.-]*\.run\.app$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup() -> None:
    try:
        init_db()
    except Exception as exc:
        print(f"[startup] DB init deferred (will retry on first request): {exc}")
    bucket = os.getenv("S3_BUCKET")
    if bucket:
        try:
            ensure_bucket(bucket)
        except Exception as exc:
            print(f"[startup] S3 bucket setup skipped: {exc}")


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


# ─── Fase 7 — Autenticação ──────────────────────────────────────────────────

@app.post("/api/auth/register", response_model=TokenResponse)
def registrar_usuario(payload: UserRegister, session: Session = Depends(get_session)):
    existing = session.exec(select(User).where(User.email == payload.email.lower().strip())).first()
    if existing:
        raise HTTPException(status_code=409, detail="Email ja cadastrado")
    user = User(
        email=payload.email.lower().strip(),
        password_hash=hash_password(payload.password),
        nome=payload.nome,
        telefone=payload.telefone,
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        user=UserRead.model_validate(user),
    )


@app.post("/api/auth/login", response_model=TokenResponse)
def login(payload: UserLogin, session: Session = Depends(get_session)):
    user = session.exec(select(User).where(User.email == payload.email.lower().strip())).first()
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Email ou senha incorretos")
    if not user.ativo:
        raise HTTPException(status_code=403, detail="Conta desativada")
    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        user=UserRead.model_validate(user),
    )


@app.post("/api/auth/refresh", response_model=TokenResponse)
def refresh_token(payload: TokenRefreshRequest, session: Session = Depends(get_session)):
    data = decode_token(payload.refresh_token)
    if data.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Token de refresh invalido")
    user = session.get(User, UUID(data["sub"]))
    if not user or not user.ativo:
        raise HTTPException(status_code=401, detail="Usuario nao encontrado")
    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        user=UserRead.model_validate(user),
    )


@app.get("/api/auth/me", response_model=UserRead)
def me(current_user: User = Depends(get_current_user)):
    return UserRead.model_validate(current_user)


# ─── Helpers de ownership ────────────────────────────────────────────────────

def _verify_obra_ownership(obra_id: UUID, user: User, session: Session) -> Obra:
    """Verifica que a obra existe e pertence ao usuário. Retorna a Obra."""
    obra = session.get(Obra, obra_id)
    if not obra or (obra.user_id is not None and obra.user_id != user.id):
        raise HTTPException(status_code=404, detail="Obra nao encontrada")
    return obra


def _verify_etapa_ownership(etapa_id: UUID, user: User, session: Session) -> Etapa:
    """Verifica que a etapa existe e sua obra pertence ao usuário."""
    etapa = session.get(Etapa, etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")
    _verify_obra_ownership(etapa.obra_id, user, session)
    return etapa


# ─── Obras ───────────────────────────────────────────────────────────────────

@app.post("/api/obras", response_model=ObraRead)
def criar_obra(payload: ObraCreate, session: Session = Depends(get_session), current_user: User = Depends(get_current_user)) -> Obra:
    obra = Obra(user_id=current_user.id, **payload.model_dump())
    session.add(obra)
    session.commit()
    session.refresh(obra)

    etapas = [
        Etapa(obra_id=obra.id, nome=nome, ordem=index + 1, status=EtapaStatus.PENDENTE.value)
        for index, nome in enumerate(ETAPAS_PADRAO)
    ]
    session.add_all(etapas)
    session.commit()
    for etapa in etapas:
        session.refresh(etapa)

    itens_seed: list[ChecklistItem] = []
    for etapa in etapas:
        for item_data in get_itens_padrao(etapa.nome):
            itens_seed.append(
                ChecklistItem(
                    etapa_id=etapa.id,
                    titulo=item_data["titulo"],
                    descricao=item_data.get("descricao"),
                    critico=item_data.get("critico", False),
                    status=ChecklistStatus.PENDENTE.value,
                )
            )
    if itens_seed:
        session.add_all(itens_seed)
        session.commit()

    return obra


@app.get("/api/obras", response_model=List[ObraRead])
def listar_obras(session: Session = Depends(get_session), current_user: User = Depends(get_current_user)) -> list[Obra]:
    return session.exec(select(Obra).where(Obra.user_id == current_user.id)).all()


@app.get("/api/obras/{obra_id}")
def obter_obra(obra_id: UUID, session: Session = Depends(get_session), current_user: User = Depends(get_current_user)) -> dict:
    obra = _verify_obra_ownership(obra_id, current_user, session)
    etapas = session.exec(select(Etapa).where(Etapa.obra_id == obra_id).order_by(Etapa.ordem)).all()
    return {"obra": obra, "etapas": etapas}


@app.get("/api/obras/{obra_id}/export-pdf")
def exportar_pdf(obra_id: UUID, session: Session = Depends(get_session), current_user: User = Depends(get_current_user)) -> StreamingResponse:
    obra = _verify_obra_ownership(obra_id, current_user, session)
    etapas = session.exec(select(Etapa).where(Etapa.obra_id == obra_id).order_by(Etapa.ordem)).all()
    itens = session.exec(select(ChecklistItem)).all()
    itens_map: dict[str, list[ChecklistItem]] = {}
    for item in itens:
        itens_map.setdefault(str(item.etapa_id), []).append(item)
    pdf_bytes = render_obra_pdf(obra, etapas, itens_map)
    return StreamingResponse(
        content=iter([pdf_bytes]),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="obra-{obra_id}.pdf"'},
    )


@app.get("/api/etapas/{etapa_id}/checklist-items", response_model=List[ChecklistItemRead])
def listar_itens(etapa_id: UUID, session: Session = Depends(get_session), current_user: User = Depends(get_current_user)) -> list[ChecklistItem]:
    _verify_etapa_ownership(etapa_id, current_user, session)
    return session.exec(select(ChecklistItem).where(ChecklistItem.etapa_id == etapa_id)).all()


@app.post("/api/etapas/{etapa_id}/checklist-items", response_model=ChecklistItemRead)
def criar_item(
    etapa_id: UUID,
    payload: ChecklistItemCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> ChecklistItem:
    etapa = _verify_etapa_ownership(etapa_id, current_user, session)
    item = ChecklistItem(etapa_id=etapa_id, **payload.model_dump(mode="json"))
    session.add(item)
    session.commit()
    session.refresh(item)
    return item


@app.patch("/api/checklist-items/{item_id}", response_model=ChecklistItemRead)
def atualizar_item(
    item_id: UUID,
    payload: ChecklistItemUpdate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> ChecklistItem:
    item = session.get(ChecklistItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item nao encontrado")
    _verify_etapa_ownership(item.etapa_id, current_user, session)
    updates = payload.model_dump(exclude_unset=True, mode="json")
    for key, value in updates.items():
        setattr(item, key, value)
    item.updated_at = datetime.utcnow()
    session.add(item)
    session.commit()
    session.refresh(item)
    return item


@app.delete("/api/checklist-items/{item_id}", status_code=204)
def deletar_item(
    item_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    item = session.get(ChecklistItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item nao encontrado")
    _verify_etapa_ownership(item.etapa_id, current_user, session)
    session.delete(item)
    session.commit()


@app.get("/api/etapas/{etapa_id}/score")
def score_etapa(etapa_id: UUID, session: Session = Depends(get_session), current_user: User = Depends(get_current_user)) -> dict:
    itens = session.exec(select(ChecklistItem).where(ChecklistItem.etapa_id == etapa_id)).all()
    total = len(itens)
    if total == 0:
        score = 0.0
    else:
        ok_count = len([item for item in itens if item.status == ChecklistStatus.OK.value])
        score = (ok_count / total) * 100
    etapa = session.get(Etapa, etapa_id)
    if etapa:
        etapa.score = score
        etapa.updated_at = datetime.utcnow()
        session.add(etapa)
        session.commit()
    return {"etapa_id": etapa_id, "score": score}


@app.patch("/api/etapas/{etapa_id}/status", response_model=EtapaRead)
def atualizar_status_etapa(
    etapa_id: UUID,
    payload: EtapaStatusUpdate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> Etapa:
    etapa = _verify_etapa_ownership(etapa_id, current_user, session)
    etapa.status = payload.status.value
    etapa.updated_at = datetime.utcnow()
    session.add(etapa)
    session.commit()
    session.refresh(etapa)
    return etapa


@app.patch("/api/etapas/{etapa_id}/prazo", response_model=EtapaRead)
def atualizar_prazo_etapa(
    etapa_id: UUID,
    payload: EtapaPrazoUpdate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> EtapaRead:
    etapa = session.get(Etapa, etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")
    obra = session.get(Obra, etapa.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acesso negado")
    if payload.prazo_previsto is not None:
        etapa.prazo_previsto = payload.prazo_previsto
    if payload.prazo_executado is not None:
        etapa.prazo_executado = payload.prazo_executado
    etapa.updated_at = datetime.utcnow()
    session.add(etapa)
    session.commit()
    session.refresh(etapa)
    return EtapaRead.model_validate(etapa)


@app.get("/api/etapas/{etapa_id}/checklist-normas", response_model=EtapaNormasChecklistRead)
def listar_normas_checklist_etapa(
    etapa_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> EtapaNormasChecklistRead:
    etapa = session.get(Etapa, etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")
    obra = session.get(Obra, etapa.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acesso negado")
    itens = session.exec(
        select(ChecklistItem).where(
            ChecklistItem.etapa_id == etapa_id,
            ChecklistItem.norma_referencia != None,
        )
    ).all()
    normas = sorted({i.norma_referencia for i in itens if i.norma_referencia})
    return EtapaNormasChecklistRead(etapa_id=etapa_id, normas=list(normas))


@app.post("/api/etapas/{etapa_id}/checklist-items/sugerir-grupo", response_model=SugerirGrupoResponse)
def sugerir_grupo_item(
    etapa_id: UUID,
    payload: SugerirGrupoRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> SugerirGrupoResponse:
    etapa = session.get(Etapa, etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")
    obra = session.get(Obra, etapa.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acesso negado")
    itens = session.exec(
        select(ChecklistItem).where(ChecklistItem.etapa_id == etapa_id)
    ).all()
    grupos_ordens: dict[str, int] = {}
    for item in itens:
        grupos_ordens[item.grupo] = max(grupos_ordens.get(item.grupo, 0), item.ordem)
    titulo_lower = payload.titulo.lower()
    for grupo in grupos_ordens:
        if grupo.lower() != "geral" and grupo.lower() in titulo_lower:
            return SugerirGrupoResponse(
                grupo=grupo,
                ordem=grupos_ordens[grupo] + 1,
            )
    return SugerirGrupoResponse(
        grupo="Geral",
        ordem=grupos_ordens.get("Geral", 0) + 1,
    )


@app.get("/api/checklist-items/{item_id}/evidencias", response_model=List[EvidenciaRead])
def listar_evidencias(item_id: UUID, session: Session = Depends(get_session), current_user: User = Depends(get_current_user)) -> list[Evidencia]:
    item = session.get(ChecklistItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item nao encontrado")
    _verify_etapa_ownership(item.etapa_id, current_user, session)
    return session.exec(select(Evidencia).where(Evidencia.checklist_item_id == item_id)).all()


@app.post("/api/checklist-items/{item_id}/evidencias", response_model=EvidenciaRead)
def upload_evidencia(
    item_id: UUID,
    file: UploadFile = File(...),
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> Evidencia:
    item = session.get(ChecklistItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item nao encontrado")
    _verify_etapa_ownership(item.etapa_id, current_user, session)
    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise HTTPException(status_code=500, detail="S3_BUCKET nao configurado")
    object_key = f"evidencias/{item_id}/{_sanitize_filename(file.filename)}"
    file.file.seek(0, os.SEEK_END)
    tamanho_bytes = file.file.tell()
    file.file.seek(0)
    file_url = upload_file(bucket, object_key, file.file, file.content_type)
    evidencia = Evidencia(
        checklist_item_id=item_id,
        arquivo_url=file_url,
        arquivo_nome=file.filename,
        mime_type=file.content_type,
        tamanho_bytes=tamanho_bytes,
    )
    session.add(evidencia)
    session.commit()
    session.refresh(evidencia)
    return evidencia


# ─── Fase 2 — Biblioteca Normativa Dinâmica ───────────────────────────────────

@app.post("/api/normas/buscar", response_model=NormaBuscarResponse)
def buscar_normas_endpoint(
    payload: NormaBuscarRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> NormaBuscarResponse:
    """
    Pesquisa normas técnicas brasileiras aplicáveis à etapa informada.
    Usa GPT-4o com web search. Registra a consulta de forma auditável.
    """
    try:
        resultado = buscar_normas(
            etapa_nome=payload.etapa_nome,
            disciplina=payload.disciplina,
            localizacao=payload.localizacao,
            obra_tipo=payload.obra_tipo,
        )
    except ValueError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Erro na pesquisa de normas: {exc}")

    # Persiste o log da consulta
    norma_log = NormaLog(
        etapa_nome=payload.etapa_nome,
        disciplina=payload.disciplina,
        localizacao=payload.localizacao,
        query_texto=resultado.get("query_texto", ""),
        data_consulta=datetime.utcnow(),
    )
    session.add(norma_log)
    session.commit()
    session.refresh(norma_log)

    # Persiste cada norma retornada
    normas_db: list[NormaResultado] = []
    for norma in resultado.get("normas", []):
        nr = NormaResultado(
            norma_log_id=norma_log.id,
            titulo=norma.get("titulo", ""),
            fonte_nome=norma.get("fonte_nome", ""),
            fonte_url=norma.get("fonte_url"),
            fonte_tipo=norma.get("fonte_tipo", "secundaria"),
            versao=norma.get("versao"),
            data_norma=norma.get("data_norma"),
            trecho_relevante=norma.get("trecho_relevante"),
            traducao_leigo=norma.get("traducao_leigo", ""),
            nivel_confianca=int(norma.get("nivel_confianca", 50)),
            risco_nivel=norma.get("risco_nivel"),
            requer_validacao_profissional=bool(norma.get("requer_validacao_profissional", False)),
        )
        session.add(nr)
        normas_db.append(nr)

    session.commit()
    for nr in normas_db:
        session.refresh(nr)

    return NormaBuscarResponse(
        log_id=norma_log.id,
        etapa_nome=payload.etapa_nome,
        resumo_geral=resultado.get("resumo_geral", ""),
        aviso_legal=resultado.get(
            "aviso_legal",
            "Este resultado é informativo e NÃO substitui parecer técnico de profissional habilitado.",
        ),
        data_consulta=resultado.get("data_consulta", datetime.utcnow().isoformat()),
        normas=[NormaResultadoRead.model_validate(nr) for nr in normas_db],
        checklist_dinamico=resultado.get("checklist_dinamico", []),
    )


@app.get("/api/normas/historico", response_model=List[NormaLogRead])
def listar_historico_normas(
    limit: int = 20,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[NormaLog]:
    """Lista as últimas consultas normativas realizadas."""
    logs = session.exec(
        select(NormaLog).order_by(NormaLog.data_consulta.desc()).limit(limit)
    ).all()
    result = []
    for log in logs:
        resultados = session.exec(
            select(NormaResultado).where(NormaResultado.norma_log_id == log.id)
        ).all()
        log_read = NormaLogRead.model_validate(log)
        log_read.resultados = [NormaResultadoRead.model_validate(r) for r in resultados]
        result.append(log_read)
    return result


@app.get("/api/normas/historico/{log_id}", response_model=NormaLogRead)
def obter_consulta_norma(log_id: UUID, session: Session = Depends(get_session), current_user: User = Depends(get_current_user)) -> NormaLogRead:
    """Retorna uma consulta normativa específica com todos os resultados."""
    log = session.get(NormaLog, log_id)
    if not log:
        raise HTTPException(status_code=404, detail="Consulta nao encontrada")
    resultados = session.exec(
        select(NormaResultado).where(NormaResultado.norma_log_id == log_id)
    ).all()
    log_read = NormaLogRead.model_validate(log)
    log_read.resultados = [NormaResultadoRead.model_validate(r) for r in resultados]
    return log_read


@app.get("/api/normas/etapas")
def listar_etapas_suportadas() -> dict:
    """Lista as etapas com suporte a busca normativa e suas palavras-chave."""
    from .normas import KEYWORDS_POR_ETAPA
    return {
        "etapas": [
            {"nome": etapa, "keywords": kws}
            for etapa, kws in KEYWORDS_POR_ETAPA.items()
        ]
    }


# ─── Fase 2 — Governança Financeira ──────────────────────────────────────────

@app.post("/api/obras/{obra_id}/orcamento", response_model=List[OrcamentoEtapaRead])
def registrar_orcamento(
    obra_id: UUID,
    payload: List[OrcamentoEtapaCreate],
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[OrcamentoEtapa]:
    """Registra ou atualiza o orçamento previsto por etapa (upsert)."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    resultado: list[OrcamentoEtapa] = []
    for item in payload:
        existing = session.exec(
            select(OrcamentoEtapa)
            .where(OrcamentoEtapa.obra_id == obra_id)
            .where(OrcamentoEtapa.etapa_id == item.etapa_id)
        ).first()
        if existing:
            existing.valor_previsto = item.valor_previsto
            existing.updated_at = datetime.utcnow()
            session.add(existing)
            resultado.append(existing)
        else:
            orcamento = OrcamentoEtapa(
                obra_id=obra_id,
                etapa_id=item.etapa_id,
                valor_previsto=item.valor_previsto,
            )
            session.add(orcamento)
            resultado.append(orcamento)
    session.commit()
    for o in resultado:
        session.refresh(o)
    return resultado


@app.get("/api/obras/{obra_id}/orcamento", response_model=List[OrcamentoEtapaRead])
def consultar_orcamento(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[OrcamentoEtapa]:
    """Retorna o orçamento previsto por etapa da obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    return session.exec(
        select(OrcamentoEtapa).where(OrcamentoEtapa.obra_id == obra_id)
    ).all()


@app.post("/api/obras/{obra_id}/despesas", response_model=DespesaRead)
def lancar_despesa(
    obra_id: UUID,
    payload: DespesaCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> Despesa:
    """Lança uma nova despesa na obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    if payload.etapa_id:
        etapa = session.get(Etapa, payload.etapa_id)
        if not etapa or etapa.obra_id != obra_id:
            raise HTTPException(status_code=400, detail="Etapa nao pertence a esta obra")
    despesa = Despesa(obra_id=obra_id, **payload.model_dump(mode="json"))
    session.add(despesa)
    session.commit()
    session.refresh(despesa)

    # Verificar se o lançamento disparou um alerta orçamentário
    _verificar_e_notificar_alerta(obra_id=obra_id, obra=obra, session=session)

    return despesa


@app.get("/api/obras/{obra_id}/despesas", response_model=List[DespesaRead])
def listar_despesas(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[Despesa]:
    """Lista todas as despesas lançadas na obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    return session.exec(
        select(Despesa).where(Despesa.obra_id == obra_id).order_by(Despesa.data.desc())
    ).all()


@app.get("/api/obras/{obra_id}/relatorio-financeiro", response_model=RelatorioFinanceiro)
def relatorio_financeiro(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> RelatorioFinanceiro:
    """Calcula desvio orçamentário e prepara dados para curva S."""
    obra = _verify_obra_ownership(obra_id, current_user, session)

    etapas = session.exec(
        select(Etapa).where(Etapa.obra_id == obra_id).order_by(Etapa.ordem)
    ).all()
    orcamentos = session.exec(
        select(OrcamentoEtapa).where(OrcamentoEtapa.obra_id == obra_id)
    ).all()
    despesas = session.exec(
        select(Despesa).where(Despesa.obra_id == obra_id)
    ).all()
    alerta_config = session.exec(
        select(AlertaConfig).where(AlertaConfig.obra_id == obra_id)
    ).first()
    threshold = alerta_config.percentual_desvio_threshold if alerta_config else 10.0

    orcamento_por_etapa = {str(o.etapa_id): o.valor_previsto for o in orcamentos}
    gasto_por_etapa: dict[str, float] = {}
    for d in despesas:
        key = str(d.etapa_id) if d.etapa_id else "__sem_etapa__"
        gasto_por_etapa[key] = gasto_por_etapa.get(key, 0.0) + d.valor

    por_etapa: list[EtapaFinanceiroItem] = []
    for etapa in etapas:
        previsto = orcamento_por_etapa.get(str(etapa.id), 0.0)
        gasto = gasto_por_etapa.get(str(etapa.id), 0.0)
        if previsto > 0:
            desvio_pct = ((gasto - previsto) / previsto) * 100
        else:
            desvio_pct = 0.0
        por_etapa.append(EtapaFinanceiroItem(
            etapa_id=str(etapa.id),
            etapa_nome=etapa.nome,
            valor_previsto=previsto,
            valor_gasto=gasto,
            desvio_percentual=round(desvio_pct, 2),
            alerta=desvio_pct > threshold,
        ))

    total_previsto = sum(e.valor_previsto for e in por_etapa)
    total_gasto = sum(e.valor_gasto for e in por_etapa)
    if total_previsto > 0:
        desvio_total = ((total_gasto - total_previsto) / total_previsto) * 100
    else:
        desvio_total = 0.0

    return RelatorioFinanceiro(
        obra_id=obra_id,
        total_previsto=total_previsto,
        total_gasto=total_gasto,
        desvio_percentual=round(desvio_total, 2),
        alerta=desvio_total > threshold,
        threshold=threshold,
        por_etapa=por_etapa,
    )


@app.put("/api/obras/{obra_id}/alertas", response_model=AlertaConfigRead)
def configurar_alertas(
    obra_id: UUID,
    payload: AlertaConfigUpdate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> AlertaConfig:
    """Cria ou atualiza a configuração de alertas de desvio da obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    config = session.exec(
        select(AlertaConfig).where(AlertaConfig.obra_id == obra_id)
    ).first()
    if not config:
        config = AlertaConfig(obra_id=obra_id)
        session.add(config)
    updates = payload.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(config, key, value)
    config.updated_at = datetime.utcnow()
    session.add(config)
    session.commit()
    session.refresh(config)
    return config


# ─── Push Notifications ───────────────────────────────────────────────────────

def _verificar_e_notificar_alerta(obra_id: UUID, obra: Obra, session: Session) -> None:
    """
    Após um lançamento de despesa, recalcula o desvio total da obra.
    Se o desvio superar o threshold configurado e notificacao_ativa=True,
    envia push para todos os dispositivos registrados na obra.
    Execução best-effort: falhas não propagam exceção.
    """
    try:
        alerta_config = session.exec(
            select(AlertaConfig).where(AlertaConfig.obra_id == obra_id)
        ).first()
        if not alerta_config or not alerta_config.notificacao_ativa:
            return

        orcamentos = session.exec(
            select(OrcamentoEtapa).where(OrcamentoEtapa.obra_id == obra_id)
        ).all()
        despesas = session.exec(
            select(Despesa).where(Despesa.obra_id == obra_id)
        ).all()

        total_previsto = sum(o.valor_previsto for o in orcamentos)
        total_gasto = sum(d.valor for d in despesas)

        if total_previsto <= 0:
            return

        desvio_pct = ((total_gasto - total_previsto) / total_previsto) * 100
        if desvio_pct <= alerta_config.percentual_desvio_threshold:
            return

        tokens = session.exec(
            select(DeviceToken).where(DeviceToken.obra_id == obra_id)
        ).all()
        if not tokens:
            return

        token_list = [dt.token for dt in tokens]
        titulo = "⚠️ Alerta Orçamentário"
        corpo = (
            f"{obra.nome}: desvio de {desvio_pct:.1f}% "
            f"(limite: {alerta_config.percentual_desvio_threshold:.0f}%)"
        )
        enviar_push_multiplos(
            token_list,
            titulo,
            corpo,
            data={"obra_id": str(obra_id), "tipo": "alerta_orcamentario"},
        )
    except Exception as exc:
        import logging
        logging.getLogger(__name__).error("Erro ao verificar alerta push: %s", exc)


@app.post("/api/obras/{obra_id}/device-tokens", response_model=DeviceTokenRead)
def registrar_device_token(
    obra_id: UUID,
    payload: DeviceTokenCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> DeviceToken:
    """Registra (ou atualiza) o token FCM de um dispositivo para esta obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)

    # Evitar duplicatas: upsert por token+obra_id
    existing = session.exec(
        select(DeviceToken).where(
            DeviceToken.obra_id == obra_id,
            DeviceToken.token == payload.token,
        )
    ).first()

    if existing:
        existing.platform = payload.platform
        existing.updated_at = datetime.utcnow()
        session.add(existing)
        session.commit()
        session.refresh(existing)
        return existing

    dt = DeviceToken(obra_id=obra_id, token=payload.token, platform=payload.platform)
    session.add(dt)
    session.commit()
    session.refresh(dt)
    return dt


@app.delete("/api/obras/{obra_id}/device-tokens/{token}", status_code=204)
def remover_device_token(
    obra_id: UUID,
    token: str,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> None:
    """Remove o token FCM de um dispositivo (ex: ao fazer logout ou desativar alertas)."""
    dt = session.exec(
        select(DeviceToken).where(
            DeviceToken.obra_id == obra_id,
            DeviceToken.token == token,
        )
    ).first()
    if dt:
        session.delete(dt)
        session.commit()


# ─── Fase 3 — Document AI ─────────────────────────────────────────────────────

@app.post("/api/obras/{obra_id}/projetos", response_model=ProjetoDocRead)
def upload_projeto(
    obra_id: UUID,
    file: UploadFile = File(...),
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> ProjetoDoc:
    """Faz upload de um PDF de projeto e cria o registro para análise."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise HTTPException(status_code=500, detail="S3_BUCKET nao configurado")
    object_key = f"projetos/{obra_id}/{_sanitize_filename(file.filename)}"
    file.file.seek(0)
    file_url = upload_file(bucket, object_key, file.file, file.content_type)
    projeto = ProjetoDoc(
        obra_id=obra_id,
        arquivo_url=file_url,
        arquivo_nome=file.filename,
        status="pendente",
    )
    session.add(projeto)
    session.commit()
    session.refresh(projeto)
    return projeto


@app.get("/api/obras/{obra_id}/projetos", response_model=List[ProjetoDocRead])
def listar_projetos(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[ProjetoDoc]:
    """Lista todos os projetos PDF enviados para a obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    return session.exec(
        select(ProjetoDoc)
        .where(ProjetoDoc.obra_id == obra_id)
        .order_by(ProjetoDoc.created_at.desc())
    ).all()


@app.get("/api/projetos/{projeto_id}", response_model=ProjetoDocRead)
def obter_projeto(
    projeto_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> ProjetoDoc:
    """Retorna os detalhes de um projeto PDF."""
    projeto = session.get(ProjetoDoc, projeto_id)
    if not projeto:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    return projeto


@app.delete("/api/projetos/{projeto_id}")
def deletar_projeto(
    projeto_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Remove um projeto PDF e seus riscos associados."""
    projeto = session.get(ProjetoDoc, projeto_id)
    if not projeto:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    try:
        # Remove riscos associados primeiro (FK constraint)
        riscos = session.exec(select(Risco).where(Risco.projeto_id == projeto_id)).all()
        for r in riscos:
            session.delete(r)
        session.flush()

        # Remove o projeto do banco
        session.delete(projeto)
        session.commit()
    except Exception as exc:
        session.rollback()
        logger.error("Erro ao deletar projeto %s do banco: %s", projeto_id, exc)
        raise HTTPException(status_code=500, detail=f"Erro ao remover projeto do banco: {exc}")

    # Tenta remover arquivo do storage (apos commit, nao bloqueia em caso de erro)
    bucket = os.getenv("S3_BUCKET")
    if bucket and projeto.arquivo_url:
        try:
            object_key = extract_object_key(projeto.arquivo_url, bucket)
            from .storage import _use_gcs
            if _use_gcs():
                from .storage import _get_gcs_client
                client = _get_gcs_client()
                bl = client.bucket(bucket).blob(object_key)
                bl.delete()
            else:
                from .storage import _get_s3_client
                _get_s3_client().delete_object(Bucket=bucket, Key=object_key)
        except Exception as exc:
            logger.warning("Falha ao remover arquivo do storage para projeto %s: %s", projeto_id, exc)

    return {"ok": True}


@app.post("/api/projetos/{projeto_id}/analisar", response_model=ProjetoDocRead)
def analisar_projeto(
    projeto_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> ProjetoDoc:
    """
    Dispara a análise de IA sobre o PDF do projeto.
    Baixa o PDF do S3, envia ao Claude e persiste os riscos encontrados.
    """
    projeto = session.get(ProjetoDoc, projeto_id)
    if not projeto:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    if projeto.status == "processando":
        raise HTTPException(status_code=409, detail="Analise ja em andamento")

    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise HTTPException(status_code=500, detail="S3_BUCKET nao configurado")

    # Atualiza status para processando
    projeto.status = "processando"
    projeto.updated_at = datetime.utcnow()
    session.add(projeto)
    session.commit()

    try:
        object_key = extract_object_key(projeto.arquivo_url, bucket)

        pdf_bytes = download_by_url(projeto.arquivo_url, bucket, object_key)
        resultado = analisar_documento(pdf_bytes, projeto.arquivo_nome)

        # Remove riscos anteriores se houver re-análise
        riscos_antigos = session.exec(
            select(Risco).where(Risco.projeto_id == projeto_id)
        ).all()
        for r in riscos_antigos:
            session.delete(r)

        # Persiste os novos riscos
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

        projeto.resumo_geral = resultado.get("resumo_geral")
        projeto.aviso_legal = resultado.get(
            "aviso_legal",
            "Esta análise é informativa e NÃO substitui parecer técnico de profissional habilitado.",
        )
        projeto.status = "concluido"
        projeto.updated_at = datetime.utcnow()
        session.add(projeto)
        session.commit()
        session.refresh(projeto)
        return projeto

    except Exception as exc:
        projeto.status = "erro"
        projeto.updated_at = datetime.utcnow()
        session.add(projeto)
        session.commit()
        raise HTTPException(status_code=502, detail=f"Erro na analise: {exc}")


@app.get("/api/projetos/{projeto_id}/analise", response_model=ProjetoAnaliseRead)
def obter_analise(
    projeto_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> ProjetoAnaliseRead:
    """Retorna o projeto com todos os riscos identificados pela IA."""
    projeto = session.get(ProjetoDoc, projeto_id)
    if not projeto:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    riscos = session.exec(
        select(Risco)
        .where(Risco.projeto_id == projeto_id)
        .order_by(Risco.severidade)
    ).all()
    return ProjetoAnaliseRead(
        projeto=ProjetoDocRead.model_validate(projeto),
        riscos=[RiscoRead.model_validate(r) for r in riscos],
    )


# ─── Fase 4 — Visual AI ───────────────────────────────────────────────────────

@app.post("/api/etapas/{etapa_id}/analise-visual", response_model=AnaliseVisualComAchadosRead)
def analisar_visual(
    etapa_id: UUID,
    file: UploadFile = File(...),
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> AnaliseVisualComAchadosRead:
    """
    Faz upload de uma foto e dispara análise visual por IA.
    Armazena no S3, envia ao Claude Vision e persiste os achados.
    """
    etapa = _verify_etapa_ownership(etapa_id, current_user, session)

    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise HTTPException(status_code=500, detail="S3_BUCKET nao configurado")

    # Salva a imagem no S3
    object_key = f"analises-visuais/{etapa_id}/{_sanitize_filename(file.filename)}"
    file.file.seek(0)
    imagem_url = upload_file(bucket, object_key, file.file, file.content_type)

    # Cria o registro com status processando
    analise = AnaliseVisual(
        etapa_id=etapa_id,
        imagem_url=imagem_url,
        imagem_nome=file.filename,
        status="processando",
    )
    session.add(analise)
    session.commit()
    session.refresh(analise)

    try:
        file.file.seek(0)
        imagem_bytes = file.file.read()
        resultado = analisar_imagem(imagem_bytes, file.filename, etapa.nome)

        achados_db: list[Achado] = []
        for achado_data in resultado.get("achados", []):
            achado = Achado(
                analise_id=analise.id,
                descricao=achado_data.get("descricao", ""),
                severidade=achado_data.get("severidade", "baixo"),
                acao_recomendada=achado_data.get("acao_recomendada", ""),
                requer_evidencia_adicional=bool(achado_data.get("requer_evidencia_adicional", False)),
                requer_validacao_profissional=bool(achado_data.get("requer_validacao_profissional", False)),
                confianca=int(achado_data.get("confianca", 50)),
            )
            session.add(achado)
            achados_db.append(achado)

        analise.etapa_inferida = resultado.get("etapa_inferida")
        analise.confianca = int(resultado.get("confianca_etapa", 0))
        analise.resumo_geral = resultado.get("resumo_geral")
        analise.aviso_legal = resultado.get(
            "aviso_legal",
            "Esta análise é informativa e NÃO substitui vistoria técnica de engenheiro ou arquiteto habilitado.",
        )
        analise.status = "concluida"
        analise.updated_at = datetime.utcnow()
        session.add(analise)
        session.commit()
        session.refresh(analise)
        for a in achados_db:
            session.refresh(a)

        return AnaliseVisualComAchadosRead(
            analise=AnaliseVisualRead.model_validate(analise),
            achados=[AchadoRead.model_validate(a) for a in achados_db],
        )

    except Exception as exc:
        analise.status = "erro"
        analise.updated_at = datetime.utcnow()
        session.add(analise)
        session.commit()
        raise HTTPException(status_code=502, detail=f"Erro na analise visual: {exc}")


@app.get("/api/etapas/{etapa_id}/analises-visuais", response_model=List[AnaliseVisualRead])
def listar_analises_visuais(
    etapa_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[AnaliseVisual]:
    """Lista todas as análises visuais de uma etapa."""
    etapa = _verify_etapa_ownership(etapa_id, current_user, session)
    return session.exec(
        select(AnaliseVisual)
        .where(AnaliseVisual.etapa_id == etapa_id)
        .order_by(AnaliseVisual.created_at.desc())
    ).all()


@app.get("/api/analises-visuais/{analise_id}", response_model=AnaliseVisualComAchadosRead)
def obter_analise_visual(
    analise_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> AnaliseVisualComAchadosRead:
    """Retorna uma análise visual com todos os achados."""
    analise = session.get(AnaliseVisual, analise_id)
    if not analise:
        raise HTTPException(status_code=404, detail="Analise nao encontrada")
    achados = session.exec(
        select(Achado)
        .where(Achado.analise_id == analise_id)
        .order_by(Achado.severidade)
    ).all()
    return AnaliseVisualComAchadosRead(
        analise=AnaliseVisualRead.model_validate(analise),
        achados=[AchadoRead.model_validate(a) for a in achados],
    )


# ─── Fase 5 — Prestadores e Fornecedores ─────────────────────────────────────

SUBCATEGORIAS_MAP: dict[str, list[str]] = {
    CategoriaPrestador.PRESTADOR_SERVICO.value: [e.value for e in SubcategoriaPrestadorServico],
    CategoriaPrestador.MATERIAIS.value: [e.value for e in SubcategoriaMateriais],
}

NOTAS_SERVICO = ["nota_qualidade_servico", "nota_cumprimento_prazos", "nota_fidelidade_projeto"]
NOTAS_MATERIAL = ["nota_prazo_entrega", "nota_qualidade_material"]


@app.get("/api/prestadores/subcategorias")
def listar_subcategorias() -> dict:
    """Retorna as subcategorias válidas por categoria."""
    return SUBCATEGORIAS_MAP


@app.post("/api/prestadores", response_model=PrestadorRead)
def criar_prestador(
    payload: PrestadorCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> dict:
    """Cadastra um novo prestador de serviço ou fornecedor de materiais."""
    if payload.categoria not in SUBCATEGORIAS_MAP:
        raise HTTPException(status_code=422, detail="Categoria invalida")
    if payload.subcategoria not in SUBCATEGORIAS_MAP[payload.categoria]:
        raise HTTPException(status_code=422, detail="Subcategoria invalida para esta categoria")

    prestador = Prestador(**payload.model_dump())
    session.add(prestador)
    session.commit()
    session.refresh(prestador)
    return PrestadorRead(
        **prestador.model_dump(),
        nota_geral=None,
        total_avaliacoes=0,
    )


@app.get("/api/prestadores", response_model=List[PrestadorRead])
def listar_prestadores(
    categoria: str | None = None,
    subcategoria: str | None = None,
    regiao: str | None = None,
    q: str | None = None,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[dict]:
    """Lista prestadores com filtros opcionais e nota média."""
    from sqlalchemy import func

    query = select(Prestador)
    if categoria:
        query = query.where(Prestador.categoria == categoria)
    if subcategoria:
        query = query.where(Prestador.subcategoria == subcategoria)
    if regiao:
        query = query.where(Prestador.regiao.ilike(f"%{regiao}%"))
    if q:
        query = query.where(Prestador.nome.ilike(f"%{q}%"))

    query = query.order_by(Prestador.nome)
    prestadores = session.exec(query).all()

    resultado: list[dict] = []
    for p in prestadores:
        avaliacoes = session.exec(
            select(Avaliacao).where(Avaliacao.prestador_id == p.id)
        ).all()
        total = len(avaliacoes)
        nota_geral = None
        if total > 0:
            if p.categoria == CategoriaPrestador.PRESTADOR_SERVICO.value:
                campos = NOTAS_SERVICO
            else:
                campos = NOTAS_MATERIAL
            todas_notas = []
            for av in avaliacoes:
                for campo in campos:
                    val = getattr(av, campo)
                    if val is not None:
                        todas_notas.append(val)
            if todas_notas:
                nota_geral = round(sum(todas_notas) / len(todas_notas), 1)

        resultado.append(PrestadorRead(
            **p.model_dump(),
            nota_geral=nota_geral,
            total_avaliacoes=total,
        ))

    # Ordenar por nota (melhores primeiro), sem nota por último
    resultado.sort(key=lambda r: (r.nota_geral is None, -(r.nota_geral or 0)))
    return resultado


@app.get("/api/prestadores/{prestador_id}", response_model=PrestadorDetalheRead)
def obter_prestador(
    prestador_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> PrestadorDetalheRead:
    """Retorna um prestador com todas as avaliações e médias por tópico."""
    prestador = session.get(Prestador, prestador_id)
    if not prestador:
        raise HTTPException(status_code=404, detail="Prestador nao encontrado")

    avaliacoes = session.exec(
        select(Avaliacao)
        .where(Avaliacao.prestador_id == prestador_id)
        .order_by(Avaliacao.created_at.desc())
    ).all()

    # Calcular médias por tópico
    if prestador.categoria == CategoriaPrestador.PRESTADOR_SERVICO.value:
        campos = NOTAS_SERVICO
    else:
        campos = NOTAS_MATERIAL

    medias: dict[str, float] = {}
    for campo in campos:
        notas = [getattr(av, campo) for av in avaliacoes if getattr(av, campo) is not None]
        if notas:
            medias[campo] = round(sum(notas) / len(notas), 1)

    total = len(avaliacoes)
    todas_notas_flat = []
    for av in avaliacoes:
        for campo in campos:
            val = getattr(av, campo)
            if val is not None:
                todas_notas_flat.append(val)
    nota_geral = round(sum(todas_notas_flat) / len(todas_notas_flat), 1) if todas_notas_flat else None

    return PrestadorDetalheRead(
        prestador=PrestadorRead(
            **prestador.model_dump(),
            nota_geral=nota_geral,
            total_avaliacoes=total,
        ),
        avaliacoes=[AvaliacaoRead.model_validate(av) for av in avaliacoes],
        medias=medias,
    )


@app.patch("/api/prestadores/{prestador_id}", response_model=PrestadorRead)
def atualizar_prestador(
    prestador_id: UUID,
    payload: PrestadorUpdate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> dict:
    """Atualiza dados de um prestador."""
    prestador = session.get(Prestador, prestador_id)
    if not prestador:
        raise HTTPException(status_code=404, detail="Prestador nao encontrado")
    updates = payload.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(prestador, key, value)
    prestador.updated_at = datetime.utcnow()
    session.add(prestador)
    session.commit()
    session.refresh(prestador)

    avaliacoes = session.exec(
        select(Avaliacao).where(Avaliacao.prestador_id == prestador_id)
    ).all()
    total = len(avaliacoes)
    campos = NOTAS_SERVICO if prestador.categoria == CategoriaPrestador.PRESTADOR_SERVICO.value else NOTAS_MATERIAL
    todas_notas = []
    for av in avaliacoes:
        for campo in campos:
            val = getattr(av, campo)
            if val is not None:
                todas_notas.append(val)
    nota_geral = round(sum(todas_notas) / len(todas_notas), 1) if todas_notas else None

    return PrestadorRead(
        **prestador.model_dump(),
        nota_geral=nota_geral,
        total_avaliacoes=total,
    )


@app.post("/api/prestadores/{prestador_id}/avaliacoes", response_model=AvaliacaoRead)
def criar_avaliacao(
    prestador_id: UUID,
    payload: AvaliacaoCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> Avaliacao:
    """Cria uma avaliação para um prestador, validando os tópicos pela categoria."""
    prestador = session.get(Prestador, prestador_id)
    if not prestador:
        raise HTTPException(status_code=404, detail="Prestador nao encontrado")

    if prestador.categoria == CategoriaPrestador.PRESTADOR_SERVICO.value:
        campos_validos = NOTAS_SERVICO
        campos_invalidos = NOTAS_MATERIAL
    else:
        campos_validos = NOTAS_MATERIAL
        campos_invalidos = NOTAS_SERVICO

    # Rejeitar notas de outra categoria
    for campo in campos_invalidos:
        if getattr(payload, campo) is not None:
            raise HTTPException(
                status_code=422,
                detail=f"Campo '{campo}' nao se aplica a categoria '{prestador.categoria}'",
            )

    # Exigir ao menos uma nota
    notas_preenchidas = [getattr(payload, c) for c in campos_validos if getattr(payload, c) is not None]
    if not notas_preenchidas:
        raise HTTPException(status_code=422, detail="Informe ao menos uma nota")

    avaliacao = Avaliacao(prestador_id=prestador_id, **payload.model_dump())
    session.add(avaliacao)
    session.commit()
    session.refresh(avaliacao)
    return avaliacao


@app.get("/api/prestadores/{prestador_id}/avaliacoes", response_model=List[AvaliacaoRead])
def listar_avaliacoes(
    prestador_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[Avaliacao]:
    """Lista todas as avaliações de um prestador."""
    prestador = session.get(Prestador, prestador_id)
    if not prestador:
        raise HTTPException(status_code=404, detail="Prestador nao encontrado")
    return session.exec(
        select(Avaliacao)
        .where(Avaliacao.prestador_id == prestador_id)
        .order_by(Avaliacao.created_at.desc())
    ).all()


# ─── Fase 6 — Checklist Inteligente ─────────────────────────────────────────

@app.get("/api/obras/{obra_id}/checklist-inteligente/stream")
def stream_checklist_inteligente(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """
    SSE endpoint que gera checklist inteligente em tempo real.
    Processa pagina por pagina, emitindo eventos de progresso.
    """
    obra = _verify_obra_ownership(obra_id, current_user, session)

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

    # Baixar PDFs antes de iniciar o stream
    pdfs: list[tuple[bytes, str]] = []
    for projeto in projetos:
        object_key = extract_object_key(projeto.arquivo_url, bucket)
        pdf_bytes = download_by_url(projeto.arquivo_url, bucket, object_key)
        pdfs.append((pdf_bytes, projeto.arquivo_nome))

    return StreamingResponse(
        gerar_checklist_stream(pdfs=pdfs, localizacao=obra.localizacao),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )


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

    projetos_info = [(p.arquivo_url, p.arquivo_nome) for p in projetos]

    # Create log entry
    log = ChecklistGeracaoLog(
        obra_id=obra_id,
        status="processando",
        total_docs_analisados=len(projetos),
    )
    session.add(log)
    session.commit()
    session.refresh(log)

    # Launch background thread — PDFs are downloaded inside the thread
    from .db import get_database_url
    thread = threading.Thread(
        target=processar_checklist_background,
        args=(log.id, projetos_info, obra.localizacao, get_database_url(), bucket),
        daemon=True,
    )
    thread.start()

    return log


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


@app.post(
    "/api/obras/{obra_id}/checklist-inteligente/aplicar",
    response_model=AplicarChecklistResponse,
)
def aplicar_checklist_inteligente(
    obra_id: UUID,
    payload: AplicarChecklistRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> AplicarChecklistResponse:
    """
    Aplica os itens selecionados pelo usuario ao checklist real.
    Etapa 2 do fluxo: gerar -> revisar -> aplicar.
    """
    obra = _verify_obra_ownership(obra_id, current_user, session)

    log = None
    if payload.log_id:
        log = session.get(ChecklistGeracaoLog, payload.log_id)
        if not log or log.obra_id != obra_id:
            raise HTTPException(status_code=404, detail="Log de geracao nao encontrado")

    # Mapear etapas por nome
    etapas = session.exec(
        select(Etapa).where(Etapa.obra_id == obra_id)
    ).all()
    etapa_map: dict[str, UUID] = {e.nome: e.id for e in etapas}

    itens_criados: list[ChecklistItem] = []
    for item_data in payload.itens:
        etapa_id = etapa_map.get(item_data.etapa_nome)
        if not etapa_id:
            continue

        # Capitalizar grupo da caracteristica_origem (ex: "piscina" -> "Piscina")
        grupo = getattr(item_data, "grupo", "Geral") or "Geral"
        grupo = grupo.replace("_", " ").title()

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
        )
        session.add(novo_item)
        itens_criados.append(novo_item)

    if log:
        log.total_itens_aplicados = len(itens_criados)
        log.updated_at = datetime.utcnow()
        session.add(log)

    session.commit()
    for item in itens_criados:
        session.refresh(item)

    return AplicarChecklistResponse(
        total_aplicados=len(itens_criados),
        itens_criados=[ChecklistItemRead.model_validate(i) for i in itens_criados],
    )


@app.get(
    "/api/obras/{obra_id}/checklist-inteligente/historico",
    response_model=List[ChecklistGeracaoLogRead],
)
def historico_checklist_inteligente(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[ChecklistGeracaoLog]:
    """Lista o historico de geracoes de checklist inteligente para a obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    return session.exec(
        select(ChecklistGeracaoLog)
        .where(ChecklistGeracaoLog.obra_id == obra_id)
        .order_by(ChecklistGeracaoLog.created_at.desc())
    ).all()
