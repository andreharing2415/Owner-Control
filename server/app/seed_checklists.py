"""
Itens de checklist padrão por etapa, baseados no DOMAIN_TAXONOMY.md.
Itens marcados como critico=True exigem evidência obrigatória.
"""

from .enums import ChecklistStatus

CHECKLIST_PADRAO: dict[str, list[dict]] = {
    "Planejamento e Projeto": [
        {
            "titulo": "Definição de escopo do projeto",
            "descricao": "Escopo formal do empreendimento definido e documentado.",
            "critico": True,
        },
        {
            "titulo": "Aprovação de projetos executivos",
            "descricao": "Projetos de arquitetura, estrutura, elétrica e hidráulica aprovados.",
            "critico": True,
        },
        {
            "titulo": "Obtenção de licenças e alvarás",
            "descricao": "Alvará de construção e demais licenças municipais emitidos.",
            "critico": True,
        },
        {
            "titulo": "Memorial descritivo aprovado",
            "descricao": "Memorial descritivo dos projetos revisado e aprovado.",
            "critico": False,
        },
        {
            "titulo": "ART/RRT dos responsáveis técnicos",
            "descricao": "Anotações de Responsabilidade Técnica dos profissionais envolvidos.",
            "critico": True,
        },
    ],
    "Preparacao do Terreno": [
        {
            "titulo": "Limpeza e demarcação do terreno",
            "descricao": "Terreno limpo, vegetação removida e demarcação topográfica realizada.",
            "critico": False,
        },
        {
            "titulo": "Movimentação de terra",
            "descricao": "Cortes e aterros executados conforme projeto topográfico.",
            "critico": False,
        },
        {
            "titulo": "Drenagem provisória implantada",
            "descricao": "Sistema de drenagem provisória do canteiro instalado.",
            "critico": False,
        },
        {
            "titulo": "Acesso ao canteiro garantido",
            "descricao": "Via de acesso para entrada de materiais e equipamentos definida.",
            "critico": False,
        },
        {
            "titulo": "Licença ambiental (se aplicável)",
            "descricao": "Autorização ambiental para movimentação de terra obtida.",
            "critico": True,
        },
    ],
    "Fundacoes e Estrutura": [
        {
            "titulo": "Gabarito e locação das fundações",
            "descricao": "Locação executada conforme projeto estrutural aprovado.",
            "critico": True,
        },
        {
            "titulo": "Escavação das fundações",
            "descricao": "Escavação realizada na cota e dimensões especificadas no projeto.",
            "critico": True,
        },
        {
            "titulo": "Armação (ferragem) conferida",
            "descricao": "Armadura de aço verificada quanto a bitola, espaçamento e cobrimento.",
            "critico": True,
        },
        {
            "titulo": "Concretagem das fundações",
            "descricao": "Concreto lançado com fck conforme projeto e amostra coletada para ensaio.",
            "critico": True,
        },
        {
            "titulo": "Laudos de sondagem disponíveis",
            "descricao": "Laudo de sondagem do solo (SPT) disponível e compatível com projeto.",
            "critico": True,
        },
        {
            "titulo": "Estrutura de concreto concluída",
            "descricao": "Pilares, vigas e lajes executados conforme projeto estrutural.",
            "critico": True,
        },
        {
            "titulo": "Ensaio de resistência do concreto (CP)",
            "descricao": "Corpos de prova rompidos com resultado igual ou superior ao fck de projeto.",
            "critico": True,
        },
    ],
    "Alvenaria e Cobertura": [
        {
            "titulo": "Levantamento de alvenaria",
            "descricao": "Alvenaria executada com espessura, prumo e nível adequados.",
            "critico": False,
        },
        {
            "titulo": "Impermeabilização de fundações e lajes",
            "descricao": "Impermeabilização aplicada conforme especificação técnica.",
            "critico": True,
        },
        {
            "titulo": "Estrutura de cobertura instalada",
            "descricao": "Tesouras, caibros e ripas da cobertura fixados conforme projeto.",
            "critico": True,
        },
        {
            "titulo": "Teste de estanqueidade realizado",
            "descricao": "Teste de estanqueidade das lajes e áreas úmidas com resultado satisfatório.",
            "critico": True,
        },
        {
            "titulo": "Telhas e rufos instalados",
            "descricao": "Cobertura concluída com telhas, cumeeiras e rufos vedados.",
            "critico": False,
        },
    ],
    "Instalacoes e Acabamentos": [
        {
            "titulo": "Instalações elétricas e SPDA",
            "descricao": "Rede elétrica, quadros, tomadas e sistema de proteção contra descargas instalados.",
            "critico": True,
        },
        {
            "titulo": "Instalações hidráulicas",
            "descricao": "Tubulações de água fria, quente e esgoto instaladas e testadas.",
            "critico": True,
        },
        {
            "titulo": "Teste de pressão hidráulica",
            "descricao": "Teste de pressão nas tubulações de água com resultado aprovado.",
            "critico": True,
        },
        {
            "titulo": "Aterramento elétrico verificado",
            "descricao": "Resistência do aterramento medida e dentro dos limites da NBR 5419.",
            "critico": True,
        },
        {
            "titulo": "Revestimentos e acabamentos concluídos",
            "descricao": "Revestimentos cerâmicos, pinturas e acabamentos finais executados.",
            "critico": False,
        },
        {
            "titulo": "Esquadrias instaladas e reguladas",
            "descricao": "Portas, janelas e portões instalados, nivelados e funcionando corretamente.",
            "critico": False,
        },
    ],
    "Entrega e Pos-obra": [
        {
            "titulo": "Vistoria final realizada",
            "descricao": "Vistoria completa da obra com registro de pendências e soluções.",
            "critico": True,
        },
        {
            "titulo": "Termo de entrega assinado",
            "descricao": "Termo de recebimento da obra assinado por responsável técnico e proprietário.",
            "critico": True,
        },
        {
            "titulo": "Manual do proprietário entregue",
            "descricao": "Manual com instruções de uso e manutenção dos sistemas entregue ao proprietário.",
            "critico": False,
        },
        {
            "titulo": "As-built entregue",
            "descricao": "Projetos as-built (como construído) entregues e arquivados.",
            "critico": True,
        },
        {
            "titulo": "Habite-se obtido (se aplicável)",
            "descricao": "Certificado de conclusão de obra (Habite-se) emitido pela prefeitura.",
            "critico": True,
        },
    ],
}


def get_itens_padrao(nome_etapa: str) -> list[dict]:
    """Retorna lista de itens padrão para a etapa informada."""
    return CHECKLIST_PADRAO.get(nome_etapa, [])
