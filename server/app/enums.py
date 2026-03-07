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
