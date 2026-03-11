# Fase 6 — Ajuste Completo ObraMaster (19 Itens)

## Context
O usuário testou o app após deploy da Fase 5 e identificou 19 melhorias/bugs agrupados em: bugs de assinatura/backend, UX do checklist, integração IA, financeiro inline, e novos campos/features. Os endpoints de IA nunca foram testados em produção.

---

## FASE 6A — Bugs Críticos & Backend Fixes
> Prioridade máxima. Sem isso, features pagas não funcionam corretamente.

### 6A.1: Bug "Dono" tag após cancelamento
**Problema:** Ao cancelar assinatura, `sub.status = "cancelled"` mas `user.plan` permanece `"dono_da_obra"`. A tag "Dono" no dashboard (e feature gates) continuam ativos.

**Arquivos:**
- `server/app/main.py` ~L2459: adicionar `user.plan = "gratuito"` + `session.add(user)` após setar `sub.status = "cancelled"`
- `server/app/main.py` ~L2615-2617: no webhook handler, quando `status_val in ("canceled", "unpaid")`, setar `user.plan = "gratuito"`
- `mobile/lib/providers/subscription_provider.dart`: `isDono` deve também checar `_info?.status == "active"` (ou "grace_period")
- `mobile/lib/models/subscription.dart`: garantir que `status` é parseado no SubscriptionInfo

### 6A.2: Fix endpoint análise visual (connection abort)
**Problema:** `POST /api/etapas/{id}/analise-visual` dá connection abort. Provavelmente timeout do Cloud Run (default 60s) para chamadas de IA que podem levar >60s.

**Ações:**
- `server/deploy-cloudrun.sh`: aumentar `--timeout` para 300s
- `server/app/main.py` endpoint `analise-visual`: adicionar try/except mais robusto com logging
- Testar localmente com `curl` antes de deploy

### 6A.3: Fix endpoint enriquecer-checklist (connection abort)
**Problema:** Mesmo issue de timeout. Batch enrichment pode levar vários minutos.

**Ações:**
- Mesmo fix de timeout do 6A.2
- Considerar tornar async (background task) com polling, similar ao checklist inteligente. Mas por agora, aumentar timeout resolve.

### 6A.4: Campo m² no cadastro da obra
**Arquivos Backend:**
- `server/app/models.py` Obra: adicionar `area_m2: Optional[float] = None`
- `server/app/schemas.py` ObraCreate/ObraUpdate: adicionar `area_m2`
- Nova migration Alembic

**Arquivos Flutter:**
- `mobile/lib/models/obra.dart`: adicionar `double? areaM2`
- `mobile/lib/screens/obras/obras_screen.dart`: adicionar campo m² no dialog de criação
- `mobile/lib/services/api_client.dart`: passar `area_m2` na criação

---

## FASE 6B — Checklist UX (Compactar + Despesas + Origem)
> Melhorias de UX na tela principal do checklist.

### 6B.1: Checklist compactado por categoria (expand/collapse)
**Arquivo:** `mobile/lib/screens/checklist/checklist_screen.dart`

**Mudança:** Trocar `_GrupoHeader` + lista de items por `ExpansionTile` por grupo. Estado colapsado por default. Header mostra: nome do grupo, contagem (3/7), botão "+" despesa.

**Implementação:**
- Converter `_ChecklistScreenState` para manter `Set<String> _expandedGroups`
- Cada grupo: `ExpansionTile` com header mostrando nome + stats
- Itens só renderizados quando expandido
- Manter pull-to-refresh

### 6B.2: Adicionar despesas por categoria direto no checklist
**Arquivo:** `mobile/lib/screens/checklist/checklist_screen.dart`

**Mudança:** No header de cada grupo, adicionar ícone `$` que abre `LancarDespesaScreen` pre-preenchendo a categoria com o nome do grupo.

**Ações:**
- Adicionar botão `Icons.attach_money` no header do grupo
- Ao clicar, navegar para `LancarDespesaScreen(categoria: grupoNome, etapaId: etapa.id)`
- `LancarDespesaScreen`: aceitar `categoria` como parâmetro opcional e pre-preencher

