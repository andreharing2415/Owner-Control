# Checklist Inteligente — SSE Streaming Incremental

## Problema
O endpoint sincrono estoura memoria (OOM 512MB), excede limites de tokens das APIs,
e deixa o usuario esperando 30-60s sem feedback.

## Solucao
Pipeline incremental por pagina com Server-Sent Events (SSE).

## Fluxo do Usuario
1. Upload PDF → popup "Deseja atualizar o checklist inteligente?" → Sim
2. Abre tela com stepper visual (4 passos)
3. Backend processa pagina por pagina, envia resultados via SSE
4. Flutter atualiza stepper + lista de itens em tempo real

## Pipeline por Pagina
```
Para cada pagina do PDF:
  1. Extrair imagem (JPEG 150dpi)
  2. IA identifica caracteristicas naquela pagina
  3. Para cada caracteristica NOVA encontrada:
     - Gerar itens de checklist com normas detalhadas
     - Enviar ao cliente via SSE
  4. Cliente atualiza UI
```

## Eventos SSE
- `step` — mudanca de fase no stepper
- `page` — progresso de pagina (current/total)
- `caracteristica` — nova caracteristica identificada
- `itens` — itens gerados para uma caracteristica
- `error` — erro parcial (nao interrompe pipeline)
- `done` — pipeline concluido

## Stepper Visual (4 passos)
1. Extraindo PDFs
2. Analisando projeto
3. Gerando checklist
4. Concluido

## Normas Explicativas
Cada item de checklist inclui:
- `medidas_minimas`: lista das exigencias normativas concretas
- `explicacao_leigo`: linguagem acessivel ao proprietario
- Ex: "A NBR 16747 exige cerca minima de 1,10m, alarme de acesso e capa de protecao"

## Mudancas no Backend
- Novo endpoint GET `/api/obras/{id}/checklist-inteligente/stream` (SSE)
- Refatorar `checklist_inteligente.py`: pipeline incremental por pagina
- Manter DPI 150 para qualidade, processar 1 pagina por vez para memoria
- Prompt Fase 2 atualizado com campos `medidas_minimas` e `explicacao_leigo`

## Mudancas no Flutter
- Tela `ChecklistInteligenteScreen` com stepper + lista incremental
- `ApiClient.streamChecklistInteligente()` usando EventSource/SSE
- Trigger pos-upload: dialog perguntando se quer atualizar checklist

## Fallback Chain (mantida)
- Fase 1 (identificar): Claude → OpenAI → Gemini
- Fase 2 (gerar itens): OpenAI (web search) → Gemini
