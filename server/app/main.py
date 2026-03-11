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

from fastapi import FastAPI, Depends, HTTPException, Request, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response, StreamingResponse
from sqlmodel import Session, select

from .db import get_session, init_db
from .models import (
    User, Obra, Etapa, ChecklistItem, Evidencia, NormaLog, NormaResultado,
    OrcamentoEtapa, Despesa, AlertaConfig, ProjetoDoc, Risco, AnaliseVisual,
    Achado, DeviceToken, Prestador, Avaliacao, ChecklistGeracaoLog,
    ChecklistGeracaoItem, Subscription, UsageTracking, RevenueCatEvent,
    ObraConvite, EtapaComentario,
)
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
    RegistrarVerificacaoRequest,
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
    GoogleLoginRequest,
    GoogleTokenResponse,
    UpdateProfileRequest,
    EtapaPrazoUpdate,
    EtapaNormasChecklistRead,
    SugerirGrupoRequest,
    SugerirGrupoResponse,
    SubscriptionInfoResponse,
    ConviteCreateRequest,
    ConviteRead,
    ConviteAceitarRequest,
    ObraConvidadaRead,
    ComentarioCreateRequest,
    ComentarioRead,
)
from .auth import hash_password, verify_password, create_access_token, create_refresh_token, decode_token, get_current_user
from .subscription import (
    PLAN_CONFIG, get_plan_config, require_paid, require_dono,
    check_and_increment_usage, get_usage_count, check_obra_access,
    check_obra_limit, check_convite_limit,
)
from google.oauth2 import id_token as google_id_token
from google.auth.transport import requests as google_requests
from .storage import ensure_bucket, upload_file, download_file, download_by_url, extract_object_key
from .pdf import render_obra_pdf
from .seed_checklists import get_itens_padrao
from .normas import buscar_normas
from .documentos import analisar_documento
from .visual_ai import analisar_imagem
from .push import enviar_push_multiplos
from .checklist_inteligente import gerar_checklist_stream, processar_checklist_background, enriquecer_item_unico
from .email_service import enviar_email_convite


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


from fastapi.responses import HTMLResponse

@app.get("/privacy", response_class=HTMLResponse)
def privacy_policy():
    return """<!DOCTYPE html>
<html lang="pt-BR"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Política de Privacidade — Mestre da Obra</title>
<style>body{font-family:system-ui,sans-serif;max-width:720px;margin:2rem auto;padding:0 1rem;line-height:1.6;color:#333}h1{color:#1a5276}h2{color:#2c3e50;margin-top:2rem}</style></head><body>
<h1>Política de Privacidade — Mestre da Obra</h1>
<p><strong>Última atualização:</strong> 10 de março de 2026</p>

<h2>1. Informações que coletamos</h2>
<p>O Mestre da Obra coleta as seguintes informações para fornecer nossos serviços:</p>
<ul>
<li><strong>Dados de cadastro:</strong> nome, e-mail e senha (armazenada de forma criptografada).</li>
<li><strong>Dados de obras:</strong> informações sobre obras, etapas, orçamentos e checklists que você cadastra.</li>
<li><strong>Fotos e câmera:</strong> quando você utiliza a funcionalidade de análise visual, acessamos a câmera do dispositivo para capturar fotos da obra. As fotos são armazenadas de forma segura e usadas exclusivamente para análise técnica.</li>
<li><strong>Documentos (PDF):</strong> projetos enviados para análise por inteligência artificial.</li>
</ul>

<h2>2. Como usamos suas informações</h2>
<ul>
<li>Gerenciar suas obras, etapas e orçamentos.</li>
<li>Analisar fotos e projetos via inteligência artificial para identificar possíveis problemas.</li>
<li>Enviar notificações sobre alertas e atualizações da obra.</li>
<li>Processar pagamentos de assinatura via Stripe.</li>
</ul>

<h2>3. Compartilhamento de dados</h2>
<p>Não vendemos seus dados pessoais. Compartilhamos informações apenas com:</p>
<ul>
<li><strong>Stripe:</strong> para processamento seguro de pagamentos.</li>
<li><strong>Provedores de IA:</strong> para análise de fotos e projetos (dados anonimizados quando possível).</li>
<li><strong>Profissionais convidados:</strong> apenas dados da obra específica, quando você convida um profissional.</li>
</ul>

<h2>4. Armazenamento e segurança</h2>
<p>Seus dados são armazenados em servidores seguros (Google Cloud Platform e Supabase) com criptografia em trânsito e em repouso. Senhas são protegidas com hash bcrypt.</p>

<h2>5. Seus direitos (LGPD)</h2>
<p>Conforme a Lei Geral de Proteção de Dados (Lei 13.709/2018), você tem direito a:</p>
<ul>
<li>Acessar seus dados pessoais.</li>
<li>Corrigir dados incompletos ou desatualizados.</li>
<li>Solicitar a exclusão da sua conta e dados associados.</li>
<li>Revogar consentimento a qualquer momento.</li>
</ul>
<p>Para exercer seus direitos, acesse "Minha Conta" no app ou entre em contato pelo e-mail abaixo.</p>

<h2>6. ID de publicidade</h2>
<p>O Mestre da Obra <strong>não utiliza</strong> o ID de publicidade do Google (AD_ID) e não exibe anúncios.</p>

<h2>7. Contato</h2>
<p>Para dúvidas sobre esta política: <strong>andrefharing@gmail.com</strong></p>

<h2>8. Alterações</h2>
<p>Esta política pode ser atualizada periodicamente. Notificaremos sobre mudanças significativas pelo app.</p>
</body></html>"""


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
        user=UserRead.from_user(user),
    )


@app.post("/api/auth/login", response_model=TokenResponse)
def login(payload: UserLogin, session: Session = Depends(get_session)):
    user = session.exec(select(User).where(User.email == payload.email.lower().strip())).first()
    if not user or not user.password_hash:
        raise HTTPException(status_code=401, detail="Email ou senha incorretos")
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Email ou senha incorretos")
    if not user.ativo:
        raise HTTPException(status_code=403, detail="Conta desativada")
    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        user=UserRead.from_user(user),
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
        user=UserRead.from_user(user),
    )


