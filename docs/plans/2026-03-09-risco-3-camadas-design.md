# Design: Análise de Risco em 3 Camadas com Cruzamento Inteligente

**Data**: 2026-03-09
**Status**: Aprovado

## Problema

A análise de risco atual é genérica ("Verifique com um engenheiro se as paredes suportarão a estrutura"). Isso:
- Não dá ao proprietário nada concreto para verificar
- Pode soar como desafio ao engenheiro
- Não aproveita os dados concretos que existem no projeto

## Solução

Redesign do sistema de risco para 3 camadas:

1. **O que o projeto diz** — dados concretos extraídos do PDF (medidas, materiais, fontes)
2. **Verifique na obra** — checklist de verificações simples que o proprietário faz sozinho
3. **Se algo parecer diferente** — pergunta colaborativa e respeitosa para o engenheiro

Cruzamento opcional: proprietário registra medições/fotos e a IA compara com o projeto.

## Modelo de Dados

### Campos novos no modelo `Risco`:

```python
# dado_projeto: JSON
{
    "descricao": "Parede estrutural do quarto 1",
    "especificacao": "Espessura 19cm, bloco cerâmico 14x19x29",
    "fonte": "Planta Estrutural - Folha 3",
    "valor_referencia": "19cm"
}

# verificacoes: JSON (lista)
[
    {
        "instrucao": "Meça a espessura da parede com trena",
        "tipo": "medicao",  # medicao | visual | documento
        "valor_esperado": "mínimo 19cm",
        "como_medir": "Posicione a trena na lateral da parede, sem reboco"
    }
]

# pergunta_engenheiro: JSON
{
    "contexto": "Notei que a parede está com [X]cm, mas o projeto indica 19cm",
    "pergunta": "Houve alguma alteração ou ajuste técnico?",
    "tom": "colaborativo"
}

# registro_proprietario: JSON (preenchido pelo usuário, opcional)
{
    "valor_medido": "15cm",
    "foto_ids": ["uuid1", "uuid2"],
    "status": "conforme | divergente | duvida",
    "data_verificacao": "2026-03-09"
}

# resultado_cruzamento: JSON (gerado pela IA)
{
    "conclusao": "divergente",
    "resumo": "A parede medida (15cm) está abaixo do projeto (19cm)",
    "acao": "Pergunte ao engenheiro usando a sugestão abaixo",
    "urgencia": "alta"
}
```

## Prompt da IA (Direcionamento)

Muda de "identifique riscos e traduza para leigo" para "extraia dados concretos e gere verificações observáveis".

Regras:
- NÃO gerar riscos vagos
- Confiança < 50% = não gerar o risco
- Priorizar itens verificáveis fisicamente
- Tom da pergunta ao engenheiro: sempre colaborativo
- Norma é informativa, não para o proprietário cobrar

## Novo Endpoint

```
POST /api/riscos/{risco_id}/verificar
Body: { valor_medido?, status, foto_ids? }
→ IA cruza dados e retorna resultado_cruzamento
```

## Telas Mobile

1. **Lista de Riscos** — ajustar cards com badge de status
2. **Detalhe do Risco** — redesign com 3 blocos + resultado cruzamento inline
3. **Registrar Verificação** — nova tela com formulário simples
4. **Resultado do Cruzamento** — bloco inline na tela de detalhe

## O que NÃO muda

- Modelo `Achado` (análise visual) — fase futura
- Modelo `NormaResultado`
- Fluxo de upload de PDF
- Fallback chain (Claude → OpenAI → Gemini)
