# Setup Tasks (from PRODUCT_ROADMAP.md)

## Baseline
- [x] Create `docs/ROADMAP_TASKS.md` to track phases, epics, and acceptance checklists.
- [x] Add delivery checklist template (requisitos funcionais, dados de entrada/saida, criterios de aceite, riscos) for all handoffs.

## Fase 0 - Conteudo Base + Estrutura Normativa
- [x] Define taxonomia de etapas (6 etapas iniciais) and document in `docs/DOMAIN_TAXONOMY.md`.
- [x] Create etapa -> palavras-chave mapping and version in `docs/NORMATIVE_KEYWORDS.md`.
- [x] Document IA flow with entradas/saidas in `docs/IA_FLOW.md`.
- [x] Produce UX prototype notes for checklists and evidencias in `docs/UX_NOTES.md`.

Checklist de aceite:
- Taxonomia validada pelo Product.
- Mapeamento etapa -> palavras-chave aprovado e versionado.
- Fluxo IA documentado com entradas e saidas.
- Prototipo UX validado para checklists e evidencias.

## Fase 1 - MVP (sem IA normativa dinamica)
- Model entities: Obra, Etapa, ChecklistItem, Evidencia.
- Implement cadastro de obra.
- Auto-generate 6 etapas.
- Implement checklists fixos por etapa (CRUD).
- Implement upload de evidencias por item.
- Implement score por etapa.
- Implement exportacao PDF (obra + checklists + score).

Checklist de aceite:
- Obra criada com dados basicos.
- 6 etapas geradas automaticamente.
- Checklists fixos exibidos e editaveis.
- Upload de evidencias funcionando.
- Score por etapa calculado e exibido.
- PDF exportado com dados da obra e checklists.

## Fase 2 - IA Normativa Dinamica
- Implement classificador de etapa e disciplina.
- Implement motor de busca web de normas (>= 3 fontes).
- Implement parser de norma.
- Implement traducao leiga (nao parecer tecnico).
- Implement registro de versao, data e fonte.
- Implement checklist dinamico auditavel.
- Exibir nivel de confianca em toda analise.

Checklist de aceite:
- Motor de busca retorna >= 3 fontes por etapa.
- Parser extrai diretrizes relevantes.
- Fonte, data e versao exibidos ao usuario.
- Traducao leiga clara, sem parecer tecnico.
- Checklist dinamico gerado e auditavel.
- Nivel de confianca visivel em toda analise.

## Fase 3 - IA Documental
- Implement upload, armazenamento e indexacao de PDFs.
- Extracao textual estruturada por secao.
- Identificacao de riscos com severidade.
- Relatorio com fonte normativa e nivel de confianca.

Checklist de aceite:
- PDF enviado, armazenado e indexado.
- Texto extraido estruturado por secao.
- Riscos identificados com severidade.
- Relatorio com fonte normativa e nivel de confianca.

## Fase 4 - IA Visual
- Implement upload de imagem.
- Classificacao de etapa por imagem (meta >= 90% no dataset interno).
- Geracao de achados com severidade e acao recomendada.
- Solicitar evidencias adicionais quando aplicavel.

Checklist de aceite:
- Upload de imagem funcional.
- Classificacao de etapa com meta >= 90%.
- Achados com severidade e acao recomendada.
- Solicita evidencias adicionais quando aplicavel.

## Fase 5 - Financeiro Premium
- Cadastro de orcamento por etapa.
- Previsto x realizado e calculo de desvio.
- Curva S.
- Alertas de desvio configuraveis.
- Relatorio executivo consolidado.

Checklist de aceite:
- Orcamento por etapa cadastrado.
- Desvio calculado e exibido.
- Curva S gerada.
- Alertas de desvio configuraveis.
- Relatorio executivo consolidado.

## Guardrails (globais)
- Indicar data, fonte e versao da norma em toda analise normativa.
- Informar se a fonte e oficial ou secundaria.
- Nao apresentar como parecer tecnico.
- Mostrar nivel de confianca.
- Logar versao da norma e data de consulta.
- Evidencia obrigatoria para itens criticos.
- Achados de risco alto exigem recomendacao clara e solicitacao de validacao profissional.
