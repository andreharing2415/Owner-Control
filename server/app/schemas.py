from datetime import date, datetime
from typing import Optional, List, Any, Union
from uuid import UUID

from sqlmodel import SQLModel

from pydantic import EmailStr, field_validator

from .enums import EtapaStatus, ChecklistStatus


# ─── ARQ-06: Resposta padronizada ────────────────────────────────────────────

class OkResponse(SQLModel):
    """Resposta padrão para operações sem retorno específico."""
    ok: bool = True


# ─── Fase 7 — Autenticação ──────────────────────────────────────────────────

class UserRegister(SQLModel):
    nome: str
    email: EmailStr
    telefone: Optional[str] = None
    password: str

    @field_validator("password")
    @classmethod
    def validate_password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("A senha deve ter no mínimo 8 caracteres")
        if not any(c.isdigit() for c in v):
            raise ValueError("A senha deve conter pelo menos um número")
        if not any(c.isalpha() for c in v):
            raise ValueError("A senha deve conter pelo menos uma letra")
        return v


class UserLogin(SQLModel):
    email: EmailStr
    password: str


class UserRead(SQLModel):
    id: UUID
    email: str
    nome: str
    telefone: Optional[str] = None
    role: str
    plan: str = "gratuito"
    has_password: bool = True
    created_at: datetime

    @classmethod
    def from_user(cls, user: Any) -> "UserRead":
        return cls(
            id=user.id,
            email=user.email,
            nome=user.nome,
            telefone=user.telefone,
            role=user.role,
            plan=getattr(user, "plan", "gratuito"),
            has_password=user.password_hash is not None,
            created_at=user.created_at,
        )


