# Design: Checklist Grupos, Tela Detalhe e Integração Normas

**Data:** 2026-03-08
**Status:** Aprovado

## Problema

1. Normas identificadas pelo Checklist Inteligente não aparecem na Biblioteca Normativa
2. Ícone de status (bolinha) na lista de checklist confunde o usuário — parece clicável mas não é
3. Itens do checklist não têm ordenação cronológica nem agrupamento por categoria (piscina, churrasqueira, etc.)
4. Não existe tela de detalhe do item — tudo via popup menu de 3 pontos
5. Não há controle de prazo previsto vs executado

## Solução: Opção B

Adicionar `grupo` e `ordem` em `ChecklistItem`. Prazo previsto/executado em `Etapa`. Refatorar UX da lista. Criar tela de detalhe. Integrar normas do checklist na Biblioteca Normativa.

---

## 1. Banco de Dados

### ChecklistItem — novos campos
```sql
ALTER TABLE checklistitem ADD COLUMN grupo VARCHAR DEFAULT 'Geral';
ALTER TABLE checklistitem ADD COLUMN ordem INTEGER DEFAULT 0;
```
- `grupo`: string livre, ex: `"Piscina"`, `"Churrasqueira"`, `"Geral"`
- `ordem`: inteiro para ordenação cronológica dentro do grupo

### Etapa — novos campos
```sql
ALTER TABLE etapa ADD COLUMN prazo_previsto DATE;
ALTER TABLE etapa ADD COLUMN prazo_executado DATE;
```

---

## 2. Backend (FastAPI)

### Endpoints modificados
- `GET /etapas/{id}/checklist` — retorna `grupo` e `ordem` nos itens
- `POST /etapas/{id}/checklist` — aceita `grupo` e `ordem` na criação
- `PATCH /checklist/{id}` — aceita `grupo` e `ordem` na atualização
- `PATCH /etapas/{id}` — aceita `prazo_previsto` e `prazo_executado`

### Novos endpoints
- `GET /etapas/{id}/checklist/normas` — retorna lista de `norma_referencia` distintas dos itens da etapa (para Biblioteca Normativa)
- `POST /etapas/{id}/checklist/sugerir-grupo` — recebe `titulo` do novo item, analisa itens existentes via IA, retorna sugestão de `grupo` e `ordem`

### Checklist Inteligente (aplicar)
- Ao aplicar itens, preencher `grupo` com `caracteristica_origem` capitalizado (ex: `"piscina"` → `"Piscina"`)
- Preencher `ordem` baseado na sequência das etapas da obra (items de fundação < alvenaria < instalações)

---

## 3. Flutter — Tela de Checklist (refatorada)

### UX da lista
- Remover ícone de status (bolinha) da esquerda
- Card inteiro clicável → abre tela de detalhe
- Badge de status no canto direito do card: chip pequeno colorido ("OK" verde, "Pendente" cinza, "Não conforme" vermelho)
- Menu de 3 pontos: apenas "Remover item"
- FAB `+` abre diálogo de criação com sugestão de grupo via endpoint `sugerir-grupo`

### Agrupamento
- ListView com headers separadores por grupo
- Header exibe: `"Churrasqueira · 2/5"` (itens concluídos / total)
- Itens ordenados por `ordem` dentro do grupo
- Grupo "Geral" sempre por último

### Prazo da etapa
- Ícone de calendário no AppBar → bottom sheet com DatePicker para previsto e executado
- Exibe badge no AppBar se prazo vencido (data prevista < hoje e status ≠ concluído)

---

## 4. Flutter — Tela de Detalhe do Item (nova)

Arquivo: `mobile/lib/screens/checklist/detalhe_item_screen.dart`

### Seções
1. **Header** — título, badge Crítico, chip grupo + etapa
2. **Descrição** — texto completo do item
3. **Norma de referência** — exibe `norma_referencia` com botão "Ver na Biblioteca" (navega para `NormasScreen` com etapa pré-selecionada)
4. **Status** — 3 botões grandes: Pendente / OK / Não Conforme (atualiza via API ao tocar)
5. **Evidências** — grid de thumbnails das fotos + botão "Adicionar foto" (câmera / galeria / arquivo)
6. **Observação** — campo de texto editável com botão salvar

---

## 5. Flutter — Biblioteca Normativa (integração)

### Seção "Normas desta etapa"
- Quando a tela é aberta a partir de uma etapa (`etapaId` passado como parâmetro), exibir seção no topo antes da busca por IA
- Chama `GET /etapas/{id}/checklist/normas`
- Lista as normas identificadas (ex: "NBR 5410:2004", "NBR 7200:2016") como chips clicáveis
- Clicar em um chip pre-preenche a busca e executa automaticamente
- Se aberta do menu principal (sem etapaId), seção não aparece

### Modelo de dados
- `ChecklistItem.norma_referencia` já existe no backend
- Novo endpoint agrega e deduplica por etapa

---

## Ordem de implementação

1. Migração Alembic (grupo, ordem, prazo_previsto, prazo_executado)
2. Backend: atualizar schemas/endpoints existentes + 2 novos endpoints
3. Flutter: atualizar modelo `ChecklistItem` + `Etapa`
4. Flutter: refatorar `ChecklistScreen` (grupos, UX, prazo)
5. Flutter: criar `DetalheItemScreen`
6. Flutter: integrar seção de normas na `NormasScreen`
7. Deploy backend
