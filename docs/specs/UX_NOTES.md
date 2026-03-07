# UX Notes - Checklists e Evidencias

## Objetivo
Descrever o prototipo de UX para fluxo de checklists e evidencias.

## Requisitos funcionais
- Exibir etapas e checklists por etapa.
- Permitir marcar itens, adicionar comentarios e evidencias.
- Mostrar score por etapa e status geral.
- Registrar evidencias com metadata basica.

## Dados de entrada
- Etapa selecionada.
- Itens do checklist.
- Evidencias (foto/arquivo), comentario, status.

## Dados de saida
- Itens atualizados com status e evidencias.
- Score por etapa recalculado.
- Log de evidencias associado ao item.

## Fluxos principais
1. Usuario entra na obra e seleciona etapa.
2. Sistema lista checklist da etapa com status atual.
3. Usuario marca item e anexa evidencia.
4. Sistema atualiza score e registra evidencia.
5. Usuario exporta relatorio quando necessario.

## Telas e componentes
- Visao de etapas: cards com status e progresso.
- Lista de checklist: item, status, comentario, evidencia.
- Modal de evidencia: upload, descricao, data.
- Resumo da etapa: score e itens criticos.

## Regras de UX
- Evidencia obrigatoria para itens criticos.
- Destaque visual para itens com risco alto.
- Linguagem leiga e sem parecer tecnico.

## Criterios de aceite
- Fluxo principal documentado.
- Componentes chave listados.
- Regras de UX alinhadas aos guardrails.

