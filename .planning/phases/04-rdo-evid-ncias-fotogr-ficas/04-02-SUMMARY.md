---
phase: 4
plan: "04-02"
subsystem: evidence-geotag
tags: [geolocator, evidencias, cronograma, metadata]
requirements_completed: [RDO-04, FOTO-01, FOTO-02]
completed_date: "2026-04-06"
---

# Phase 4 Plan 02 Summary

Implementada captura automática de metadados de evidência (geolocalização e timestamp) e vínculo opcional a atividade do cronograma.

## Entregas

- App Flutter:
- Serviço de metadados de evidência para coletar latitude, longitude e horário de captura.
- Upload de imagem no checklist atualizado para enviar metadados automaticamente.
- Fluxo para vincular a evidência a uma atividade específica do cronograma durante o upload.

- Plataforma:
- Dependência geolocator adicionada no app.
- Permissões de localização configuradas para Android e iOS.

- Backend já preparado e integrado:
- Endpoint de upload de evidência recebe atividade_id, latitude, longitude e capturado_em.
- Modelo e schema de evidência expõem os campos de metadados.

## Arquivos principais

- lib/services/evidence_metadata_service.dart
- lib/screens/checklist_screen.dart
- pubspec.yaml
- android/app/src/main/AndroidManifest.xml
- ios/Runner/Info.plist
- server/app/routers/etapas.py
- server/app/models.py
- server/app/schemas.py

## Validação

- Flutter tests: test/home_screen_test.dart e test/widget_test.dart passaram.
- Backend (Python 3.12 venv): `pytest -q tests -k "rdo or alert"` passou com 8 testes verdes.

## Resultado

Evidências fotográficas passam a nascer com timestamp e geotag automáticos no app e podem ser associadas a atividades específicas do cronograma.