### 6B.3: Mostrar documento de origem no item do checklist
**Problema:** ChecklistItem tem `origem: "padrao" | "ia"` mas não guarda qual documento gerou o item.

**Backend:**
- `server/app/models.py` ChecklistItem: adicionar `projeto_doc_id: Optional[UUID]` e `projeto_doc_nome: Optional[str]`
- `server/app/checklist_inteligente.py`: ao gerar itens de documentos, salvar o `projeto_doc_id` e nome
- `server/app/main.py` endpoint aplicar-checklist/aplicar-riscos: propagar `projeto_doc_id`
- Migration Alembic

**Flutter:**
- `mobile/lib/models/checklist_item.dart`: adicionar `String? projetoDocId`, `String? projetoDocNome`
- `mobile/lib/screens/checklist/detalhe_item_screen.dart`: mostrar discretamente "Origem: [nome doc]" abaixo do header
- `mobile/lib/screens/checklist/checklist_screen.dart`: no `_ItemCard`, mostrar ícone documento se `projetoDocNome != null`

### 6B.4: Filtro no Planejamento (checklist) por origem
**Arquivo:** `mobile/lib/screens/checklist/checklist_screen.dart`

**Mudança:** Adicionar `FilterChip` row no topo: "Todos", "Padrão", "IA", e por documento (se houver).

**Implementação:**
- State: `String? _filtroOrigem` (null = todos, "padrao", "ia", ou docId)
- Extrair lista de documentos únicos dos items
- Filtrar items antes de agrupar
- Chips horizontais scrolláveis no topo

---

## FASE 6C — Info Enriquecida no Detalhe do Item (via Obra)
> As informações ricas da IA devem aparecer ao navegar pelo menu Obra, não só no Checklist Inteligente.

### 6C.1: Mostrar "como verificar", "medidas mínimas", "porque é importante" no detalhe do item
**Arquivo:** `mobile/lib/screens/checklist/detalhe_item_screen.dart`

**Problema:** Estes campos (`como_verificar`, `medidas_minimas`, `explicacao_leigo`) existem no `ChecklistGeracaoItem` mas NÃO são copiados para o `ChecklistItem` quando aplicados.

**Backend:**
- `server/app/models.py` ChecklistItem: adicionar `como_verificar: Optional[str]`, `medidas_minimas: Optional[str]`, `explicacao_leigo: Optional[str]`
- `server/app/main.py` endpoint `aplicar-checklist`: copiar estes 3 campos do `ChecklistGeracaoItem` para o `ChecklistItem`
- `server/app/checklist_inteligente.py` enrichment: preencher estes campos também
- Migration Alembic

**Flutter:**
- `mobile/lib/models/checklist_item.dart`: adicionar 3 campos
- `mobile/lib/screens/checklist/detalhe_item_screen.dart`: adicionar 3 blocos expansíveis:
  - "Como verificar" (ícone checklist, cor azul)
  - "Medidas mínimas" (ícone straighten, cor teal)
  - "Por que é importante" (ícone lightbulb, já existe como `traducaoLeigo` mas renomear visualmente)

### 6C.2: "O que o projeto diz" com especificações detalhadas
**Já implementado** no `detalhe_item_screen.dart` L277-318 como `_BlocoExpansivel`. O conteúdo depende da qualidade do `dado_projeto` retornado pela IA.

**Melhoria no backend:**
- `server/app/checklist_inteligente.py`: no prompt de geração, enfatizar que `dado_projeto.especificacao` deve conter valores concretos extraídos do projeto (ex: "2 ralos de fundo na piscina a 2m um do outro")
- Adicionar `valor_referencia` no bloco dado_projeto para mostrar na UI

### 6C.3: "Verifique na obra" com referência ao projeto ou norma
**Já implementado** no `detalhe_item_screen.dart` L321-398.

**Melhoria no backend:**
- `server/app/checklist_inteligente.py`: no prompt, pedir que `verificacoes[].instrucao` referencie o projeto quando disponível (ex: "os ralos devem estar a 2m de distância conforme projeto") ou a norma quando o projeto não detalha

---

