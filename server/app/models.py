from datetime import datetime, date
from typing import Optional
from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel


# ─── Fase 7 — Autenticação ──────────────────────────────────────────────────

class User(SQLModel, table=True):
    """Usuário proprietário da plataforma."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    email: str = Field(unique=True, index=True)
    password_hash: str
    nome: str
    telefone: Optional[str] = None
    role: str = Field(default="owner")  # "owner" | "admin"
    ativo: bool = Field(default=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


# ─── Core ────────────────────────────────────────────────────────────────────

class Obra(SQLModel, table=True):
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    user_id: Optional[UUID] = Field(default=None, index=True, foreign_key="user.id")
    nome: str
    data_inicio: Optional[date] = None
    data_fim: Optional[date] = None
    orcamento: Optional[float] = None
    localizacao: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class Etapa(SQLModel, table=True):
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    obra_id: UUID = Field(index=True, foreign_key="obra.id")
    nome: str
    ordem: int
    status: str = Field(default="pendente")
    score: Optional[float] = None
    prazo_previsto: Optional[date] = None
    prazo_executado: Optional[date] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


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
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class Evidencia(SQLModel, table=True):
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    checklist_item_id: UUID = Field(index=True, foreign_key="checklistitem.id")
    arquivo_url: str
    arquivo_nome: str
    mime_type: Optional[str] = None
    tamanho_bytes: Optional[int] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class NormaLog(SQLModel, table=True):
    """Registro auditável de cada consulta normativa realizada."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    etapa_nome: str
    disciplina: Optional[str] = None
    localizacao: Optional[str] = None
    query_texto: str
    data_consulta: datetime = Field(default_factory=datetime.utcnow)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


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
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


# ─── Fase 2 — Governança Financeira ──────────────────────────────────────────

class OrcamentoEtapa(SQLModel, table=True):
    """Orçamento previsto por etapa de uma obra."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    obra_id: UUID = Field(index=True, foreign_key="obra.id")
    etapa_id: UUID = Field(index=True, foreign_key="etapa.id")
    valor_previsto: float
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


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
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class AlertaConfig(SQLModel, table=True):
    """Configuração de alertas de desvio orçamentário por obra."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    obra_id: UUID = Field(index=True, foreign_key="obra.id")
    percentual_desvio_threshold: float = Field(default=10.0)
    notificacao_ativa: bool = Field(default=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


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
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class Risco(SQLModel, table=True):
    """Risco identificado num documento de projeto pela IA."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    projeto_id: UUID = Field(index=True, foreign_key="projetodoc.id")
    descricao: str
    severidade: str  # "alto" | "medio" | "baixo"
    norma_referencia: Optional[str] = None
    norma_url: Optional[str] = None
    traducao_leigo: str
    acao_proprietario: Optional[str] = None
    perguntas_para_profissional: Optional[str] = None  # JSON string
    documentos_a_exigir: Optional[str] = None           # JSON string
    requer_validacao_profissional: bool = Field(default=False)
    confianca: int = Field(default=0)  # 0–100
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


# ─── Push Notifications ───────────────────────────────────────────────────────

class DeviceToken(SQLModel, table=True):
    """Token FCM de um dispositivo registrado para receber alertas de uma obra."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    obra_id: UUID = Field(index=True, foreign_key="obra.id")
    token: str = Field(index=True)
    platform: str = Field(default="android")  # "android" | "ios"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


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
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


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
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


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
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


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
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


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
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


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