@app.get("/api/auth/me", response_model=UserRead)
def me(current_user: User = Depends(get_current_user)):
    return UserRead.from_user(current_user)


@app.post("/api/auth/google", response_model=GoogleTokenResponse)
def login_google(payload: GoogleLoginRequest, session: Session = Depends(get_session)):
    """Verifica um Google ID Token e retorna JWT próprio."""
    google_client_id = os.getenv("GOOGLE_CLIENT_ID")
    if not google_client_id:
        raise HTTPException(status_code=500, detail="Google login nao configurado")
    try:
        info = google_id_token.verify_oauth2_token(
            payload.id_token,
            google_requests.Request(),
            google_client_id,
        )
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Token Google invalido: {e}")

    google_sub = info["sub"]
    email = info.get("email", "").lower().strip()
    nome_google = info.get("name", "")

    user = session.exec(select(User).where(User.google_id == google_sub)).first()
    is_new_user = False

    if not user and email:
        user = session.exec(select(User).where(User.email == email)).first()
        if user:
            user.google_id = google_sub
            session.add(user)
            session.commit()
            session.refresh(user)

    if not user:
        is_new_user = True
        user = User(
            email=email,
            password_hash=None,
            google_id=google_sub,
            nome=nome_google or email.split("@")[0],
        )
        session.add(user)
        session.commit()
        session.refresh(user)

    if not user.ativo:
        raise HTTPException(status_code=403, detail="Conta desativada")

    return GoogleTokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        user=UserRead.from_user(user),
        is_new_user=is_new_user,
    )