## FASE 6D — Análise Visual IA (Seleção + Integração Checklist)
> Melhorar fluxo de análise de fotos.

### 6D.1: Selecionar etapa + categoria na análise de foto (aba IA)
**Arquivo:** `mobile/lib/screens/ia/ia_hub_screen.dart` método `_selecionarEtapaParaFoto`

**Mudança:** Após selecionar etapa, mostrar segundo dialog para selecionar categoria (grupo) do checklist. Passar como contexto para a análise.

**Backend:**
- `server/app/main.py` endpoint `analise-visual`: aceitar parâmetro opcional `grupo: str` para contextualizar a análise

**Flutter:**
- `ia_hub_screen.dart`: após selecionar etapa, carregar grupos disponíveis via `listarItens(etapa.id)` e mostrar dialog de seleção
- `visual_ai_screen.dart`: aceitar `grupo` opcional e passar para API

### 6D.2: Oferecer análise IA ao tirar foto no checklist item
**Arquivo:** `mobile/lib/screens/checklist/detalhe_item_screen.dart` método `_adicionarEvidencia`

**Mudança:** Após upload de foto (camera), mostrar dialog: "Deseja analisar esta foto com IA?"

**Implementação:**
- Após `uploadEvidenciaImagem` com sucesso (se source == camera):
  - Dialog: "Analisar foto com IA?" [Sim] [Não]
  - Se sim: chamar `api.enviarAnaliseVisual(etapaId: _item.etapaId, image: img)` e mostrar resultado
  - Ou navegar para `VisualAiScreen` com a última análise pré-carregada

---

## FASE 6E — Documentos + Checklist Inteligente Melhorias

### 6E.1: Click no documento → navegar para tab Obra
**Arquivo:** `mobile/lib/screens/documentos/documentos_screen.dart`

**Mudança:** Ao clicar num documento na lista, ao invés de abrir PDF viewer diretamente, navegar para a tab "Obra" (index 1) e selecionar a etapa relevante.

**Implementação:**
- Usar callback para `HomeScreen` trocar tab: `Navigator.of(context, rootNavigator: true)` ou usar um provider/callback
- Alternativa simples: manter o clique abrindo o PDF viewer, mas adicionar botão "Ver na Obra" que faz `Navigator.pop` até root e troca tab

### 6E.2: Selecionar documentos para análise no Gerar Checklist IA
**Arquivo:** `mobile/lib/screens/checklist_inteligente/checklist_inteligente_screen.dart`

**Mudança:** Antes de iniciar a geração, mostrar lista de documentos com checkbox para o usuário escolher quais analisar. Se já analisado, mostrar aviso e perguntar se quer repetir.

**Backend:**
- `server/app/main.py` endpoint `iniciar` checklist inteligente: aceitar `projeto_ids: List[UUID]` opcional
- `server/app/checklist_inteligente.py`: filtrar apenas os documentos selecionados

**Flutter:**
- Antes da tela de progresso, mostrar tela de seleção de documentos
- Marcar documentos já analisados com badge "Já analisado"
- Confirmar re-análise se necessário

### 6E.3: "Selecionar todos" no Enriquecer Checklist + só itens padrão
**Arquivo:** `mobile/lib/screens/ia/ia_hub_screen.dart` método `_selecionarEtapaParaEnriquecer`

**Mudança:**
1. Adicionar opção "Todas as etapas" no dialog de seleção
2. Backend já filtra itens padrão (origem == "padrao" e não enriquecidos)
3. Se selecionar "Todas", fazer loop por todas etapas

**Backend:**
- Verificar que `enriquecer-checklist` já filtra por `origem == "padrao"` — se não, adicionar filtro
- Novo endpoint `POST /api/obras/{obra_id}/enriquecer-todos` que itera todas etapas

---

## FASE 6F — Detalhamento da Obra (Cômodos + m²)

### 6F.1: Análise IA extrai cômodos e metragem
**Backend:**
- `server/app/documentos.py` ou `checklist_inteligente.py`: no prompt de análise, pedir extração de:
  - Lista de cômodos com nome e m² de cada
  - Metragem total da obra
