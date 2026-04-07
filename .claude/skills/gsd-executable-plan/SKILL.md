---
name: gsd-executable-plan
description: Endurece a geração de planos GSD executáveis para /gsd:execute-phase. Use quando houver menção a "plan-phase", "execute-phase", "plano não reconhecido", "PLAN.md", "fase não executa" ou "ajustar skill de planejamento". Garante formato canônico com arquivos *-PLAN.md, frontmatter obrigatório e tarefas XML.
disable-model-invocation: false
---

# GSD Executable Plan Guard

Objetivo: garantir que todo plano gerado seja executável pelo parser do GSD.

## Regras obrigatórias

1. Nunca gerar apenas `PLAN.md` para execução de fase.
2. Gerar 1 arquivo por plano no padrão: `<plan-id>-PLAN.md`.
3. Cada arquivo deve conter frontmatter com campos obrigatórios:
- `phase`
- `plan`
- `type`
- `wave`
- `depends_on`
- `files_modified`
- `autonomous`
- `must_haves`
4. Cada plano deve conter bloco `<tasks>` com `<task>` e, em cada tarefa:
- `<name>`
- `<files>`
- `<action>`
- `<verify>`
- `<done>`
5. Sempre mapear requirements no frontmatter (`requirements`) e manter `depends_on` coerente com `wave`.
6. Validar antes de finalizar:
- `node $HOME/.claude/get-shit-done/bin/gsd-tools.cjs phase-plan-index <phase>` deve listar planos sem erro.
- `node $HOME/.claude/get-shit-done/bin/gsd-tools.cjs verify plan-structure <arquivo>` deve retornar `valid`.

## Convenções recomendadas

- IDs de plano no formato `00-01`, `00-02`, `00-03` para fase 0.
- `autonomous: true` por padrão; usar `false` apenas com checkpoint real.
- `wave` incremental conforme dependências reais.

## Resultado esperado

- `/gsd:execute-phase <n>` reconhece todos os planos da fase.
- `phase-plan-index` retorna `task_count > 0` e `has_summary: false` para planos novos.
