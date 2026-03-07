# Domain Taxonomy - Etapas de Obra

## Objetivo
Definir as 6 etapas iniciais da obra e os criterios basicos de classificacao para uso em checklists, evidencias e IA normativa.

## Requisitos funcionais
- Permitir classificar uma obra em 6 etapas padrao.
- Associar cada etapa a um conjunto de disciplinas e tipos de evidencias esperadas.
- Servir de base para geracao automatica de etapas no cadastro de obra.

## Dados de entrada
- Tipo de obra (residencial, comercial, industrial).
- Porte (pequeno, medio, grande).
- Localizacao (UF/cidade).

## Dados de saida
- Lista de 6 etapas padrao com descricao e disciplinas associadas.
- Regras de classificacao basicas por etapa.

## Etapas padrao (v1)
1. Planejamento e Projeto
2. Preparacao do Terreno
3. Fundacoes e Estrutura
4. Alvenaria e Cobertura
5. Instalacoes e Acabamentos
6. Entrega e Pos-obra

## Definicoes e disciplinas
1. Planejamento e Projeto
Descricao: definicao de escopo, projetos executivos e licencas.
Disciplinas: arquitetura, estrutural, eletrica, hidraulica, legal.
Evidencias tipicas: documentos de projeto, alvaras, memoriais.

2. Preparacao do Terreno
Descricao: limpeza, demarcacao, terraplanagem e acessos.
Disciplinas: topografia, terraplanagem, meio ambiente, seguranca.
Evidencias tipicas: fotos do terreno, laudos, licencas ambientais.

3. Fundacoes e Estrutura
Descricao: fundacoes, pilares, vigas, lajes e estrutura primaria.
Disciplinas: estrutural, geotecnia, concreto, seguranca.
Evidencias tipicas: fotos de armaduras, notas de concreto, ensaios.

4. Alvenaria e Cobertura
Descricao: paredes, vedacoes, telhados e impermeabilizacoes.
Disciplinas: alvenaria, impermeabilizacao, cobertura.
Evidencias tipicas: fotos de paredes, testes de estanqueidade.

5. Instalacoes e Acabamentos
Descricao: instalacoes eletricas/hidraulicas e acabamentos finais.
Disciplinas: eletrica, hidraulica, HVAC, acabamentos.
Evidencias tipicas: fotos de quadros, testes, notas de materiais.

6. Entrega e Pos-obra
Descricao: vistorias finais, entrega e garantia.
Disciplinas: qualidade, seguranca, documental.
Evidencias tipicas: checklists finais, termo de entrega, as built.

## Regras de classificacao basicas
- Se ha documentos de projeto e licencas em validacao, classificar como Planejamento e Projeto.
- Se ha atividade de terraplanagem e limpeza ativa, classificar como Preparacao do Terreno.
- Se ha execucao de fundacoes ou estrutura primaria, classificar como Fundacoes e Estrutura.
- Se ha vedacoes/cobertura em execucao, classificar como Alvenaria e Cobertura.
- Se ha instalacoes e acabamentos simultaneos, classificar como Instalacoes e Acabamentos.
- Se ha vistorias finais e entrega, classificar como Entrega e Pos-obra.

## Criterios de aceite
- 6 etapas padrao definidas e aprovadas pelo Product.
- Disciplinas e evidencias tipicas associadas a cada etapa.
- Regras basicas de classificacao documentadas.

