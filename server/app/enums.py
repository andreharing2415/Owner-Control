from enum import Enum


class EtapaStatus(str, Enum):
    PENDENTE = "pendente"
    EM_ANDAMENTO = "em_andamento"
    CONCLUIDA = "concluida"


class ChecklistStatus(str, Enum):
    PENDENTE = "pendente"
    OK = "ok"
    NAO_CONFORME = "nao_conforme"


class CategoriaPrestador(str, Enum):
    PRESTADOR_SERVICO = "prestador_servico"
    MATERIAIS = "materiais"


class SubcategoriaPrestadorServico(str, Enum):
    ARQUITETO = "arquiteto"
    EMPREITEIRO = "empreiteiro"
    PINTOR = "pintor"
    MARCENARIA = "marcenaria"
    MARMORE_GRANITO = "marmore_granito"
    ELETRICISTA = "eletricista"
    ENCANADOR = "encanador"
    SERRALHEIRO = "serralheiro"
    VIDRACEIRO = "vidraceiro"
    GESSEIRO = "gesseiro"
    OUTRO = "outro"


class SubcategoriaMateriais(str, Enum):
    LOJA_MATERIAL = "loja_material"
    FORNECEDOR_ACO = "fornecedor_aco"
    MADEIRA = "madeira"
    TINTA = "tinta"
    ELETRO_ELETRONICOS = "eletro_eletronicos"
    HIDRAULICA = "hidraulica"
    CERAMICA = "ceramica"
    OUTRO = "outro"


# ─── COMPL-03: Enums para status que antes eram magic strings ─────────────────

class ProjetoDocStatus(str, Enum):
    PENDENTE = "pendente"
    PROCESSANDO = "processando"
    CONCLUIDO = "concluido"
    ERRO = "erro"


class AnaliseVisualStatus(str, Enum):
    PROCESSANDO = "processando"
    CONCLUIDA = "concluida"
    ERRO = "erro"


class ChecklistGeracaoStatus(str, Enum):
    PROCESSANDO = "processando"
    CONCLUIDO = "concluido"
    ERRO = "erro"


class ConviteStatus(str, Enum):
    PENDENTE = "pendente"
    ACEITO = "aceito"
    REMOVIDO = "removido"


class AtividadeStatus(str, Enum):
    PENDENTE = "pendente"
    EM_ANDAMENTO = "em_andamento"
    CONCLUIDA = "concluida"


class GeracaoUnificadaStatus(str, Enum):
    PENDENTE = "pendente"        # criado, aguardando background worker iniciar
    ANALISANDO = "analisando"    # lendo e indexando documentos
    GERANDO = "gerando"          # IA produzindo cronograma + checklist
    CONCLUIDO = "concluido"      # cronograma e checklist persistidos com sucesso
    ERRO = "erro"                # falha irrecuperavel — erro_detalhe preenchido
    CANCELADO = "cancelado"      # cliente desconectou antes da conclusao
