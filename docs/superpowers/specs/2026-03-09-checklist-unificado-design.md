# Checklist Unificado com 3 Blocos — Design Spec

**Data:** 2026-03-09
**Status:** Aprovado

## Objetivo

Unificar riscos e checklist numa única entidade. O checklist passa a ser o hub central de qualidade da obra. Cada item pode ter 3 blocos de orientação (detalhamento, verificação, norma/engenheiro) preenchidos por IA a partir dos PDFs do projeto. A tela separada de riscos é eliminada.

## O que muda

- `ChecklistItem` ganha os campos das 3 camadas (hoje no modelo `Risco`)
- Geração por IA preenche os 3 blocos nos itens do checklist
- Itens ordenados cronologicamente por etapa de obra
- Telas de risco (`analise_documento_screen`, `detalhe_risco_screen`, `registrar_verificacao_screen`) são removidas

## O que permanece

- Evidências (fotos/arquivos) por item
- Status: pendente / ok / não conforme
- Grupos por etapa
- Feature gate (plano pago)

## Modelo: ChecklistItem ampliado

Campos novos adicionados ao `ChecklistItem`:

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `severidade` | str, opcional | "alto", "medio", "baixo" |
| `dado_projeto` | JSON, opcional | Especificação do PDF: descrição, especificação, fonte, valor_referência |
| `traducao_leigo` | str, opcional | Explicação simples para leigo |
| `verificacoes` | JSON lista, opcional | Checklist prático: instrução, tipo (medicao/visual/documento), valor esperado, como medir |
| `pergunta_engenheiro` | JSON, opcional | Contexto + pergunta colaborativa |
| `documentos_a_exigir` | JSON lista, opcional | Documentos que o dono deve exigir |
| `registro_proprietario` | JSON, opcional | Valor medido + status + foto_ids + data_verificacao |
| `resultado_cruzamento` | JSON, opcional | Conclusão + resumo + ação + urgência |
| `status_verificacao` | str | "pendente", "conforme", "divergente", "duvida" (default: "pendente") |
| `confianca` | int, opcional | 0-100, confiança da IA |
| `requer_validacao_profissional` | bool | default: false |

## UI: Tela principal do checklist

Lista cronológica. Cada card mostra:

- Título do item
- Badge de status (pendente/ok/não conforme)
- Badge de severidade (vermelho/laranja/verde) — se preenchido
- Ícone de "enriquecido pela IA" se `dado_projeto` preenchido
- Progresso: "2/3 blocos verificados"

## UI: Detalhe do item (3 blocos expansíveis)

### Bloco 1 — "O que o projeto diz" (ícone: architecture, teal)

- `dado_projeto.descricao` + `dado_projeto.especificacao`
- `traducao_leigo` em caixa destacada (índigo)
- Fonte: `dado_projeto.fonte`
- Se vazio: "Solicite análise por IA para preencher"

### Bloco 2 — "Verifique na obra" (ícone: checklist_rtl, blue)

- Lista de `verificacoes` com ícones por tipo:
  - medicao → Icons.straighten
  - visual → Icons.visibility
  - documento → Icons.description
- Valor esperado + como medir
- Botão "Registrar Verificação" → form inline:
  - Campo texto: valor medido
  - 3 opções: conforme / divergente / dúvida
  - Upload de foto
- Resultado do cruzamento exibido inline (se já registrado)

### Bloco 3 — "Norma & Engenheiro" (ícone: engineering, deep purple)

- Norma de referência (link clicável)
- `pergunta_engenheiro`: contexto + pergunta
- `documentos_a_exigir`: lista
- Se vazio: "Nenhuma norma identificada"

## Fluxo da IA

1. Usuário clica "Analisar com IA" na tela do checklist
2. Backend recebe: `obra_id` + lista de itens padrão existentes
3. IA analisa PDFs do projeto + contexto dos itens existentes
4. Retorna:
   - Itens existentes **preenchidos** (3 blocos + severidade + confiança)
   - Itens **novos** sugeridos (já com 3 blocos)
5. Usuário revisa e aplica

## Migração de dados

- Riscos existentes → viram ChecklistItems na etapa correspondente
- Campos mapeados 1:1 (mesmos nomes JSON)
- Tabela `risco` removida após migração

## Endpoints

| Ação | Antes | Depois |
|------|-------|--------|
| Ver riscos | `GET /api/projetos/{id}/analise` | Removido — dados no checklist |
| Verificar risco | `POST /api/riscos/{id}/verificar` | `POST /api/checklist-items/{id}/verificar` (novo) |
| Gerar checklist IA | `POST /obras/{id}/checklist-inteligente/iniciar` | Mesmo endpoint, retorna 3 blocos |
| Aplicar checklist IA | `POST /obras/{id}/checklist-inteligente/aplicar` | Mesmo, com campos ampliados |

## Telas removidas

- `analise_documento_screen.dart` — lista de riscos
- `detalhe_risco_screen.dart` — detalhe do risco
- `registrar_verificacao_screen.dart` — form de verificação de risco

## Telas modificadas

- `checklist_screen.dart` — cards com badges de severidade + ícone IA
- `detalhe_item_screen.dart` — 3 blocos expansíveis (reusa widgets do detalhe_risco)
- `checklist_inteligente_screen.dart` — adaptado para novo formato de retorno