@app.patch("/api/auth/me", response_model=UserRead)
def atualizar_perfil(
    payload: UpdateProfileRequest,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Atualiza nome e/ou telefone do usuário autenticado."""
    if payload.nome is not None:
        current_user.nome = payload.nome.strip()
    if payload.telefone is not None:
        current_user.telefone = payload.telefone.strip() or None
    current_user.updated_at = datetime.utcnow()
    session.add(current_user)
    session.commit()
    session.refresh(current_user)
    return UserRead.from_user(current_user)


# ─── Helpers de ownership ────────────────────────────────────────────────────

def _verify_obra_ownership(obra_id: UUID, user: User, session: Session) -> Obra:
    """Verifica que a obra existe e pertence ao usuário. Retorna a Obra."""
    obra = session.get(Obra, obra_id)
    if not obra or (obra.user_id is not None and obra.user_id != user.id):
        raise HTTPException(status_code=404, detail="Obra nao encontrada")
    return obra


def _verify_obra_access(obra_id: UUID, user: User, session: Session) -> tuple[Obra, str]:
    """Verifica acesso à obra (dono ou convidado). Retorna (Obra, role)."""
    obra = session.get(Obra, obra_id)
    if not obra:
        raise HTTPException(status_code=404, detail="Obra nao encontrada")
    if obra.user_id == user.id:
        return obra, "dono"
    convite = session.exec(
        select(ObraConvite).where(
            ObraConvite.obra_id == obra_id,
            ObraConvite.convidado_id == user.id,
            ObraConvite.status == "aceito",
        )
    ).first()
    if convite:
        return obra, "convidado"
    raise HTTPException(status_code=404, detail="Obra nao encontrada")


def _verify_etapa_ownership(etapa_id: UUID, user: User, session: Session) -> Etapa:
    """Verifica que a etapa existe e sua obra pertence ao usuário."""
    etapa = session.get(Etapa, etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")
    _verify_obra_ownership(etapa.obra_id, user, session)
    return etapa


def _verify_etapa_access(etapa_id: UUID, user: User, session: Session) -> tuple[Etapa, str]:
    """Verifica acesso à etapa (dono ou convidado). Retorna (Etapa, role)."""
    etapa = session.get(Etapa, etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")
    _, role = _verify_obra_access(etapa.obra_id, user, session)
    return etapa, role


def _notificar_dono_atualizacao(session: Session, obra_id: UUID, nome_convidado: str) -> None:
    """Envia push notification ao dono da obra quando convidado faz atualização."""
    try:
        obra = session.get(Obra, obra_id)
        if not obra or not obra.user_id:
            return
        tokens = session.exec(
            select(DeviceToken).where(DeviceToken.obra_id == obra_id)
        ).all()
        if tokens:
            enviar_push_multiplos(
                tokens=[t.token for t in tokens],
                titulo="Obra atualizada",
                corpo=f"O andamento da sua obra foi atualizado por {nome_convidado}",
            )
    except Exception as exc:
        logger.warning("Falha ao enviar push de atualização: %s", exc)


# ─── Obras ───────────────────────────────────────────────────────────────────

@app.post("/api/obras", response_model=ObraRead)
def criar_obra(payload: ObraCreate, session: Session = Depends(get_session), current_user: User = Depends(get_current_user)) -> Obra:
    check_obra_limit(session, current_user)
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
    from sqlalchemy import func as sa_func

    obra = _verify_obra_ownership(obra_id, current_user, session)
    etapas = session.exec(select(Etapa).where(Etapa.obra_id == obra_id).order_by(Etapa.ordem)).all()

    etapas_enriched = []
    for etapa in etapas:
        etapa_dict = etapa.model_dump()

        orcamento = session.exec(
            select(OrcamentoEtapa).where(OrcamentoEtapa.etapa_id == etapa.id)
        ).first()
        etapa_dict["valor_previsto"] = orcamento.valor_previsto if orcamento else None

        total_gasto = session.exec(
            select(sa_func.coalesce(sa_func.sum(Despesa.valor), 0))
            .where(Despesa.etapa_id == etapa.id)
        ).one()
        etapa_dict["valor_gasto"] = float(total_gasto)

        etapas_enriched.append(etapa_dict)

    return {"obra": obra, "etapas": etapas_enriched}


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
    _verify_etapa_access(etapa_id, current_user, session)
    return session.exec(select(ChecklistItem).where(ChecklistItem.etapa_id == etapa_id)).all()


@app.post("/api/etapas/{etapa_id}/checklist-items", response_model=ChecklistItemRead)
def criar_item(
    etapa_id: UUID,
    payload: ChecklistItemCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> ChecklistItem:
    etapa, role = _verify_etapa_access(etapa_id, current_user, session)
    # Free users não podem criar itens; convidados podem
    if role == "dono" and not get_plan_config(current_user).get("can_create_checklist_items"):
        raise HTTPException(status_code=403, detail="Recurso disponível apenas para assinantes")
    item = ChecklistItem(etapa_id=etapa_id, **payload.model_dump(mode="json"))
    session.add(item)
    session.commit()
    session.refresh(item)
    # Notificar dono se quem criou é convidado
    if role == "convidado":
        _notificar_dono_atualizacao(session, etapa.obra_id, current_user.nome)
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
    etapa, role = _verify_etapa_access(item.etapa_id, current_user, session)
    updates = payload.model_dump(exclude_unset=True, mode="json")
    for key, value in updates.items():
        setattr(item, key, value)
    item.updated_at = datetime.utcnow()
    session.add(item)
    session.commit()
    session.refresh(item)
    if role == "convidado":
        _notificar_dono_atualizacao(session, etapa.obra_id, current_user.nome)
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
    _verify_etapa_access(item.etapa_id, current_user, session)
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
    etapa, role = _verify_etapa_access(item.etapa_id, current_user, session)
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
    if role == "convidado":
        _notificar_dono_atualizacao(session, etapa.obra_id, current_user.nome)
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

    # Truncar resultados para plano gratuito
    normas_read = [NormaResultadoRead.model_validate(nr) for nr in normas_db]
    config = get_plan_config(current_user)
    normas_limit = config.get("normas_results_limit")
    total_normas = len(normas_read)
    if normas_limit is not None:
        normas_read = normas_read[:normas_limit]

    return NormaBuscarResponse(
        log_id=norma_log.id,
        etapa_nome=payload.etapa_nome,
        resumo_geral=resultado.get("resumo_geral", ""),
        aviso_legal=resultado.get(
            "aviso_legal",
            "Este resultado é informativo e NÃO substitui parecer técnico de profissional habilitado.",
        ),
        data_consulta=resultado.get("data_consulta", datetime.utcnow().isoformat()),
        normas=normas_read,
        checklist_dinamico=resultado.get("checklist_dinamico", []),
        total_normas=total_normas,
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
    """Registra ou atualiza o orçamento previsto e realizado por etapa (upsert)."""
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
            existing.valor_realizado = item.valor_realizado
            existing.updated_at = datetime.utcnow()
            session.add(existing)
            resultado.append(existing)
        else:
            orcamento = OrcamentoEtapa(
                obra_id=obra_id,
                etapa_id=item.etapa_id,
                valor_previsto=item.valor_previsto,
                valor_realizado=item.valor_realizado,
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
    realizado_por_etapa = {str(o.etapa_id): o.valor_realizado for o in orcamentos if o.valor_realizado is not None}
    gasto_por_etapa: dict[str, float] = {}
    for d in despesas:
        key = str(d.etapa_id) if d.etapa_id else "__sem_etapa__"
        gasto_por_etapa[key] = gasto_por_etapa.get(key, 0.0) + d.valor

    por_etapa: list[EtapaFinanceiroItem] = []
    for etapa in etapas:
        previsto = orcamento_por_etapa.get(str(etapa.id), 0.0)
        gasto = realizado_por_etapa.get(str(etapa.id), gasto_por_etapa.get(str(etapa.id), 0.0))
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
    config = get_plan_config(current_user)
    # Gate: limite de uploads
    if config["max_doc_uploads"] is not None:
        doc_count = len(session.exec(
            select(ProjetoDoc).where(ProjetoDoc.obra_id == obra_id)
        ).all())
        if doc_count >= config["max_doc_uploads"]:
            raise HTTPException(status_code=403, detail="Limite de documentos atingido para seu plano")
    # Gate: limite de tamanho
    if config["max_doc_size_mb"] is not None:
        file.file.seek(0, os.SEEK_END)
        size_mb = file.file.tell() / (1024 * 1024)
        file.file.seek(0)
        if size_mb > config["max_doc_size_mb"]:
            raise HTTPException(
                status_code=403,
                detail=f"Arquivo excede o limite de {config['max_doc_size_mb']}MB para seu plano",
            )
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


@app.get("/api/projetos/{projeto_id}/pdf")
def download_projeto_pdf(
    projeto_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Serve o PDF do projeto via proxy (resolve CORS com storage)."""
    projeto = session.get(ProjetoDoc, projeto_id)
    if not projeto:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise HTTPException(status_code=500, detail="S3_BUCKET nao configurado")
    object_key = extract_object_key(projeto.arquivo_url, bucket)
    pdf_bytes = download_by_url(projeto.arquivo_url, bucket, object_key)
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'inline; filename="{projeto.arquivo_nome}"'},
    )


