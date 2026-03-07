---
name: projeto-status
description: Mostra o status atual do projeto Mestre da Obra — fases implementadas, pendentes e próximos passos. Use para ter uma visão rápida do progresso.
disable-model-invocation: false
context: fork
agent: Explore
---

# Status do projeto Mestre da Obra

## Estado atual do código
- Commits recentes: !`git -C C:\Project\ObraMaster\Owner-Control log --oneline -8 2>/dev/null`
- Arquivos modificados: !`git -C C:\Project\ObraMaster\Owner-Control status --short 2>/dev/null`

Analise o projeto em `C:\Project\ObraMaster\Owner-Control` e produza um relatório de status com:

## 1. Roadmap de fases (docs/SETUP_TASKS.md e docs/specs/PRODUCT_ROADMAP.md)

Para cada fase (0 a 5), indique:
- ✅ Implementado
- 🔄 Em andamento
- ❌ Não iniciado

## 2. Backend (server/app/)

Liste os endpoints disponíveis em `main.py` e compare com os esperados em `docs/specs/ARCHITECTURE_OVERVIEW.md`.

## 3. Flutter (mobile/lib/)

Liste as telas existentes em `main.dart` e os métodos de API disponíveis em `api.dart`.

## 4. Gaps críticos

O que está faltando para o MVP (Fase 1) estar 100% funcional?

## 5. Próxima ação recomendada

Qual é o próximo item de maior impacto a implementar?

Seja conciso e use tabelas/listas onde ajudar a clareza.
