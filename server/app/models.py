from datetime import datetime, date, timezone
from typing import Optional
from uuid import UUID, uuid4

from sqlalchemy import UniqueConstraint
from sqlmodel import Field, SQLModel


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


# ─── Fase 7 — Autenticação ──────────────────────────────────────────────────

class User(SQLModel, table=True):
    """Usuário proprietário da plataforma."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    email: str = Field(unique=True, index=True)
    password_hash: Optional[str] = Field(default=None)
    google_id: Optional[str] = Field(default=None, unique=True, index=True)
    nome: str
    telefone: Optional[str] = None
    role: str = Field(default="owner")  # "owner" | "admin" | "convidado"
    plan: str = Field(default="gratuito")  # "gratuito" | "essencial" | "completo" | "dono_da_obra" (legacy)
    ativo: bool = Field(default=True)
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


# ─── Core ────────────────────────────────────────────────────────────────────

class Obra(SQLModel, table=True):
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    user_id: Optional[UUID] = Field(default=None, index=True, foreign_key="user.id")
    nome: str
    data_inicio: Optional[date] = None
    data_fim: Optional[date] = None
    orcamento: Optional[float] = None
    localizacao: Optional[str] = None
    area_m2: Optional[float] = None
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


class Etapa(SQLModel, table=True):
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    obra_id: UUID = Field(index=True, foreign_key="obra.id")
    nome: str
    ordem: int
    status: str = Field(default="pendente")
    score: Optional[float] = None
    prazo_previsto: Optional[date] = None
    prazo_executado: Optional[date] = None
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


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
    projeto_doc_id: Optional[UUID] = Field(default=None, foreign_key="projetodoc.id")
    projeto_doc_nome: Optional[str] = None
    como_verificar: Optional[str] = None
    medidas_minimas: Optional[str] = None
    explicacao_leigo: Optional[str] = None
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
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


class Evidencia(SQLModel, table=True):
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    checklist_item_id: UUID = Field(index=True, foreign_key="checklistitem.id")
    arquivo_url: str
    arquivo_nome: str
    mime_type: Optional[str] = None
    tamanho_bytes: Optional[int] = None
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


class NormaLog(SQLModel, table=True):
    """Registro auditável de cada consulta normativa realizada."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    user_id: Optional[UUID] = Field(default=None, index=True, foreign_key="user.id")
    etapa_nome: str
    disciplina: Optional[str] = None
    localizacao: Optional[str] = None
    query_texto: str
    data_consulta: datetime = Field(default_factory=_utcnow)
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


class NormaResultado(SQLModel, table=True):
    """Cada norma encontrada numa consulta, com metadados de rastreabilidade."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    norma_log_id: UUID = Field(index=True, foreign_key="normalog.id")
    titulo: str
    fonte_nome: str
    fonte_url: Optional[str] = None
    fonte_tipo: str = Field(default="secundaria")  # "oficial" | "secundaria"
    versao: Optional[str] = None
    data_norma: Optional[str] = None
    trecho_relevante: Optional[str] = None
    traducao_leigo: str
    nivel_confianca: int = Field(default=0)  # 0–100
    risco_nivel: Optional[str] = None        # "alto" | "medio" | "baixo" | None
    requer_validacao_profissional: bool = Field(default=False)
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


# ─── Fase 2 — Governança Financeira ──────────────────────────────────────────

class OrcamentoEtapa(SQLModel, table=True):
    """Orçamento previsto por etapa de uma obra."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    obra_id: UUID = Field(index=True, foreign_key="obra.id")
    etapa_id: UUID = Field(index=True, foreign_key="etapa.id")
    valor_previsto: float
    valor_realizado: Optional[float] = None
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


class Despesa(SQLModel, table=True):
    """Despesa realizada numa obra, opcionalmente vinculada a uma etapa."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    obra_id: UUID = Field(index=True, foreign_key="obra.id")
    etapa_id: Optional[UUID] = Field(default=None, index=True, foreign_key="etapa.id")
    valor: float
    descricao: str
    data: date
    categoria: Optional[str] = None
    comprovante_url: Optional[str] = None
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


class AlertaConfig(SQLModel, table=True):
    """Configuração de alertas de desvio orçamentário por obra."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    obra_id: UUID = Field(index=True, foreign_key="obra.id")
    percentual_desvio_threshold: float = Field(default=10.0)
    notificacao_ativa: bool = Field(default=True)
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


# ─── Fase 3 — Document AI ─────────────────────────────────────────────────────

