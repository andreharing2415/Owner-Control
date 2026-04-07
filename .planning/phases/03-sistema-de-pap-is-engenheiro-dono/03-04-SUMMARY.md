---
phase: 3
plan: "03-04"
subsystem: flutter-routing
tags: [go_router, shellroute, role-gated, navigation]
requirements_completed: [ROLE-02, OWNER-03]
completed_date: "2026-04-07"
---

# Phase 3 Plan 04 Summary

Migracao de navegacao para `go_router` com ShellRoute condicionado por papel.

## Entregas

- Criado `AppRouter` com guard de autenticacao e guard por papel.
- Separacao de shells:
  - shell de engenheiro (`/`, `/obras`, `/documentos`, `/prestadores`, `/config`)
  - shell de dono (`/owner`, `/owner/config`)
- Integracao no bootstrap do app com `MaterialApp.router`.
- Deep links internos respeitando papel (redirecionamento de owner para `/owner` e bloqueio de rotas de gestao).

## Arquivos

- `lib/routes/app_router.dart`
- `lib/main.dart`
- `lib/screens/main_shell.dart`

## Validacao

Comando executado:

```bash
C:\flutter\bin\flutter.bat test test/home_screen_test.dart test/widget_test.dart
```

Resultado: todos os testes executados passaram.

## Resultado

Aplicativo abre o shell correto com base no papel do token e evita navegacao indevida entre perfis.
