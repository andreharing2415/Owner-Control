---
status: partial
phase: 00-bloqueadores-criticos
source: [00-VERIFICATION.md]
started: 2026-04-06T23:30:00Z
updated: 2026-04-06T23:30:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Cold Start Latency — minInstanceCount Active
expected: Primeira requisição após 5+ min inativo responde em menos de 2s
result: [pending]

Steps:
1. `bash server/deploy-cloudrun.sh`
2. Aguardar 5+ minutos sem tráfego
3. `curl -w "%{time_total}" https://mestreobra-backend-530484413221.us-central1.run.app/health`
4. Confirmar que `time_total < 2.0`

### 2. PDF Character Rendering on Linux Docker
expected: Caracteres ã, ç, é, ê, õ, á, í, ó, ú aparecem corretamente no PDF (sem ? ou quadrados)
result: [pending]

Steps:
1. `docker build -t mestreobra-test server/`
2. `docker run -p 8080:8080 mestreobra-test`
3. Chamar `GET /api/obras/{id}/export-pdf` em uma obra com nome acentuado
4. Abrir o PDF e verificar caracteres

### 3. Stripe Cancel-Then-Period-End Full Cycle
expected: Usuário mantém plano pago após cancelar, só faz downgrade quando webhook `customer.subscription.deleted` chega
result: [pending]

Steps:
1. Criar assinatura em modo test do Stripe
2. Chamar `POST /api/subscription/cancel` — confirmar que plano continua `premium`
3. Simular `customer.subscription.deleted` via Stripe Dashboard (test mode)
4. Confirmar que usuário cai para `gratuito` após webhook

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