class ProjetoDoc(SQLModel, table=True):
    """Documento de projeto (PDF) enviado para análise de IA."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    obra_id: UUID = Field(index=True, foreign_key="obra.id")
    arquivo_url: str
    arquivo_nome: str
    status: str = Field(default="pendente")  # pendente | processando | concluido | erro
    resumo_geral: Optional[str] = None
    aviso_legal: Optional[str] = None
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


class Risco(SQLModel, table=True):
    """Risco identificado num documento de projeto pela IA."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    projeto_id: UUID = Field(index=True, foreign_key="projetodoc.id")
    descricao: str                                  # descricao_tecnica
    severidade: str                                 # "ALTA" | "MEDIA" | "BAIXA"
    disciplina: Optional[str] = None                # "Arquitetura" | "Eletrica" | "Hidraulica" | "Estrutural" | "Geral"
    norma_referencia: Optional[str] = None
    norma_url: Optional[str] = None
    traducao_leigo: str                             # traducao_para_leigo
    acao_proprietario: Optional[str] = None         # acao_imediata
    perguntas_para_profissional: Optional[str] = None  # JSON string (legado)
    documentos_a_exigir: Optional[str] = None           # JSON string
    requer_validacao_profissional: bool = Field(default=False)
    confianca: int = Field(default=0)  # 0–100
    # ─── 3 Camadas de Risco ─────────────────────────────────────────────
    dado_projeto: Optional[str] = None            # JSON: dados concretos extraídos do PDF
    verificacoes: Optional[str] = None             # JSON: verificacao_na_obra
    pergunta_engenheiro: Optional[str] = None      # JSON: mensagem_para_o_profissional
    registro_proprietario: Optional[str] = None    # JSON: preenchido pelo usuário (medições, fotos)
    resultado_cruzamento: Optional[str] = None     # JSON: resultado da comparação IA
    status_verificacao: str = Field(default="pendente")  # "pendente" | "conforme" | "divergente" | "duvida"
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


# ─── Push Notifications ───────────────────────────────────────────────────────

class DeviceToken(SQLModel, table=True):
    """Token FCM de um dispositivo registrado para receber alertas de uma obra."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    obra_id: UUID = Field(index=True, foreign_key="obra.id")
    token: str = Field(index=True)
    platform: str = Field(default="android")  # "android" | "ios"
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


# ─── Fase 4 — Visual AI ───────────────────────────────────────────────────────

class AnaliseVisual(SQLModel, table=True):
    """Análise visual de uma foto da obra por IA."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    etapa_id: UUID = Field(index=True, foreign_key="etapa.id")
    imagem_url: str
    imagem_nome: str
    etapa_inferida: Optional[str] = None    # etapa identificada pela IA na foto
    confianca: int = Field(default=0)       # 0–100, confiança na classificação
    status: str = Field(default="processando")  # processando | concluida | erro
    resumo_geral: Optional[str] = None
    aviso_legal: Optional[str] = None
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


class Achado(SQLModel, table=True):
    """Achado (finding) identificado numa análise visual pela IA."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    analise_id: UUID = Field(index=True, foreign_key="analisevisual.id")
    descricao: str
    severidade: str  # "alto" | "medio" | "baixo"
    acao_recomendada: str
    requer_evidencia_adicional: bool = Field(default=False)
    requer_validacao_profissional: bool = Field(default=False)
    confianca: int = Field(default=0)  # 0–100
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


# ─── Fase 5 — Prestadores e Fornecedores ─────────────────────────────────────

class Prestador(SQLModel, table=True):
    """Prestador de serviço ou fornecedor de materiais."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    nome: str
    categoria: str = Field(index=True)   # "prestador_servico" | "materiais"
    subcategoria: str
    regiao: Optional[str] = Field(default=None, index=True)
    telefone: Optional[str] = None
    email: Optional[str] = None
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


