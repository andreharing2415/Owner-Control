# Produto Roadmap e Backlog (Resumo)

## Objetivo
Definir roadmap, fases, epics e stories com MoSCoW e criterios de aceite. Manter diferencial de IA normativa.

## Principios e Guardrails
- Indicar data, fonte e versao da norma em toda analise normativa.
- Informar se a fonte e oficial ou secundaria.
- Nao apresentar como parecer tecnico.
- Mostrar nivel de confianca.
- Logar versao da norma e data de consulta.
- Evidencia obrigatoria para itens criticos.
- Achados de risco alto exigem recomendacao clara e solicitacao de validacao profissional.

## MoSCoW Geral
| Must | Should | Could | Wont (inicial) |
| --- | --- | --- | --- |
| Estrutura da obra | IA visual | Benchmarking | BIM IFC avancado |
| Checklists | Curva S | Marketplace especialistas | DWG nativo |
| IA normativa dinamica | Alertas avancados |  |  |
| IA documental basica |  |  |  |
| Evidencias |  |  |  |

## Roadmap por Fases
### Fase 0 - Conteudo Base + Estrutura Normativa
Foco: taxonomia de etapas, mapeamento etapa -> palavras-chave, fluxo IA e prototipo UX.

Criterios de aceite:
- Taxonomia de etapas definida e validada pelo Product.
- Mapeamento etapa -> palavras-chave aprovado e versionado.
- Fluxo IA documentado com entradas e saidas.
- Prototipo UX validado para checklists e evidencias.

### Fase 1 - MVP (sem IA normativa dinamica)
Foco: cadastro de obra, 6 etapas, checklists fixos, evidencias por foto, score basico, exportacao PDF.

Criterios de aceite:
- Obra criada com dados basicos.
- 6 etapas geradas automaticamente.
- Checklists fixos por etapa exibidos e editaveis.
- Upload de evidencia por item funcionando.
- Score por etapa calculado e exibido.
- PDF exportado com dados da obra e checklists.

### Fase 2 - IA Normativa Dinamica
Foco: busca web de normas, parser, versao, traducao leiga e checklist dinamico.

Criterios de aceite:
- Motor de busca retorna pelo menos 3 fontes por etapa.
- Parser extrai diretrizes relevantes com estrutura.
- Registro de fonte, data e versao exibido ao usuario.
- Traducao leiga clara, sem parecer tecnico.
- Checklist dinamico gerado e auditavel.
- Nivel de confianca visivel em toda analise.

### Fase 3 - IA Documental
Foco: upload PDF, extracao, conflitos, cruzamento com normas, relatorio de risco.

Criterios de aceite:
- PDF enviado, armazenado e indexado.
- Texto extraido estruturado por secao.
- Riscos identificados com severidade.
- Relatorio com fonte normativa e nivel de confianca.

### Fase 4 - IA Visual
Foco: classificacao de etapa por imagem, anomalias, achados, solicitacao de evidencias.

Criterios de aceite:
- Upload de imagem funcional.
- Classificacao de etapa com meta >= 90% em dataset interno.
- Achados com severidade e acao recomendada.
- Solicita evidencias adicionais quando aplicavel.

### Fase 5 - Financeiro Premium
Foco: orcamento por etapa, previsto x realizado, curva S, alertas, relatorios executivos.

Criterios de aceite:
- Orcamento por etapa cadastrado.
- Desvio calculado e exibido.
- Curva S gerada.
- Alertas de desvio configuraveis.
- Relatorio executivo consolidado.

## Epics e Stories (Fase 1 e Fase 2 primeiro)
### EPIC A - Estrutura Base da Obra
Stories:
1. Criar entidade Obra.
2. Criar etapas padrao.
3. Atualizar status de etapa.

Dados de entrada:
- Nome da obra, datas, orcamento, local.

Dados de saida:
- Obra criada com id, etapas padrao e status inicial.

Criterios de aceite (epic):
- Obra salva e recuperavel.
- 6 etapas criadas automaticamente.
- Status persistido e auditavel.

### EPIC B - Checklists e Evidencias
Stories:
1. Checklist fixo por etapa.
2. Registro de evidencia por item.
3. Score por etapa.

Dados de entrada:
- Itens de checklist, fotos, comentarios, status por item.

Dados de saida:
- Itens vinculados a etapa, evidencias associadas, score calculado.

Criterios de aceite (epic):
- Itens exibidos por etapa.
- Evidencias vinculadas ao item.
- Score atualizado automaticamente.

### EPIC C - Biblioteca Normativa Dinamica
Stories:
1. Classificador de etapa e disciplina.
2. Motor de busca web de normas.
3. Parser de norma.
4. Traducao leiga.
5. Registro de versao, data e fonte.

Dados de entrada:
- Etapa, disciplina, palavras-chave, urls e textos normativos.

Dados de saida:
- Norma identificada com fonte, data, versao, confianca e checklist dinamico.

Criterios de aceite (epic):
- Retornar 3 fontes no minimo.
- Exibir fonte oficial ou secundaria.
- Logar versao e data de consulta.
- Checklist dinamico acionavel e auditavel.

### EPIC D - IA Documental
Stories:
1. Upload de projeto PDF.
2. Extracao textual.
3. Identificacao de riscos.
4. Checklist personalizado por projeto.

Dados de entrada:
- PDF, metadados do projeto.

Dados de saida:
- Texto extraido, riscos, checklist personalizado.

Criterios de aceite (epic):
- Extracao estruturada e rastreavel.
- Riscos priorizados e explicados em linguagem leiga.

### EPIC E - IA Visual
Stories:
1. Upload de imagem.
2. Classificacao de imagem.
3. Geracao de achados.

Dados de entrada:
- Imagens, metadados de contexto.

Dados de saida:
- Etapa inferida, achados e evidencias solicitadas.

Criterios de aceite (epic):
- Achados com severidade e acao recomendada.
- Nivel de confianca exibido.

### EPIC F - Financeiro
Stories:
1. Cadastro de orcamento.
2. Previsto x realizado.
3. Relatorio executivo.

Dados de entrada:
- Orcamento por etapa, despesas, contratos.

Dados de saida:
- Desvio, curva S, alertas.

Criterios de aceite (epic):
- Relatorio com dados consolidados.
- Alertas configuraveis.

## Riscos Altos e Handoff
- Qualquer achado de risco alto exige revisao do Product.
- Entregas devem incluir requisitos funcionais e dados de entrada/saida.
- Cada entrega deve vir com checklist de aceite.
