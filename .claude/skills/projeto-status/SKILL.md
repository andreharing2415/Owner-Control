---
name: projeto-status
description: Mostra o status atual do projeto ObraMaster Owner Control — telas implementadas, pendentes e próximos passos. Use para ter uma visão rápida do progresso. Ative sempre que ouvir "status", "progresso", "o que falta", "fase atual", "próximos passos" ou "o que foi feito".
disable-model-invocation: false
context: fork
agent: Explore
---

# Status do projeto ObraMaster Owner Control

## Estado atual do código

- Branch atual: !`git -C "C:/Project/ObraMaster/Owner-Control/.claude/worktrees/brave-lovelace" branch --show-current 2>/dev/null`
- Commits recentes: !`git -C "C:/Project/ObraMaster/Owner-Control/.claude/worktrees/brave-lovelace" log --oneline -8 2>/dev/null`
- Arquivos modificados: !`git -C "C:/Project/ObraMaster/Owner-Control/.claude/worktrees/brave-lovelace" status --short 2>/dev/null`

Analise o projeto em `C:\Project\ObraMaster\Owner-Control\.claude\worktrees\brave-lovelace` e produza um relatório de status com:

## 1. Telas Flutter implementadas (`lib/screens/`)

Para cada tela, indique:
- ✅ Implementada e funcional
- 🔄 Em andamento / incompleta
- ❌ Planejada mas não iniciada

Telas conhecidas do projeto:
- `obras_screen.dart` — listagem de obras
- `etapas_screen.dart` — etapas de uma obra
- `checklist_screen.dart` — checklist de uma etapa
- `evidencias_screen.dart` — evidências de um item
- `normas_screen.dart` — busca de normas técnicas
- `normas_historico_screen.dart` — histórico de consultas de normas
- `financial_screen.dart` — financeiro
- `timeline_screen.dart` — linha do tempo
- `documents_screen.dart` — documentos
- `document_analysis_screen.dart` — análise de documentos
- `home_screen.dart` — home
- `projects_screen.dart` — projetos (visão proprietário)
- `settings_screen.dart` — configurações
- `main_shell.dart` — shell de navegação

## 2. API client (`lib/api/api.dart`)

Liste os métodos disponíveis e quais endpoints do backend eles consomem.

## 3. Backend (`server/app/main.py` no repo principal)

Se acessível, liste os endpoints FastAPI implementados.

## 4. Gaps críticos

O que está faltando para o MVP estar 100% funcional?

## 5. Próxima ação recomendada

Qual é o próximo item de maior impacto a implementar?

Seja conciso e use tabelas/listas onde ajudar a clareza.