@app.delete("/api/projetos/{projeto_id}")
def deletar_projeto(
    projeto_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Remove um projeto PDF e seus riscos associados."""
    if not get_plan_config(current_user).get("can_delete_doc"):
        raise HTTPException(status_code=403, detail="Exclusão de documentos disponível apenas para assinantes")
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
            dado_projeto = risco_data.get("dado_projeto")
            verificacoes = risco_data.get("verificacoes")
            pergunta_eng = risco_data.get("pergunta_engenheiro")
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
                dado_projeto=json.dumps(dado_projeto, ensure_ascii=False) if dado_projeto else None,
                verificacoes=json.dumps(verificacoes, ensure_ascii=False) if verificacoes else None,
                pergunta_engenheiro=json.dumps(pergunta_eng, ensure_ascii=False) if pergunta_eng else None,
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


# ─── Riscos → Checklist ─────────────────────────────────────────────────────

# Mapeamento de palavras-chave em riscos para etapas sugeridas
_RISCO_ETAPA_KEYWORDS: dict[str, list[str]] = {
    "fundação": ["Fundacoes e Estrutura"],
    "fundacao": ["Fundacoes e Estrutura"],
    "estrutura": ["Fundacoes e Estrutura"],
    "concreto": ["Fundacoes e Estrutura"],
    "ferragem": ["Fundacoes e Estrutura"],
    "armadura": ["Fundacoes e Estrutura"],
    "estaca": ["Fundacoes e Estrutura"],
    "sapata": ["Fundacoes e Estrutura"],
    "terreno": ["Preparacao do Terreno"],
    "terraplanagem": ["Preparacao do Terreno"],
    "topografia": ["Preparacao do Terreno"],
    "sondagem": ["Preparacao do Terreno"],
    "demolição": ["Preparacao do Terreno"],
    "demolicao": ["Preparacao do Terreno"],
    "alvenaria": ["Alvenaria e Cobertura"],
    "cobertura": ["Alvenaria e Cobertura"],
    "telhado": ["Alvenaria e Cobertura"],
    "laje": ["Alvenaria e Cobertura"],
    "impermeabilização": ["Alvenaria e Cobertura"],
    "impermeabilizacao": ["Alvenaria e Cobertura"],
    "elétric": ["Instalacoes e Acabamentos"],
    "eletric": ["Instalacoes e Acabamentos"],
    "hidráulic": ["Instalacoes e Acabamentos"],
    "hidraulic": ["Instalacoes e Acabamentos"],
    "acabamento": ["Instalacoes e Acabamentos"],
    "revestimento": ["Instalacoes e Acabamentos"],
    "pintura": ["Instalacoes e Acabamentos"],
    "piso": ["Instalacoes e Acabamentos"],
    "entrega": ["Entrega e Pos-obra"],
    "habite-se": ["Entrega e Pos-obra"],
    "vistoria": ["Entrega e Pos-obra"],
    "garantia": ["Entrega e Pos-obra"],
    "projeto": ["Planejamento e Projeto"],
    "licença": ["Planejamento e Projeto"],
    "licenca": ["Planejamento e Projeto"],
    "alvará": ["Planejamento e Projeto"],
    "alvara": ["Planejamento e Projeto"],
}


@app.get("/api/obras/{obra_id}/riscos-pendentes")
def listar_riscos_pendentes(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Retorna riscos de documentos analisados que ainda nao viraram checklist items."""
    docs = session.exec(
        select(ProjetoDoc)
        .where(ProjetoDoc.obra_id == obra_id)
        .where(ProjetoDoc.status == "concluido")
    ).all()

    # Buscar todos os títulos de checklist existentes na obra para comparação
    titulos_existentes: set[str] = set()
    etapas = session.exec(select(Etapa).where(Etapa.obra_id == obra_id)).all()
    etapa_ids = [e.id for e in etapas]
    if etapa_ids:
        items_existentes = session.exec(
            select(ChecklistItem.titulo).where(ChecklistItem.etapa_id.in_(etapa_ids))  # type: ignore[attr-defined]
        ).all()
        titulos_existentes = {t for t in items_existentes}

    riscos_pendentes = []
    for doc in docs:
        riscos = session.exec(
            select(Risco).where(Risco.projeto_id == doc.id)
        ).all()
        for risco in riscos:
            if risco.descricao in titulos_existentes:
                continue
            riscos_pendentes.append({
                "id": str(risco.id),
                "descricao": risco.descricao,
                "severidade": risco.severidade,
                "norma_referencia": risco.norma_referencia,
                "traducao_leigo": risco.traducao_leigo,
                "documento_nome": doc.arquivo_nome,
            })

    return {"riscos": riscos_pendentes, "total": len(riscos_pendentes)}


@app.post("/api/obras/{obra_id}/aplicar-riscos")
def aplicar_riscos(
    obra_id: UUID,
    body: dict,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Converte riscos selecionados em ChecklistItems nas etapas adequadas."""
    risco_ids = body.get("risco_ids", [])
    if not risco_ids:
        return {"criados": 0}

    etapas = session.exec(select(Etapa).where(Etapa.obra_id == obra_id)).all()
    if not etapas:
        raise HTTPException(status_code=400, detail="Obra sem etapas")

    etapa_map = {e.nome: e for e in etapas}
    etapa_fallback = etapa_map.get("Instalacoes e Acabamentos") or etapas[-1]

    criados = 0
    for rid in risco_ids:
        risco = session.get(Risco, UUID(rid))
        if not risco:
            continue

        etapa_alvo = etapa_fallback
        desc_lower = risco.descricao.lower()
        for keyword, etapa_nomes in _RISCO_ETAPA_KEYWORDS.items():
            if keyword in desc_lower:
                for nome in etapa_nomes:
                    if nome in etapa_map:
                        etapa_alvo = etapa_map[nome]
                        break
                break

        item = ChecklistItem(
            etapa_id=etapa_alvo.id,
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
            requer_validacao_profissional=risco.requer_validacao_profissional,
        )
        session.add(item)
        criados += 1

    session.commit()
    return {"criados": criados}


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
    config = get_plan_config(current_user)
    check_and_increment_usage(
        session, current_user.id, "ai_visual", config["ai_visual_monthly_limit"]
    )

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

    # Gate: limitar quantidade e ocultar contato para plano gratuito
    config = get_plan_config(current_user)
    if config["prestadores_limit"] is not None:
        resultado = resultado[:config["prestadores_limit"]]
    if not config["prestadores_show_contact"]:
        for r in resultado:
            r.telefone = None
            r.email = None
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
    config = get_plan_config(current_user)
    # Para checklist inteligente, o limite é lifetime (sem período mensal)
    check_and_increment_usage(
        session, current_user.id, "checklist_inteligente",
        config["checklist_inteligente_lifetime_limit"],
        period="lifetime",
    )

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


# ─── Monetização — Subscription ──────────────────────────────────────────────

@app.get("/api/subscription/me", response_model=SubscriptionInfoResponse)
def get_subscription_info(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Retorna plano atual, configuração de limites e uso do mês."""
    config = get_plan_config(current_user)
    period = datetime.utcnow().strftime("%Y-%m")

    usages = session.exec(
        select(UsageTracking).where(
            UsageTracking.user_id == current_user.id,
            UsageTracking.period.in_([period, "lifetime"]),
        )
    ).all()
    usage_map = {u.feature: u.count for u in usages}

    obra_count = len(session.exec(
        select(Obra).where(Obra.user_id == current_user.id)
    ).all())

    doc_count = 0
    obras = session.exec(select(Obra).where(Obra.user_id == current_user.id)).all()
    for obra in obras:
        doc_count += len(session.exec(
            select(ProjetoDoc).where(ProjetoDoc.obra_id == obra.id)
        ).all())

    convite_count = 0
    for obra in obras:
        convite_count += len(session.exec(
            select(ObraConvite).where(
                ObraConvite.obra_id == obra.id,
                ObraConvite.status.in_(["pendente", "aceito"]),
            )
        ).all())

    subscription = session.exec(
        select(Subscription).where(Subscription.user_id == current_user.id)
    ).first()

    return SubscriptionInfoResponse(
        plan=current_user.plan,
        plan_config=config,
        usage=usage_map,
        obra_count=obra_count,
        doc_count=doc_count,
        convite_count=convite_count,
        expires_at=subscription.expires_at if subscription else None,
        status=subscription.status if subscription else "active",
    )


@app.post("/api/subscription/create-checkout")
def create_checkout_session(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Cria uma sessão Stripe Checkout para assinatura Dono da Obra."""
    import stripe

    stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="STRIPE_SECRET_KEY não configurado")

    price_id = os.getenv("STRIPE_PRICE_ID")
    if not price_id:
        raise HTTPException(status_code=500, detail="STRIPE_PRICE_ID não configurado")

    # Check if user already has a Stripe customer ID
    sub = session.exec(
        select(Subscription).where(Subscription.user_id == current_user.id)
    ).first()

    checkout_params = {
        "mode": "subscription",
        "line_items": [{"price": price_id, "quantity": 1}],
        "success_url": os.getenv("STRIPE_SUCCESS_URL", "https://mestreobra-backend-530484413221.us-central1.run.app/api/subscription/success?session_id={CHECKOUT_SESSION_ID}"),
        "cancel_url": os.getenv("STRIPE_CANCEL_URL", "https://mestreobra-backend-530484413221.us-central1.run.app/api/subscription/cancel"),
        "client_reference_id": str(current_user.id),
        "metadata": {"user_id": str(current_user.id)},
    }

    if sub and sub.revenuecat_customer_id:
        # revenuecat_customer_id agora guarda stripe_customer_id
        checkout_params["customer"] = sub.revenuecat_customer_id
    else:
        checkout_params["customer_email"] = current_user.email

    try:
        checkout_session = stripe.checkout.Session.create(**checkout_params)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Erro Stripe: {exc}")

    return {"checkout_url": checkout_session.url, "session_id": checkout_session.id}


@app.get("/api/subscription/success")
def subscription_success(session_id: str):
    """Redirect page after successful Stripe Checkout."""
    html = """
    <html><head><meta charset='utf-8'><title>Assinatura confirmada</title></head>
    <body style='display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;background:#f0f4f8'>
    <div style='text-align:center;padding:40px;background:white;border-radius:16px;box-shadow:0 4px 12px rgba(0,0,0,0.1)'>
    <h1 style='color:#4f46e5'>Assinatura confirmada!</h1>
    <p style='font-size:18px;color:#555'>Volte ao app Mestre da Obra para aproveitar todos os recursos.</p>
    <p style='margin-top:20px;font-size:14px;color:#999'>Você pode fechar esta janela.</p>
    </div></body></html>
    """
    from fastapi.responses import HTMLResponse
    return HTMLResponse(content=html)


@app.get("/api/subscription/cancel")
def subscription_cancel():
    """Redirect page after cancelled Stripe Checkout."""
    from fastapi.responses import HTMLResponse
    html = """
    <html><head><meta charset='utf-8'><title>Assinatura cancelada</title></head>
    <body style='display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;background:#f0f4f8'>
    <div style='text-align:center;padding:40px;background:white;border-radius:16px;box-shadow:0 4px 12px rgba(0,0,0,0.1)'>
    <h1 style='color:#666'>Assinatura não concluída</h1>
    <p style='font-size:18px;color:#555'>Volte ao app e tente novamente quando quiser.</p>
    </div></body></html>
    """
    return HTMLResponse(content=html)


@app.post("/api/subscription/sync")
def sync_subscription(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Consulta Stripe para verificar status da assinatura."""
    import stripe

    stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="STRIPE_SECRET_KEY não configurado")

    sub = session.exec(
        select(Subscription).where(Subscription.user_id == current_user.id)
    ).first()

    if not sub or not sub.revenuecat_customer_id:
        return {"plan": current_user.plan}

    try:
        # revenuecat_customer_id stores stripe_customer_id
        subscriptions = stripe.Subscription.list(
            customer=sub.revenuecat_customer_id,
            status="active",
            limit=1,
        )
        if subscriptions.data:
            stripe_sub = subscriptions.data[0]
            current_user.plan = "dono_da_obra"
            sub.plan = "dono_da_obra"
            sub.status = "active"
            sub.expires_at = datetime.utcfromtimestamp(stripe_sub.current_period_end)
        else:
            current_user.plan = "gratuito"
            sub.plan = "gratuito"
            sub.status = "expired"
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Erro Stripe: {exc}")

    current_user.updated_at = datetime.utcnow()
    sub.updated_at = datetime.utcnow()
    session.add(current_user)
    session.commit()

    return {"plan": current_user.plan}


@app.post("/api/subscription/cancel-subscription")
def cancel_subscription(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Cancela a assinatura do usuário no final do período atual."""
    import stripe

    stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="STRIPE_SECRET_KEY não configurado")

    sub = session.exec(
        select(Subscription).where(Subscription.user_id == current_user.id)
    ).first()

    if not sub or sub.status != "active" or not sub.product_id:
        raise HTTPException(status_code=400, detail="Nenhuma assinatura ativa encontrada")

    try:
        stripe.Subscription.modify(sub.product_id, cancel_at_period_end=True)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Erro Stripe: {exc}")

    sub.status = "cancelled"
    sub.updated_at = datetime.utcnow()
    session.add(sub)
    session.commit()

    return {
        "message": "Assinatura cancelada. Acesso mantido até o final do período.",
        "expires_at": sub.expires_at.isoformat() if sub.expires_at else None,
    }


@app.delete("/api/auth/me")
def delete_account(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Exclui a conta do usuário: anonimiza dados pessoais, mantém dados de obra."""
    import stripe

    # 1. Cancel Stripe subscription if active
    sub = session.exec(
        select(Subscription).where(Subscription.user_id == current_user.id)
    ).first()

    if sub and sub.status == "active" and sub.product_id:
        stripe_key = os.getenv("STRIPE_SECRET_KEY")
        if stripe_key:
            stripe.api_key = stripe_key
            try:
                stripe.Subscription.modify(sub.product_id, cancel_at_period_end=True)
            except Exception:
                pass  # Best effort — don't block deletion
        sub.status = "cancelled"
        sub.updated_at = datetime.utcnow()
        session.add(sub)

    # 2. Anonymize user data
    current_user.nome = "Usuário removido"
    current_user.email = f"{current_user.id}@deleted.local"
    current_user.telefone = None
    current_user.google_id = None
    current_user.password_hash = None
    current_user.ativo = False
    current_user.plan = "gratuito"
    current_user.updated_at = datetime.utcnow()
    session.add(current_user)

    # 3. Cancel pending invites where user is owner
    pending_convites = session.exec(
        select(ObraConvite).where(
            ObraConvite.dono_id == current_user.id,
            ObraConvite.status == "pendente",
        )
    ).all()
    for convite in pending_convites:
        convite.status = "removido"
        session.add(convite)

    session.commit()
    return {"message": "Conta excluída com sucesso"}


@app.post("/api/webhooks/stripe")
async def stripe_webhook(
    request: Request,
    session: Session = Depends(get_session),
):
    """Webhook handler para eventos do Stripe."""
    import stripe

    stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
    webhook_secret = os.getenv("STRIPE_WEBHOOK_SECRET")

    payload = await request.body()
    sig_header = request.headers.get("stripe-signature", "")

    try:
        event = stripe.Webhook.construct_event(payload, sig_header, webhook_secret)
    except (ValueError, stripe.error.SignatureVerificationError):
        raise HTTPException(status_code=400, detail="Assinatura do webhook inválida")

    event_type = event["type"]
    data_object = event["data"]["object"]

    # Log do evento
    rc_event = RevenueCatEvent(
        event_type=event_type,
        app_user_id=data_object.get("client_reference_id", data_object.get("customer", "")),
        product_id=data_object.get("id", ""),
        store="stripe",
        event_timestamp=datetime.utcnow(),
        raw_payload=json.dumps(event, default=str),
    )
    session.add(rc_event)

    if event_type == "checkout.session.completed":
        user_id = data_object.get("client_reference_id")
        customer_id = data_object.get("customer")
        stripe_sub_id = data_object.get("subscription")

        if user_id:
            try:
                user = session.get(User, UUID(user_id))
            except (ValueError, TypeError):
                user = None

            if user:
                user.plan = "dono_da_obra"
                user.updated_at = datetime.utcnow()
                session.add(user)

                sub = session.exec(
                    select(Subscription).where(Subscription.user_id == user.id)
                ).first()
                if not sub:
                    sub = Subscription(user_id=user.id)
                    session.add(sub)

                sub.plan = "dono_da_obra"
                sub.status = "active"
                sub.revenuecat_customer_id = customer_id  # stores stripe customer_id
                sub.store = "stripe"
                sub.product_id = stripe_sub_id
                sub.original_purchase_date = datetime.utcnow()
                sub.updated_at = datetime.utcnow()

                # Fetch subscription details for expiry
                if stripe_sub_id:
                    try:
                        stripe_sub = stripe.Subscription.retrieve(stripe_sub_id)
                        sub.expires_at = datetime.utcfromtimestamp(stripe_sub.current_period_end)
                    except Exception:
                        pass

                rc_event.processed = True

    elif event_type in ("customer.subscription.updated", "customer.subscription.created"):
        customer_id = data_object.get("customer")
        status_val = data_object.get("status")

        sub = session.exec(
            select(Subscription).where(Subscription.revenuecat_customer_id == customer_id)
        ).first()

        if sub:
            user = session.get(User, sub.user_id)
            if status_val == "active":
                sub.status = "active"
                sub.plan = "dono_da_obra"
                sub.expires_at = datetime.utcfromtimestamp(data_object.get("current_period_end", 0))
                if user:
                    user.plan = "dono_da_obra"
                    user.updated_at = datetime.utcnow()
                    session.add(user)
            elif status_val == "past_due":
                sub.status = "grace_period"
            elif status_val in ("canceled", "unpaid"):
                sub.status = "cancelled"
            sub.updated_at = datetime.utcnow()
            rc_event.processed = True

    elif event_type == "customer.subscription.deleted":
        customer_id = data_object.get("customer")
        sub = session.exec(
            select(Subscription).where(Subscription.revenuecat_customer_id == customer_id)
        ).first()
        if sub:
            user = session.get(User, sub.user_id)
            sub.status = "expired"
            sub.plan = "gratuito"
            sub.updated_at = datetime.utcnow()
            if user:
                user.plan = "gratuito"
                user.updated_at = datetime.utcnow()
                session.add(user)
                _revogar_convites_por_expiracao(session, user.id)
            rc_event.processed = True

    elif event_type == "invoice.payment_failed":
        customer_id = data_object.get("customer")
        sub = session.exec(
            select(Subscription).where(Subscription.revenuecat_customer_id == customer_id)
        ).first()
        if sub:
            sub.status = "grace_period"
            sub.updated_at = datetime.utcnow()
            rc_event.processed = True

    session.commit()
    return {"ok": True}


def _revogar_convites_por_expiracao(session: Session, user_id: UUID) -> None:
    """Remove convites ativos quando dono perde assinatura."""
    obras = session.exec(select(Obra).where(Obra.user_id == user_id)).all()
    for obra in obras:
        convites = session.exec(
            select(ObraConvite).where(
                ObraConvite.obra_id == obra.id,
                ObraConvite.status.in_(["pendente", "aceito"]),
            )
        ).all()
        for c in convites:
            c.status = "removido"
            c.accepted_at = None
            session.add(c)


# ─── Monetização — Convites ──────────────────────────────────────────────────

@app.post("/api/obras/{obra_id}/convites", response_model=ConviteRead)
def criar_convite(
    obra_id: UUID,
    payload: ConviteCreateRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Dono cria convite para profissional acessar a obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    check_convite_limit(session, current_user, obra_id)

    # Verificar se já existe convite ativo para este e-mail nesta obra
    existing = session.exec(
        select(ObraConvite).where(
            ObraConvite.obra_id == obra_id,
            ObraConvite.email == payload.email.lower().strip(),
            ObraConvite.status.in_(["pendente", "aceito"]),
        )
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail="Já existe um convite ativo para este e-mail")

    import secrets
    from datetime import timedelta
    token = secrets.token_urlsafe(32)

    convite = ObraConvite(
        obra_id=obra_id,
        dono_id=current_user.id,
        email=payload.email.lower().strip(),
        papel=payload.papel,
        token=token,
        token_expires_at=datetime.utcnow() + timedelta(days=7),
    )
    session.add(convite)
    session.commit()
    session.refresh(convite)

    # Enviar e-mail com magic link
    email_enviado = enviar_email_convite(
        destinatario=convite.email,
        obra_nome=obra.nome,
        dono_nome=current_user.nome,
        papel=convite.papel,
        token=token,
    )
    if not email_enviado:
        logger.error("Falha ao enviar email de convite para %s", convite.email)

    return ConviteRead(
        id=convite.id,
        obra_id=convite.obra_id,
        email=convite.email,
        papel=convite.papel,
        status=convite.status,
        created_at=convite.created_at,
        accepted_at=convite.accepted_at,
    )


@app.get("/api/obras/{obra_id}/convites", response_model=List[ConviteRead])
def listar_convites(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Dono lista convites de uma obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    convites = session.exec(
        select(ObraConvite).where(
            ObraConvite.obra_id == obra_id,
            ObraConvite.status.in_(["pendente", "aceito"]),
        ).order_by(ObraConvite.created_at.desc())
    ).all()

    result = []
    for c in convites:
        convidado_nome = None
        if c.convidado_id:
            convidado = session.get(User, c.convidado_id)
            convidado_nome = convidado.nome if convidado else None
        result.append(ConviteRead(
            id=c.id,
            obra_id=c.obra_id,
            email=c.email,
            papel=c.papel,
            status=c.status,
            convidado_nome=convidado_nome,
            created_at=c.created_at,
            accepted_at=c.accepted_at,
        ))
    return result


@app.delete("/api/convites/{convite_id}")
def remover_convite(
    convite_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Dono remove convidado (acesso revogado instantaneamente)."""
    convite = session.get(ObraConvite, convite_id)
    if not convite:
        raise HTTPException(status_code=404, detail="Convite não encontrado")
    if convite.dono_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acesso negado")

    convite.status = "removido"
    session.add(convite)
    session.commit()
    return {"ok": True}


@app.post("/api/convites/aceitar")
def aceitar_convite(
    payload: ConviteAceitarRequest,
    session: Session = Depends(get_session),
):
    """Convidado aceita convite via token do magic link. Cria conta se não existe."""
    convite = session.exec(
        select(ObraConvite).where(
            ObraConvite.token == payload.token,
            ObraConvite.status == "pendente",
        )
    ).first()
    if not convite:
        raise HTTPException(status_code=404, detail="Convite não encontrado ou já utilizado")

    if convite.token_expires_at < datetime.utcnow():
        raise HTTPException(status_code=410, detail="Link expirado. Solicite um novo convite ao proprietário.")

    # Buscar ou criar conta do convidado
    user = session.exec(
        select(User).where(User.email == convite.email)
    ).first()

    if not user:
        # Criar conta simplificada (sem senha, role convidado)
        user = User(
            email=convite.email,
            nome=payload.nome,
            role="convidado",
            plan="gratuito",
        )
        session.add(user)
        session.commit()
        session.refresh(user)

    convite.convidado_id = user.id
    convite.status = "aceito"
    convite.accepted_at = datetime.utcnow()
    session.add(convite)
    session.commit()

    return {
        "access_token": create_access_token(str(user.id)),
        "refresh_token": create_refresh_token(str(user.id)),
        "user": UserRead.from_user(user).model_dump(),
        "obra_id": str(convite.obra_id),
    }


@app.get("/api/convites/minhas-obras", response_model=List[ObraConvidadaRead])
def listar_obras_convidadas(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Convidado lista obras onde foi convidado."""
    convites = session.exec(
        select(ObraConvite).where(
            ObraConvite.convidado_id == current_user.id,
            ObraConvite.status == "aceito",
        )
    ).all()

    result = []
    for c in convites:
        obra = session.get(Obra, c.obra_id)
        dono = session.get(User, c.dono_id)
        if obra:
            result.append(ObraConvidadaRead(
                obra_id=obra.id,
                obra_nome=obra.nome,
                dono_nome=dono.nome if dono else "",
                papel=c.papel,
                convite_id=c.id,
            ))
    return result


# ─── Comentários em Etapas ───────────────────────────────────────────────────

@app.post("/api/etapas/{etapa_id}/comentarios", response_model=ComentarioRead)
def criar_comentario(
    etapa_id: UUID,
    payload: ComentarioCreateRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Dono ou convidado cria comentário em uma etapa."""
    etapa, role = _verify_etapa_access(etapa_id, current_user, session)

    # Free users não podem comentar
    if role == "dono" and not get_plan_config(current_user).get("can_create_comentarios"):
        raise HTTPException(status_code=403, detail="Comentários disponíveis apenas para assinantes")

    comentario = EtapaComentario(
        etapa_id=etapa_id,
        user_id=current_user.id,
        texto=payload.texto,
    )
    session.add(comentario)
    session.commit()
    session.refresh(comentario)

    if role == "convidado":
        _notificar_dono_atualizacao(session, etapa.obra_id, current_user.nome)

    return ComentarioRead(
        id=comentario.id,
        etapa_id=comentario.etapa_id,
        user_id=comentario.user_id,
        user_nome=current_user.nome,
        texto=comentario.texto,
        created_at=comentario.created_at,
    )


@app.get("/api/etapas/{etapa_id}/comentarios", response_model=List[ComentarioRead])
def listar_comentarios(
    etapa_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Lista comentários de uma etapa."""
    _verify_etapa_access(etapa_id, current_user, session)

    comentarios = session.exec(
        select(EtapaComentario)
        .where(EtapaComentario.etapa_id == etapa_id)
        .order_by(EtapaComentario.created_at.desc())
    ).all()

    result = []
    for c in comentarios:
        user = session.get(User, c.user_id)
        result.append(ComentarioRead(
            id=c.id,
            etapa_id=c.etapa_id,
            user_id=c.user_id,
            user_nome=user.nome if user else "",
            texto=c.texto,
            created_at=c.created_at,
        ))
    return result


# ─── Fase 3 — IA Enriquece Checklist Padrão ─────────────────────────────────

@app.post("/api/checklist-items/{item_id}/enriquecer", response_model=ChecklistItemRead)
def enriquecer_item(
    item_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_paid),
):
    """Enriquece um item de checklist padrão com análise IA (3 blocos)."""
    item = session.get(ChecklistItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item nao encontrado")

    etapa = session.get(Etapa, item.etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")

    _verify_obra_access(etapa.obra_id, current_user, session)

    # Buscar contexto dos docs analisados da obra
    docs = session.exec(
        select(ProjetoDoc).where(ProjetoDoc.obra_id == etapa.obra_id)
    ).all()
    doc_parts = []
    for d in docs:
        if d.resumo_geral:
            doc_parts.append(f"[{d.arquivo_nome}] {d.resumo_geral}")
        # Include risks identified in this document
        riscos = session.exec(
            select(Risco).where(Risco.projeto_id == d.id)
        ).all()
        for r in riscos:
            doc_parts.append(f"  Risco ({r.severidade}): {r.descricao}")
    contexto = "\n".join(doc_parts)

    enrichment = enriquecer_item_unico(
        titulo=item.titulo,
        descricao=item.descricao or "",
        etapa_nome=etapa.nome,
        contexto_docs=contexto,
    )

    # Atualizar campos escalares
    if enrichment.get("severidade"):
        item.severidade = enrichment["severidade"]
    if enrichment.get("traducao_leigo"):
        item.traducao_leigo = enrichment["traducao_leigo"]
    if enrichment.get("norma_referencia"):
        item.norma_referencia = enrichment["norma_referencia"]
    if enrichment.get("confianca") is not None:
        item.confianca = int(enrichment["confianca"])

    # Atualizar campos JSON (3 blocos)
    if enrichment.get("dado_projeto"):
        item.dado_projeto = json.dumps(enrichment["dado_projeto"], ensure_ascii=False)
    if enrichment.get("verificacoes"):
        item.verificacoes = json.dumps(enrichment["verificacoes"], ensure_ascii=False)
    if enrichment.get("pergunta_engenheiro"):
        item.pergunta_engenheiro = json.dumps(enrichment["pergunta_engenheiro"], ensure_ascii=False)
    if enrichment.get("documentos_a_exigir"):
        item.documentos_a_exigir = json.dumps(enrichment["documentos_a_exigir"], ensure_ascii=False)

    item.origem = "ia"
    session.add(item)
    session.commit()
    session.refresh(item)
    return item


@app.post("/api/etapas/{etapa_id}/enriquecer-checklist")
def enriquecer_checklist_etapa(
    etapa_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_paid),
):
    """Enriquece em batch todos os itens padrão de uma etapa com IA."""
    etapa = session.get(Etapa, etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")

    _verify_obra_access(etapa.obra_id, current_user, session)

    # Buscar itens NÃO enriquecidos (sem dado_projeto preenchido)
    items = session.exec(
        select(ChecklistItem)
        .where(ChecklistItem.etapa_id == etapa_id)
        .where(ChecklistItem.dado_projeto.is_(None))
    ).all()

    if not items:
        return {"enriquecidos": 0, "total": 0, "mensagem": "Todos os itens ja foram enriquecidos."}

    # Buscar contexto dos docs
    docs = session.exec(
        select(ProjetoDoc).where(ProjetoDoc.obra_id == etapa.obra_id)
    ).all()
    doc_parts = []
    for d in docs:
        if d.resumo_geral:
            doc_parts.append(f"[{d.arquivo_nome}] {d.resumo_geral}")
        riscos = session.exec(
            select(Risco).where(Risco.projeto_id == d.id)
        ).all()
        for r in riscos:
            doc_parts.append(f"  Risco ({r.severidade}): {r.descricao}")
    contexto = "\n".join(doc_parts)

    count = 0
    for item in items:
        try:
            enrichment = enriquecer_item_unico(
                titulo=item.titulo,
                descricao=item.descricao or "",
                etapa_nome=etapa.nome,
                contexto_docs=contexto,
            )
            if enrichment.get("severidade"):
                item.severidade = enrichment["severidade"]
            if enrichment.get("traducao_leigo"):
                item.traducao_leigo = enrichment["traducao_leigo"]
            if enrichment.get("norma_referencia"):
                item.norma_referencia = enrichment["norma_referencia"]
            if enrichment.get("confianca") is not None:
                item.confianca = int(enrichment["confianca"])
            if enrichment.get("dado_projeto"):
                item.dado_projeto = json.dumps(enrichment["dado_projeto"], ensure_ascii=False)
            if enrichment.get("verificacoes"):
                item.verificacoes = json.dumps(enrichment["verificacoes"], ensure_ascii=False)
            if enrichment.get("pergunta_engenheiro"):
                item.pergunta_engenheiro = json.dumps(enrichment["pergunta_engenheiro"], ensure_ascii=False)
            if enrichment.get("documentos_a_exigir"):
                item.documentos_a_exigir = json.dumps(enrichment["documentos_a_exigir"], ensure_ascii=False)
            item.origem = "ia"
            session.add(item)
            count += 1
        except Exception as e:
            logger.warning(f"Falha ao enriquecer item {item.id}: {e}")

    session.commit()
    return {"enriquecidos": count, "total": len(items)}
