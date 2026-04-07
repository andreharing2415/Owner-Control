---
phase: 4
plan: "04-03"
subsystem: cronograma-alerts
tags: [deadline, atraso, fcm, cronograma]
requirements_completed: [NOTIF-01, NOTIF-02]
completed_date: "2026-04-06"
---

# Phase 4 Plan 03 Summary

Consolidado motor de alertas de cronograma para atraso de atividade e proximidade de prazo final com disparo via FCM.

## Entregas

- Serviço de alertas de cronograma com regras:
- atividade não concluída com data fim prevista vencida gera alerta de atraso;
- obra com prazo final em até 7 dias gera alerta preventivo.
- Endpoint para verificar e disparar alertas de cronograma por obra.
- Payload de push inclui contexto para consumo no app (tipo, subtipo, obra e atividade).
- NotificationService no app com listeners de dados para consumo de payload de notificação.

## Arquivos principais

- server/app/services/cronograma_alert_service.py
- server/app/routers/cronograma.py
- server/app/notifications.py
- lib/services/notification_service.dart
- lib/api/api.dart

## Validação

- Testes de backend adicionados em server/tests/test_rdo_alerts.py.
- Backend (Python 3.12 venv):
- `pytest -q tests/test_rdo_alerts.py` → 5 passed.
- `pytest -q tests -k "rdo or alert"` → 8 passed, 274 deselected.

## Resultado

A base de alertas proativos está ativa: o backend identifica atraso/prazo e dispara push com contexto para orientar ação do engenheiro.