class TokenResponse(SQLModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserRead


class TokenRefreshRequest(SQLModel):
    refresh_token: str


class GoogleLoginRequest(SQLModel):
    id_token: str


class GoogleTokenResponse(SQLModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserRead
    is_new_user: bool


class UpdateProfileRequest(SQLModel):
    nome: Optional[str] = None
    telefone: Optional[str] = None


# ─── Core ────────────────────────────────────────────────────────────────────

class ObraCreate(SQLModel):
    nome: str
    data_inicio: Optional[date] = None
    data_fim: Optional[date] = None
    orcamento: Optional[float] = None
    localizacao: Optional[str] = None
    area_m2: Optional[float] = None
    tipo: str = "construcao"  # "construcao" | "reforma"


class ObraRead(ObraCreate):
    id: UUID
    user_id: Optional[UUID] = None
    created_at: datetime
    updated_at: datetime


class EtapaRead(SQLModel):
    id: UUID
    obra_id: UUID
    nome: str
    ordem: int
    status: EtapaStatus
    score: Optional[float] = None
    prazo_previsto: Optional[date] = None
    prazo_executado: Optional[date] = None
    created_at: datetime
    updated_at: datetime


class EtapaEnrichedRead(EtapaRead):
    valor_previsto: Optional[float] = None
    valor_gasto: float = 0.0


class ObraDetailResponse(SQLModel):
    obra: ObraRead
    etapas: List[EtapaEnrichedRead] = []


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


class ChecklistItemRead(SQLModel):
    id: UUID
    etapa_id: Optional[UUID] = None
    atividade_id: Optional[UUID] = None
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
    # Fase 6 fields
    projeto_doc_id: Optional[UUID] = None
    projeto_doc_nome: Optional[str] = None
    como_verificar: Optional[str] = None
    medidas_minimas: Optional[str] = None
    explicacao_leigo: Optional[str] = None
    created_at: datetime
    updated_at: datetime


# ─── Role-based view projections (ROLE-04 / OWNER-03) ────────────────────────

class ChecklistItemOwnerView(SQLModel):
    """Projecao do checklist para o dono da obra — campos leigos, sem terminologia tecnica.

    Exclui: norma_referencia, severidade, dado_projeto, verificacoes,
            pergunta_engenheiro, documentos_a_exigir, confianca,
            requer_validacao_profissional, resultado_cruzamento, status_verificacao.
    Inclui: traducao_leigo, explicacao_leigo, como_verificar — linguagem acessivel.
    """
    id: UUID
    etapa_id: Optional[UUID] = None
    atividade_id: Optional[UUID] = None
    titulo: str
    descricao: Optional[str] = None
    status: ChecklistStatus
    critico: bool
    observacao: Optional[str] = None
    grupo: str
    ordem: int
    # Campos de linguagem leiga (mantidos para o dono)
    traducao_leigo: Optional[str] = None
    explicacao_leigo: Optional[str] = None
    como_verificar: Optional[str] = None
    # Registro do proprio dono
    registro_proprietario: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_item(cls, item: "ChecklistItemRead") -> "ChecklistItemOwnerView":
        """Projeta ChecklistItemRead filtrando campos tecnicos."""
        return cls(
            id=item.id,
            etapa_id=item.etapa_id,
            atividade_id=item.atividade_id,
            titulo=item.titulo,
            descricao=item.descricao,
            status=item.status,
            critico=item.critico,
            observacao=item.observacao,
            grupo=item.grupo,
            ordem=item.ordem,
            traducao_leigo=item.traducao_leigo,
            explicacao_leigo=item.explicacao_leigo,
            como_verificar=item.como_verificar,
            registro_proprietario=item.registro_proprietario,
            created_at=item.created_at,
            updated_at=item.updated_at,
        )


class AtividadeOwnerView(SQLModel):
    """Projecao do cronograma para o dono da obra — progresso simplificado sem financeiro.

    Exclui: valor_previsto, valor_gasto, tipo_projeto, is_modified, locked,
            servicos (detalhe operacional do engenheiro).
    Inclui: nome, descricao, status, datas — suficiente para acompanhamento.
    """
    id: UUID
    obra_id: UUID
    parent_id: Optional[UUID] = None
    nome: str
    descricao: Optional[str] = None
    ordem: int
    nivel: int
    status: str
    data_inicio_prevista: Optional[date] = None
    data_fim_prevista: Optional[date] = None
    data_inicio_real: Optional[date] = None
    data_fim_real: Optional[date] = None
    sub_atividades: List["AtividadeOwnerView"] = []
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_atividade(cls, ativ: "AtividadeCronogramaRead") -> "AtividadeOwnerView":
        """Projeta AtividadeCronogramaRead removendo campos financeiros e operacionais."""
        return cls(
            id=ativ.id,
            obra_id=ativ.obra_id,
            parent_id=ativ.parent_id,
            nome=ativ.nome,
            descricao=ativ.descricao,
            ordem=ativ.ordem,
            nivel=ativ.nivel,
            status=ativ.status,
            data_inicio_prevista=ativ.data_inicio_prevista,
            data_fim_prevista=ativ.data_fim_prevista,
            data_inicio_real=ativ.data_inicio_real,
            data_fim_real=ativ.data_fim_real,
            sub_atividades=[
                cls.from_atividade(sub) for sub in (ativ.sub_atividades or [])
            ],
            created_at=ativ.created_at,
            updated_at=ativ.updated_at,
        )


class CronogramaOwnerView(SQLModel):
    """Projecao do cronograma completo para o dono da obra.

    Remove totais financeiros — exibe apenas progresso por atividade.
    """
    obra_id: UUID
    atividades: List[AtividadeOwnerView] = []

    @classmethod
    def from_cronograma(cls, cronograma: "CronogramaResponse") -> "CronogramaOwnerView":
        """Projeta CronogramaResponse removendo dados financeiros."""
        return cls(
            obra_id=cronograma.obra_id,
            atividades=[
                AtividadeOwnerView.from_atividade(a) for a in (cronograma.atividades or [])
            ],
        )


AtividadeOwnerView.model_rebuild()


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


class EtapaStatusUpdate(SQLModel):
    status: EtapaStatus


class EtapaPrazoUpdate(SQLModel):
    prazo_previsto: Optional[date] = None
    prazo_executado: Optional[date] = None


class EvidenciaRead(SQLModel):
    id: UUID
    checklist_item_id: UUID
    arquivo_url: str
    arquivo_nome: str
    mime_type: Optional[str] = None
    tamanho_bytes: Optional[int] = None
    created_at: datetime
    updated_at: datetime


# ─── Normas ───────────────────────────────────────────────────────────────────

class NormaBuscarRequest(SQLModel):
    etapa_nome: str
    disciplina: Optional[str] = None
    localizacao: Optional[str] = None
    obra_tipo: Optional[str] = None


class NormaResultadoRead(SQLModel):
    id: UUID
    titulo: str
    fonte_nome: str
    fonte_url: Optional[str] = None
    fonte_tipo: str
    versao: Optional[str] = None
    data_norma: Optional[str] = None
    trecho_relevante: Optional[str] = None
    traducao_leigo: str
    nivel_confianca: int
    risco_nivel: Optional[str] = None
    requer_validacao_profissional: bool
    created_at: datetime


class NormaLogRead(SQLModel):
    id: UUID
    etapa_nome: str
    disciplina: Optional[str] = None
    localizacao: Optional[str] = None
    query_texto: str
    data_consulta: datetime
    created_at: datetime
    resultados: List[NormaResultadoRead] = []


class NormaBuscarResponse(SQLModel):
    log_id: UUID
    etapa_nome: str
    resumo_geral: str
    aviso_legal: str
    data_consulta: str
    normas: List[NormaResultadoRead]
    checklist_dinamico: List[Any] = []
    total_normas: int = 0  # total antes de truncar (para UI mostrar "X de Y")


class EtapaNormasChecklistRead(SQLModel):
    etapa_id: UUID
    normas: List[str]  # lista de norma_referencia distintas


class SugerirGrupoRequest(SQLModel):
    titulo: str


class SugerirGrupoResponse(SQLModel):
    grupo: str
    ordem: int


# ─── Fase 2 — Governança Financeira ──────────────────────────────────────────

class OrcamentoEtapaCreate(SQLModel):
    etapa_id: UUID
    valor_previsto: float
    valor_realizado: Optional[float] = None


class OrcamentoEtapaRead(SQLModel):
    id: UUID
    obra_id: UUID
    etapa_id: UUID
    valor_previsto: float
    valor_realizado: Optional[float] = None
    created_at: datetime
    updated_at: datetime


class DespesaCreate(SQLModel):
    etapa_id: Optional[UUID] = None
    valor: float
    descricao: str
    data: date
    categoria: Optional[str] = None
    comprovante_url: Optional[str] = None


class DespesaRead(SQLModel):
    id: UUID
    obra_id: UUID
    etapa_id: Optional[UUID] = None
    valor: float
    descricao: str
    data: date
    categoria: Optional[str] = None
    comprovante_url: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class AlertaConfigUpdate(SQLModel):
    percentual_desvio_threshold: Optional[float] = None
    notificacao_ativa: Optional[bool] = None


class AlertaConfigRead(SQLModel):
    id: UUID
    obra_id: UUID
    percentual_desvio_threshold: float
    notificacao_ativa: bool


class EtapaFinanceiroItem(SQLModel):
    etapa_id: str
    etapa_nome: str
    valor_previsto: float
    valor_gasto: float
    desvio_percentual: float
    alerta: bool


class CurvaSPonto(SQLModel):
    data: str
    previsto: float
    realizado: float


class RelatorioFinanceiro(SQLModel):
    obra_id: UUID
    total_previsto: float
    total_gasto: float
    desvio_percentual: float
    alerta: bool
    threshold: float
    por_etapa: List[EtapaFinanceiroItem]
    curva_s: List[CurvaSPonto] = []


# ─── Fase 3 — Document AI ─────────────────────────────────────────────────────

class ElementoConstrutivo(SQLModel):
    """Elemento construtivo específico extraído do documento de projeto pela IA.

    Resultado da extração em duas passagens:
    - Passagem 1: por página, identificando elementos brutos.
    - Passagem 2: consolidação global, deduplicando e enriquecendo.
    """
    categoria: str  # "Estrutural" | "Elétrico" | "Hidráulico" | "Arquitetura" | "Outro"
    nome: str  # ex: "Sapata de concreto armado", "Tubulação de esgoto PVC 100mm"
    descricao: Optional[str] = None  # detalhes técnicos extraídos do documento
    especificacao: Optional[str] = None  # materiais, dimensões, normas citadas
    localizacao: Optional[str] = None  # onde na obra: "banheiro social", "bloco A", etc.
    pagina_referencia: Optional[int] = None  # página do PDF onde o elemento foi identificado
    prancha_referencia: Optional[str] = None  # ex: "Folha 03 – Planta Hidráulica"
    confianca: int = 0  # 0-100, confiança da IA na extração


class ProjetoDocRead(SQLModel):
    id: UUID
    obra_id: UUID
    arquivo_url: str
    arquivo_nome: str
    status: str
    erro_detalhe: Optional[str] = None
    resumo_geral: Optional[str] = None
    aviso_legal: Optional[str] = None
    elementos_extraidos: Optional[str] = None  # JSON: [ElementoConstrutivo]
    created_at: datetime
    updated_at: datetime


class RiscoRead(SQLModel):
    id: UUID
    projeto_id: UUID
    descricao: str
    severidade: str
    disciplina: Optional[str] = None
    norma_referencia: Optional[str] = None
    norma_url: Optional[str] = None
    traducao_leigo: str
    acao_proprietario: Optional[str] = None
    perguntas_para_profissional: Optional[str] = None
    documentos_a_exigir: Optional[str] = None
    requer_validacao_profissional: bool
    confianca: int
    # 3 Camadas
    dado_projeto: Optional[str] = None
    verificacoes: Optional[str] = None
    pergunta_engenheiro: Optional[str] = None
    registro_proprietario: Optional[str] = None
    resultado_cruzamento: Optional[str] = None
    status_verificacao: str = "pendente"
    created_at: datetime


class RegistrarVerificacaoRequest(SQLModel):
    valor_medido: Optional[str] = None
    status: str  # "conforme" | "divergente" | "duvida"
    foto_ids: Optional[List[str]] = None


class ResultadoCruzamento(SQLModel):
    conclusao: str  # "conforme" | "divergente" | "duvida"
    resumo: str
    acao: Optional[str] = None
    urgencia: str = "media"  # "alta" | "media" | "baixa"


class ProjetoAnaliseRead(SQLModel):
    projeto: ProjetoDocRead
    riscos: List[RiscoRead]


# ─── Fase 4 — Visual AI ───────────────────────────────────────────────────────

class AchadoRead(SQLModel):
    id: UUID
    analise_id: UUID
    descricao: str
    severidade: str
    acao_recomendada: str
    requer_evidencia_adicional: bool
    requer_validacao_profissional: bool
    confianca: int
    created_at: datetime


class AnaliseVisualRead(SQLModel):
    id: UUID
    etapa_id: UUID
    imagem_url: str
    imagem_nome: str
    etapa_inferida: Optional[str] = None
    confianca: int
    status: str
    resumo_geral: Optional[str] = None
    aviso_legal: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class AnaliseVisualComAchadosRead(SQLModel):
    analise: AnaliseVisualRead
    achados: List[AchadoRead]


# ─── Push Notifications ───────────────────────────────────────────────────────

class DeviceTokenCreate(SQLModel):
    token: str
    platform: str = "android"  # "android" | "ios"


class DeviceTokenRead(SQLModel):
    id: UUID
    obra_id: UUID
    token: str
    platform: str
    created_at: datetime


# ─── Fase 5 — Prestadores e Fornecedores ─────────────────────────────────────

class PrestadorCreate(SQLModel):
    nome: str
    categoria: str   # "prestador_servico" | "materiais"
    subcategoria: str
    regiao: Optional[str] = None
    telefone: Optional[str] = None
    email: Optional[str] = None


class PrestadorRead(SQLModel):
    id: UUID
    nome: str
    categoria: str
    subcategoria: str
    regiao: Optional[str] = None
    telefone: Optional[str] = None
    email: Optional[str] = None
    nota_geral: Optional[float] = None
    total_avaliacoes: int = 0
    created_at: datetime
    updated_at: datetime


class PrestadorUpdate(SQLModel):
    nome: Optional[str] = None
    regiao: Optional[str] = None
    telefone: Optional[str] = None
    email: Optional[str] = None


class AvaliacaoCreate(SQLModel):
    nota_qualidade_servico: Optional[int] = None
    nota_cumprimento_prazos: Optional[int] = None
    nota_fidelidade_projeto: Optional[int] = None
    nota_prazo_entrega: Optional[int] = None
    nota_qualidade_material: Optional[int] = None
    comentario: Optional[str] = None

    @field_validator(
        "nota_qualidade_servico", "nota_cumprimento_prazos",
        "nota_fidelidade_projeto", "nota_prazo_entrega",
        "nota_qualidade_material",
    )
    @classmethod
    def validate_nota(cls, v: Optional[int]) -> Optional[int]:
        if v is not None and (v < 1 or v > 5):
            raise ValueError("Nota deve estar entre 1 e 5")
        return v


class AvaliacaoRead(SQLModel):
    id: UUID
    prestador_id: UUID
    nota_qualidade_servico: Optional[int] = None
    nota_cumprimento_prazos: Optional[int] = None
    nota_fidelidade_projeto: Optional[int] = None
    nota_prazo_entrega: Optional[int] = None
    nota_qualidade_material: Optional[int] = None
    comentario: Optional[str] = None
    created_at: datetime


class PrestadorDetalheRead(SQLModel):
    prestador: PrestadorRead
    avaliacoes: List[AvaliacaoRead]
    medias: dict


# ─── Fase 6 — Checklist Inteligente ─────────────────────────────────────────

class CaracteristicaIdentificada(SQLModel):
    id: str
    nome_legivel: str
    descricao_no_projeto: str
    confianca: int


class ItemChecklistSugerido(SQLModel):
    etapa_nome: str
    titulo: str
    descricao: str
    norma_referencia: Optional[str] = None
    critico: bool = False
    risco_nivel: str = "baixo"  # "alto" | "medio" | "baixo"
    requer_validacao_profissional: bool = False
    confianca: int = 0
    como_verificar: str = ""
    caracteristica_origem: str = ""


class ChecklistInteligenteResponse(SQLModel):
    log_id: UUID
    resumo_projeto: str
    observacoes_gerais: Optional[str] = None
    caracteristicas: List[CaracteristicaIdentificada]
    itens_por_etapa: dict  # { "etapa_nome": [ItemChecklistSugerido] }
    total_itens: int
    aviso_legal: str


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
    # Fase 6 fields
    como_verificar: Optional[str] = None
    medidas_minimas: Optional[str] = None
    explicacao_leigo: Optional[str] = None
    projeto_doc_id: Optional[UUID] = None
    projeto_doc_nome: Optional[str] = None
    # Rastreabilidade (AI-02)
    fonte_doc_trecho: Optional[str] = None


class IniciarChecklistRequest(SQLModel):
    projeto_ids: Optional[List[str]] = None


class AplicarChecklistRequest(SQLModel):
    log_id: Optional[UUID] = None
    itens: List[ItemParaAplicar]


class AplicarChecklistResponse(SQLModel):
    total_aplicados: int
    itens_criados: List[ChecklistItemRead]


class ChecklistGeracaoLogRead(SQLModel):
    id: UUID
    obra_id: UUID
    status: str
    total_docs_analisados: int
    caracteristicas_identificadas: Optional[str] = None
    total_itens_sugeridos: int
    total_itens_aplicados: int
    resumo_geral: Optional[str] = None
    aviso_legal: Optional[str] = None
    erro_detalhe: Optional[str] = None
    total_paginas: int = 0
    paginas_processadas: int = 0
    created_at: datetime


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
    projeto_doc_id: Optional[UUID] = None
    projeto_doc_nome: Optional[str] = None
    # 3 Camadas (new)
    dado_projeto: Optional[str] = None
    verificacoes: Optional[str] = None
    pergunta_engenheiro: Optional[str] = None
    documentos_a_exigir: Optional[str] = None
    # Rastreabilidade: trecho do documento que originou este item
    fonte_doc_trecho: Optional[str] = None
    created_at: datetime


class ChecklistGeracaoStatusRead(SQLModel):
    log: ChecklistGeracaoLogRead
    itens: List[ChecklistGeracaoItemRead]


# ─── Monetização — Subscription ──────────────────────────────────────────────

class SubscriptionRead(SQLModel):
    plan: str
    status: str
    expires_at: Optional[datetime] = None
    store: Optional[str] = None
    product_id: Optional[str] = None


class SubscriptionInfoResponse(SQLModel):
    """Resposta completa de /api/subscription/me."""
    plan: str
    plan_config: dict
    usage: dict  # {"ai_visual": 0, "checklist_inteligente": 0, ...}
    obra_count: int
    doc_count: int
    convite_count: int = 0
    expires_at: Optional[datetime] = None
    status: str = "active"
    show_ads: bool = True
    can_watch_rewarded: bool = False


class RewardUsageRequest(SQLModel):
    """Request para conceder usos extras via rewarded ad."""
    feature: str  # "ai_visual" | "checklist_inteligente" | "doc_upload" | "normas"


class RewardUsageResponse(SQLModel):
    """Response após conceder usos extras via rewarded ad."""
    feature: str
    new_count: int
    bonus_granted: int


# ─── Monetização — Convites ──────────────────────────────────────────────────

class ConviteCreateRequest(SQLModel):
    email: str
    papel: str  # "arquiteto" | "engenheiro" | "empreiteiro"


class ConviteRead(SQLModel):
    id: UUID
    obra_id: UUID
    email: str
    papel: str
    status: str
    convidado_nome: Optional[str] = None
    created_at: datetime
    accepted_at: Optional[datetime] = None


class ConviteAceitarRequest(SQLModel):
    token: str
    nome: str  # nome do convidado (para criar conta simplificada)


class ObraConvidadaRead(SQLModel):
    """Obra vista pelo convidado."""
    obra_id: UUID
    obra_nome: str
    dono_nome: str
    papel: str
    convite_id: UUID


# ─── Comentários em Etapas ───────────────────────────────────────────────────

class ComentarioCreateRequest(SQLModel):
    texto: str


class ComentarioRead(SQLModel):
    id: UUID
    etapa_id: UUID
    user_id: UUID
    user_nome: str = ""
    texto: str
    created_at: datetime


# ─── Cronograma ──────────────────────────────────────────────────────────────

class TipoProjetoIdentificado(SQLModel):
    nome: str               # "Estrutural", "Elétrico", "Hidráulico", etc.
    confianca: int = 0      # 0-100
    projeto_doc_id: Optional[UUID] = None
    projeto_doc_nome: Optional[str] = None


class IdentificarProjetosResponse(SQLModel):
    tipos: List[TipoProjetoIdentificado]
    resumo: str
    aviso_legal: str


class ServicoNecessarioRead(SQLModel):
    id: UUID
    atividade_id: UUID
    descricao: str
    categoria: str
    prestador_id: Optional[UUID] = None
    created_at: datetime


class AtividadeCronogramaRead(SQLModel):
    id: UUID
    obra_id: UUID
    parent_id: Optional[UUID] = None
    nome: str
    descricao: Optional[str] = None
    ordem: int
    nivel: int
    status: str
    data_inicio_prevista: Optional[date] = None
    data_fim_prevista: Optional[date] = None
    data_inicio_real: Optional[date] = None
    data_fim_real: Optional[date] = None
    valor_previsto: float = 0
    valor_gasto: float = 0
    tipo_projeto: Optional[str] = None
    # Preservação de edições manuais (AI-03)
    is_modified: bool = False
    locked: bool = False
    sub_atividades: List["AtividadeCronogramaRead"] = []
    servicos: List[ServicoNecessarioRead] = []
    created_at: datetime
    updated_at: datetime


class CronogramaResponse(SQLModel):
    obra_id: UUID
    total_previsto: float = 0
    total_gasto: float = 0
    desvio_percentual: float = 0
    atividades: List[AtividadeCronogramaRead] = []


ChecklistItemRoleView = Union[ChecklistItemRead, ChecklistItemOwnerView]
CronogramaRoleView = Union[CronogramaResponse, CronogramaOwnerView]


def project_checklist_item_for_role(
    item: ChecklistItemRead,
    role: str,
) -> ChecklistItemRoleView:
    """Seleciona projeção de checklist conforme papel do usuário."""
    if role == "dono_da_obra":
        return ChecklistItemOwnerView.from_item(item)
    return item


def project_cronograma_for_role(
    cronograma: CronogramaResponse,
    role: str,
) -> CronogramaRoleView:
    """Seleciona projeção de cronograma conforme papel do usuário."""
    if role == "dono_da_obra":
        return CronogramaOwnerView.from_cronograma(cronograma)
    return cronograma


class AtividadeUpdate(SQLModel):
    status: Optional[str] = None
    data_inicio_real: Optional[date] = None
    data_fim_real: Optional[date] = None
    valor_previsto: Optional[float] = None
    valor_gasto: Optional[float] = None
    # Edições manuais (AI-03) — qualquer PATCH marca is_modified automaticamente no router
    nome: Optional[str] = None
    descricao: Optional[str] = None
    data_inicio_prevista: Optional[date] = None
    data_fim_prevista: Optional[date] = None
    locked: Optional[bool] = None


class VincularPrestadorRequest(SQLModel):
    prestador_id: UUID


class DespesaAtividadeCreate(SQLModel):
    valor: float
    descricao: str
    data: date
    categoria: Optional[str] = None


# ─── Aplicar Riscos ─────────────────────────────────────────────────────────

class AplicarRiscosRequest(SQLModel):
    risco_ids: List[str]


# ─── Geração Unificada — state machine (AI-06/AI-07) ─────────────────────────

class IniciarGeracaoUnificadaRequest(SQLModel):
    """Request para iniciar geração unificada (cronograma + checklist)."""
    tipos_projeto: List[str]


class GeracaoUnificadaLogRead(SQLModel):
    """Estado atual do log de geração unificada — retornado no polling."""
    id: UUID
    obra_id: UUID
    status: str                           # GeracaoUnificadaStatus values
    etapa_atual: Optional[str] = None     # descrição humana da etapa em curso
    total_atividades: int = 0
    atividades_geradas: int = 0
    total_itens_checklist: int = 0
    erro_detalhe: Optional[str] = None
    created_at: datetime
    updated_at: datetime


AtividadeCronogramaRead.model_rebuild()
