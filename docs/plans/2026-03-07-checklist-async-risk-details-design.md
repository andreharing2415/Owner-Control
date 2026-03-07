# Design: Checklist Inteligente Async + Detalhe de Riscos Enriquecido

**Data:** 2026-03-07
**Status:** Aprovado

## Problema

1. O processamento do checklist inteligente e sincrono via SSE. Se o usuario sair da tela, perde todo o progresso e precisa recomecar.
2. A tela de detalhe de riscos nao tem link para a norma referenciada.
3. As instrucoes na tela de riscos sao tecnicas demais para um proprietario leigo. Nao dizem o que ele deve fazer concretamente.

## Solucao

### 1. Checklist Inteligente — Processamento Assincrono em Background

#### Backend

- **Novo endpoint `POST /api/obras/{obra_id}/checklist-inteligente/iniciar`**
  - Cria um `ChecklistGeracaoLog` com status "processando"
  - Dispara processamento em background thread (`threading.Thread`)
  - Retorna imediatamente o `log_id` + status

- **Thread em background**
  - Roda o pipeline existente (`gerar_checklist_stream`)
  - Salva resultados incrementais no banco (nova tabela `ChecklistGeracaoItem`)
  - Atualiza `ChecklistGeracaoLog` com progresso, caracteristicas, e status final

- **Novo endpoint `GET /api/obras/{obra_id}/checklist-inteligente/{log_id}/status`**
  - Retorna status atual do job: progresso (paginas processadas/total), caracteristicas encontradas, itens gerados
  - Inclui os itens ja gerados ate o momento

- **Endpoint SSE existente** mantido como opcional para acompanhamento ao vivo

- **Endpoint de historico** ja existe e lista todos os logs

#### Nova tabela `ChecklistGeracaoItem`

```
id              UUID PK
log_id          UUID FK -> checklistgeracaolog.id
etapa_nome      str
titulo          str
descricao       str
norma_referencia str | null
critico         bool
risco_nivel     str  (alto/medio/baixo)
requer_validacao_profissional bool
confianca       int  (0-100)
como_verificar  str
medidas_minimas str | null
explicacao_leigo str
caracteristica_origem str
created_at      datetime
```

#### Frontend (nova tela de Checklist Inteligente)

- Lista de jobs em andamento e concluidos (endpoint de historico)
- Cada job mostra: status (processando/concluido/erro), data, caracteristicas, total de itens
- Botao "Gerar Novo Checklist" dispara `POST /iniciar`
- Polling a cada 5s no job ativo para atualizar progresso
- Ao clicar num job concluido, mostra itens sugeridos para revisar e aplicar

### 2. Detalhe dos Riscos — Link para a Norma

- Adicionar campo `norma_url` no prompt da IA (documentos.py) para a IA retornar URL quando disponivel
- Adicionar campo `norma_url` no model `Risco` e schema `RiscoRead`
- No frontend, botao "Ver na Norma" abre a URL retornada pela IA
- Fallback: se nao tiver URL, gerar link de busca Google: `https://www.google.com/search?q=ABNT+{norma_referencia}`

### 3. Detalhe dos Riscos — Instrucoes para Proprietario Leigo

#### Novos campos no prompt da IA e no model Risco:

- **`acao_proprietario`**: Instrucao direta e especifica do que pedir ao engenheiro/arquiteto, sem linguagem tecnica
- **`perguntas_para_profissional`**: Lista de 2-3 perguntas que o proprietario deve fazer ao engenheiro. Cada pergunta inclui o que o proprietario deve esperar ouvir como resposta satisfatoria (nao a frase exata, mas a mensagem-chave)
- **`documento_a_exigir`**: Documento ou laudo que o proprietario deve cobrar (ex: "Peca ao engenheiro o laudo de sondagem do solo atualizado", "Solicite ART/RRT para esta atividade"). Listados quando aplicavel.

#### Frontend (DocumentAnalysis.tsx):

Cada finding expandido mostra:

- **"O que isso significa?"** — traducao em linguagem simples (campo traducao_leigo existente)
- **"O que voce deve fazer?"** — acao_proprietario
- **"Pergunte ao seu engenheiro:"** — lista de perguntas com indicacao da resposta esperada
- **"Documento a exigir:"** — lista de documentos/laudos a cobrar
- **Link para a norma** — botao funcional

#### Exemplo concreto:

**Antes:** "O detalhe 04/02 especifica recobrimento de 3cm, mas a NBR 6122 exige 4cm para este tipo de solo."

**Depois:**

> **O que isso significa?** O "recobrimento" e a camada de concreto que protege o ferro da fundacao. Se for fino demais, a ferragem pode enferrujar e comprometer a estrutura da casa.
>
> **O que voce deve fazer:** Peca ao seu engenheiro estrutural que revise o detalhe 04/02 do projeto e corrija o recobrimento para no minimo 4cm.
>
> **Pergunte ao engenheiro:**
> - "O recobrimento dos blocos B4 e B5 esta adequado para o tipo de solo do nosso terreno?"
>   → Resposta esperada: ele deve confirmar que o recobrimento atende a norma NBR 6122 para a classe de agressividade do solo
> - "Voce pode emitir uma revisao do projeto corrigindo esse ponto?"
>   → Resposta esperada: sim, com nova ART registrada no CREA
>
> **Documento a exigir:**
> - Revisao do projeto estrutural (detalhe 04/02) com ART atualizada
> - Laudo de sondagem do solo (se nao houver um recente)
>
> **Norma:** NBR 6122:2022 [Ver norma completa →]

## Arquivos a modificar

### Backend
- `server/app/models.py` — novo model ChecklistGeracaoItem, novos campos em Risco
- `server/app/schemas.py` — novos schemas
- `server/app/main.py` — novos endpoints (iniciar, status)
- `server/app/checklist_inteligente.py` — versao background do pipeline
- `server/app/documentos.py` — prompt enriquecido com novos campos
- `server/alembic/` — migracao para novos campos/tabelas

### Frontend
- `client/src/pages/Checklists.tsx` — nova tela com lista de jobs
- `client/src/pages/DocumentAnalysis.tsx` — findings enriquecidos + link norma
- `client/src/lib/mock-data.ts` — mock data atualizado