- Salvar em nova tabela ou campo JSON na `Obra`: `detalhamento: Optional[str]` (JSON)

**Nova tabela (ou campo JSON):**
```
ObraDetalhamento:
  obra_id, comodos (JSON: [{nome, area_m2}]), area_total_m2, fonte_doc_id
```

**Endpoint novo:**
- `GET /api/obras/{obra_id}/detalhamento` — retorna cômodos e metragens extraídas

### 6F.2: Tela de detalhamento da obra (substituir botão análise IA no topo)
**Arquivo:** `mobile/lib/screens/etapas/etapas_screen.dart`

**Mudança:** No AppBar da tela de Obra/Etapas, substituir ou complementar o botão de análise IA por um botão "Detalhes da casa" que mostra:
- m² total
- Lista de cômodos com m²
- Origem (documento X)

**Flutter:**
- Nova tela ou bottom sheet: `ObraDetalhamentoSheet`
- Botão no AppBar de `EtapasScreen`: ícone `Icons.home_outlined` → abre sheet
- Mostra dados de `GET /api/obras/{obra_id}/detalhamento`

### 6F.3: Editar previsto/realizado financeiro na tela de etapas
**Arquivo:** `mobile/lib/screens/etapas/etapas_screen.dart`

**Mudança:** No card de cada etapa, ao clicar na barra financeira (ou no ícone), abrir bottom sheet com:
- Campo: Valor Previsto (R$)
- Campo: Valor Realizado (R$)
- Botão Salvar → `POST /api/obras/{obra_id}/orcamento`

**Implementação:**
- Adicionar `_editarFinanceiro(Etapa etapa)` method
- Bottom sheet com 2 TextFields (currency formatted)
- Chamar `api.salvarOrcamento(obraId, etapaId, previsto, realizado)`
- Refresh etapas após salvar

---

## Ordem de Implementação

| Fase | Items | Estimativa | Dependências |
|------|-------|-----------|-------------|
| **6A** | Bugs + m² | Backend deploy necessário | Nenhuma |
| **6B** | Checklist UX | Flutter only (exceto 6B.3) | 6A (migration) |
| **6C** | Info enriquecida | Backend + Flutter | 6A (migration) |
| **6D** | Visual AI | Backend + Flutter | 6A (timeout fix) |
| **6E** | Docs + Checklist IA | Backend + Flutter | 6A |
| **6F** | Detalhamento obra | Backend + Flutter | 6A (m² campo) |

## Migrations Necessárias (1 migration consolidada)

```sql
-- Obra: adicionar area_m2
ALTER TABLE obra ADD COLUMN area_m2 FLOAT;

-- ChecklistItem: novos campos
ALTER TABLE checklistitem ADD COLUMN projeto_doc_id UUID REFERENCES projetodoc(id);
ALTER TABLE checklistitem ADD COLUMN projeto_doc_nome VARCHAR;
ALTER TABLE checklistitem ADD COLUMN como_verificar TEXT;
ALTER TABLE checklistitem ADD COLUMN medidas_minimas TEXT;
ALTER TABLE checklistitem ADD COLUMN explicacao_leigo TEXT;

-- ObraDetalhamento: nova tabela
CREATE TABLE obradetalhamento (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  obra_id UUID NOT NULL REFERENCES obra(id),
  comodos TEXT, -- JSON
  area_total_m2 FLOAT,
  fonte_doc_id UUID REFERENCES projetodoc(id),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

## Verificação
1. **Bug Dono tag:** Cancelar assinatura → tag deve sumir, feature gates devem bloquear
2. **Análise visual:** Enviar foto → análise deve completar sem connection abort
3. **Checklist compacto:** Categorias colapsadas, expandir mostra items
4. **m² obra:** Criar obra com m², verificar no dashboard
5. **Filtro checklist:** Filtrar por "Padrão" e "IA" e por documento
6. **Info enriquecida:** Navegar item via Obra → ver "como verificar", "medidas mínimas"
7. **Detalhamento:** Após análise de documento, ver cômodos e m² extraídos
8. **Financeiro inline:** Editar valores na tela de etapas
9. Deploy backend → testar em produção
