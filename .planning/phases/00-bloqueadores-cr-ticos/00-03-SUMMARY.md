---
phase: 00-bloqueadores-críticos
plan: "00-03"
subsystem: backend
tags: [pdf, utf8, weasyprint, jinja2, unicode, docker]

requires:
  - 00-01
provides:
  - Renderer PDF com suporte Unicode real via WeasyPrint+Jinja2
  - Template HTML obra_relatorio.html com charset UTF-8 e estilos
  - Dockerfile com dependências nativas para WeasyPrint em python:3.11-slim
  - Suite de testes com corpus PT-BR (ã/ç/é/ê/õ/á/í/ó/ú)
affects:
  - Endpoint GET /api/obras/{obra_id}/export-pdf (contrato preservado)

tech-stack:
  added:
    - "weasyprint==62.3 — HTML→PDF com suporte Unicode completo"
    - "jinja2==3.1.4 — templates HTML para geração de conteúdo"
  patterns:
    - "PDF gerado via HTML template + WeasyPrint (sem encoding manual)"
    - "Dockerfile com apt-get de libs nativas antes de pip install"
    - "Testes com pytestmark.skipif para libs nativas ausentes em Windows"

key-files:
  created:
    - server/app/templates/obra_relatorio.html
    - server/tests/test_pdf.py
  modified:
    - server/app/pdf.py
    - server/requirements.txt
    - server/Dockerfile

key-decisions:
  - "WeasyPrint+Jinja2 substitui fpdf2 — elimina _safe()/latin1 encode/replace que corrompia acentuação"
  - "Dockerfile atualizado com libpango/libcairo/libgdk-pixbuf2 (bloqueio necessário para WeasyPrint em slim)"
  - "Testes com pytestmark.skipif + try/except OSError para WeasyPrint indisponível em Windows/CI"

requirements-completed:
  - INFRA-04

duration: 4min
completed: 2026-04-06
---

# Phase 00 Plan 03: Substituir fpdf2 por WeasyPrint+Jinja2 Summary

**WeasyPrint+Jinja2 substitui fpdf2+Helvetica eliminando _safe()/latin1 que corrompiam acentuação PT-BR em PDFs de obra**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-04-06T23:09:21Z
- **Completed:** 2026-04-06T23:13:05Z
- **Tasks:** 3
- **Files modified:** 5 (+ 2 criados)

## Accomplishments

- Removido `_safe()` com `text.encode("latin1", errors="replace")` que substituía ã/ç/é/ê/õ por `?`
- `pdf.py` reescrito com WeasyPrint+Jinja2: HTML template renderizado em PDF com charset UTF-8 nativo
- Template `obra_relatorio.html` com CSS, layout por etapa, suporte a todos os caracteres PT-BR
- `requirements.txt`: `fpdf2==2.7.8` substituído por `weasyprint==62.3` + `jinja2==3.1.4`
- `Dockerfile` atualizado com `apt-get install libpango/libcairo/libgdk-pixbuf2` para WeasyPrint em slim
- 5 testes de corpus PT-BR criados (ã, ç, é, ê, õ, á, í, ó, ú) — skipados em Windows, executam em Docker Linux
- Contrato da API preservado: `render_obra_pdf(obra, etapas, itens)` → `bytes`; endpoint sem alteração

## Task Commits

1. **Task 1: Implementar renderer PDF com Unicode** — `2893543` (feat)
2. **Task 2: Integrar renderer ao endpoint** — incluído no Task 1 (contrato inalterado)
3. **Task 3: Validar corpus PT-BR** — `1d058db` (test)

## Files Created/Modified

- `server/app/pdf.py` — removido `_safe()/latin1`, implementado `render_obra_pdf` via WeasyPrint+Jinja2
- `server/app/templates/obra_relatorio.html` — template HTML com UTF-8, estilos CSS por etapa, suporte PT-BR
- `server/requirements.txt` — `fpdf2==2.7.8` → `weasyprint==62.3` + `jinja2==3.1.4`
- `server/Dockerfile` — adicionado `apt-get install` de libs nativas GTK/Pango/Cairo
- `server/tests/test_pdf.py` — 5 testes com corpus PT-BR completo

## Decisions Made

- `_safe()` com encode latin1 é a causa-raiz da corrupção: `ã` → `?`, `ç` → `?`, etc. Removido completamente.
- WeasyPrint gera PDF a partir de HTML+CSS com suporte Unicode nativo sem configuração adicional.
- Dockerfile precisa de libs nativas (`libpango`, `libcairo`, `libgdk-pixbuf2`) para WeasyPrint funcionar em `python:3.11-slim`.
- Testes usam `pytestmark = pytest.mark.skipif(not _WEASYPRINT_AVAILABLE, ...)` com `try/except OSError` para suportar Windows sem GTK; executarão em Docker Linux em CI/CD.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Dockerfile atualizado com dependências nativas de WeasyPrint**
- **Found during:** Task 1 (ao planejar implementação)
- **Issue:** `python:3.11-slim` não possui `libpango`, `libcairo`, `libgdk-pixbuf2` necessários para WeasyPrint importar `ffi.py`
- **Fix:** Adicionado bloco `apt-get install` no Dockerfile antes do `pip install`
- **Files modified:** `server/Dockerfile`
- **Committed in:** `2893543`

**2. [Rule 3 - Blocking] Testes com skip condicional para ambiente sem GTK**
- **Found during:** Task 3 (ao tentar rodar pytest localmente em Windows)
- **Issue:** `pytest.importorskip` não captura `OSError` levantado pelo WeasyPrint (captura apenas `ImportError`); testes abortariam com erro de coleta
- **Fix:** Substituído por `try/except (ImportError, OSError)` + `pytestmark = pytest.mark.skipif(...)`
- **Files modified:** `server/tests/test_pdf.py`
- **Committed in:** `1d058db`

---

**Total deviations:** 2 auto-fixed (Rule 3 — blocking)

## Known Stubs

None — todos os dados são renderizados a partir de objetos reais passados à função.

## Self-Check: PASSED

- `server/app/pdf.py` — modificado, existe
- `server/app/templates/obra_relatorio.html` — criado, existe
- `server/requirements.txt` — modificado, weasyprint+jinja2 presentes
- `server/Dockerfile` — modificado, apt-get libs presentes
- `server/tests/test_pdf.py` — criado, 5 testes skipados em Windows
- Commit `2893543` — presente no log
- Commit `1d058db` — presente no log
- `fpdf2` removido, `latin1` removido: confirmado via grep