class Avaliacao(SQLModel, table=True):
    """Avaliação (rating) de um prestador/fornecedor."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    prestador_id: UUID = Field(index=True, foreign_key="prestador.id")
    # Notas para prestador de serviço (1–5, null para materiais)
    nota_qualidade_servico: Optional[int] = None
    nota_cumprimento_prazos: Optional[int] = None
    nota_fidelidade_projeto: Optional[int] = None
    # Notas para fornecedor de materiais (1–5, null para prestador de serviço)
    nota_prazo_entrega: Optional[int] = None
    nota_qualidade_material: Optional[int] = None
    comentario: Optional[str] = None
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


# ─── Fase 6 — Checklist Inteligente ─────────────────────────────────────────

class ChecklistGeracaoLog(SQLModel, table=True):
    """Log auditável de cada geração de checklist inteligente por IA."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    obra_id: UUID = Field(index=True, foreign_key="obra.id")
    status: str = Field(default="processando")  # processando | concluido | erro
    total_docs_analisados: int = Field(default=0)
    caracteristicas_identificadas: Optional[str] = None  # JSON string
    total_itens_sugeridos: int = Field(default=0)
    total_itens_aplicados: int = Field(default=0)
    total_paginas: int = Field(default=0)
    paginas_processadas: int = Field(default=0)
    resumo_geral: Optional[str] = None
    aviso_legal: Optional[str] = None
    erro_detalhe: Optional[str] = None
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


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
    projeto_doc_id: Optional[UUID] = None
    projeto_doc_nome: Optional[str] = None
    # 3 Camadas
    dado_projeto: Optional[str] = None
    verificacoes: Optional[str] = None
    pergunta_engenheiro: Optional[str] = None
    documentos_a_exigir: Optional[str] = None
    created_at: datetime = Field(default_factory=_utcnow)


# ─── Monetização — Subscription ──────────────────────────────────────────────

class Subscription(SQLModel, table=True):
    """Assinatura do usuário via Stripe."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    user_id: UUID = Field(foreign_key="user.id", unique=True, index=True)
    plan: str = Field(default="gratuito")  # "gratuito" | "essencial" | "completo" | "dono_da_obra" (legacy)
    status: str = Field(default="active")  # "active" | "expired" | "cancelled" | "grace_period"
    stripe_customer_id: Optional[str] = Field(default=None, index=True)
    store: Optional[str] = None  # "play_store" | "app_store"
    stripe_subscription_id: Optional[str] = None
    original_purchase_date: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    grace_period_expires_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


class UsageTracking(SQLModel, table=True):
    """Rastreamento de uso de features limitadas por período."""
    __table_args__ = (
        UniqueConstraint("user_id", "feature", "period", name="uq_usage_user_feature_period"),
    )
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    user_id: UUID = Field(foreign_key="user.id", index=True)
    feature: str  # "ai_visual" | "checklist_inteligente" | "doc_upload"
    period: str   # "2026-03" (YYYY-MM)
    count: int = Field(default=0)
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


class StripeWebhookEvent(SQLModel, table=True):
    """Log de eventos recebidos do Stripe webhook."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    event_type: str  # "INITIAL_PURCHASE" | "RENEWAL" | "EXPIRATION" etc.
    app_user_id: str = Field(index=True)
    product_id: Optional[str] = None
    store: Optional[str] = None
    event_timestamp: Optional[datetime] = None
    expiration_at: Optional[datetime] = None
    raw_payload: Optional[str] = None  # JSON completo para debug
    processed: bool = Field(default=False)
    created_at: datetime = Field(default_factory=_utcnow)


# ─── Monetização — Convites ──────────────────────────────────────────────────

class ObraConvite(SQLModel, table=True):
    """Convite de profissional para acessar uma obra."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    obra_id: UUID = Field(foreign_key="obra.id", index=True)
    dono_id: UUID = Field(foreign_key="user.id")
    convidado_id: Optional[UUID] = Field(default=None, foreign_key="user.id")
    email: str
    papel: str  # "arquiteto" | "engenheiro" | "empreiteiro"
    status: str = Field(default="pendente")  # "pendente" | "aceito" | "removido"
    token: str = Field(index=True)
    token_expires_at: datetime
    created_at: datetime = Field(default_factory=_utcnow)
    accepted_at: Optional[datetime] = None


class ObraDetalhamento(SQLModel, table=True):
    """Detalhamento da obra extraído por IA dos documentos (cômodos, m²)."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    obra_id: UUID = Field(foreign_key="obra.id", index=True)
    comodos: Optional[str] = None       # JSON: [{nome, area_m2}]
    area_total_m2: Optional[float] = None
    fonte_doc_id: Optional[UUID] = Field(default=None, foreign_key="projetodoc.id")
    fonte_doc_nome: Optional[str] = None
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


class EtapaComentario(SQLModel, table=True):
    """Comentário/nota em uma etapa (Dono ou convidado)."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    etapa_id: UUID = Field(foreign_key="etapa.id", index=True)
    user_id: UUID = Field(foreign_key="user.id")
    texto: str
    created_at: datetime = Field(default_factory=_utcnow)
