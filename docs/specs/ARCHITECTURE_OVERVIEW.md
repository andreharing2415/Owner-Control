# Architecture Overview (MVP Focus)

## Escopo
Fase 1 MVP com base para Fase 2. Sem IA normativa dinamica ainda, mas com pontos de extensao.

## Modulos (Frontend)
- Onboarding e cadastro de obra.
- Linha do tempo e etapas.
- Checklists por etapa.
- Evidencias por item.
- Score e relatorio PDF.
- Biblioteca normativa (placeholder com avisos de versao e fonte).

## Modulos (Backend)
- API de obras, etapas, checklists e evidencias.
- Armazenamento de arquivos (fotos e PDFs).
- Servico de score por etapa.
- Exportacao PDF.
- Logs de norma (fonte, data, versao, confianca).

## Entidades (Banco)
- obra: id, nome, local, datas, orcamento_total.
- etapa: id, obra_id, nome, status, ordem.
- checklist: id, etapa_id, tipo, versao.
- checklist_item: id, checklist_id, titulo, criticidade, status.
- evidencia: id, checklist_item_id, arquivo_url, comentario, data.
- score_etapa: id, etapa_id, valor, calculo.
- norma_log: id, etapa_id, fonte, data_consulta, versao, confianca, oficial_ou_secundaria.
- usuario: id, nome, email, papel.
- projeto_doc: id, obra_id, arquivo_url, status.
- risco: id, obra_id, origem, severidade, descricao, confianca.

## Endpoints (Base)
- POST /api/obras
- GET /api/obras/:id
- POST /api/obras/:id/etapas
- PATCH /api/etapas/:id/status
- GET /api/etapas/:id/checklist
- POST /api/checklist-itens/:id/evidencias
- GET /api/etapas/:id/score
- GET /api/obras/:id/relatorio

## Pontos de extensao para Fase 2
- /api/normas/search
- /api/normas/parse
- /api/normas/log
- checklist dinamico por norma

## Regras de Produto (Guardrails)
- Sempre exibir fonte, data e versao da norma quando houver analise normativa.
- Informar se fonte e oficial ou secundaria.
- Nao apresentar como parecer tecnico.
- Exibir nivel de confianca.
- Logar versao e data de consulta.
- Evidencia obrigatoria para itens criticos.

## Dados de Entrada e Saida (MVP)
Entrada:
- Dados da obra, etapas, checklist, evidencias (foto).
Saida:
- Checklist atualizado, score por etapa, relatorio PDF.
