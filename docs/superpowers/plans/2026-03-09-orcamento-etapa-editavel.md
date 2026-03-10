# Orçamento por Etapa Editável — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow the obra owner to edit both `valor_previsto` and `valor_realizado` per etapa in a dedicated screen, with `valor_realizado` taking priority over the automatic sum of despesas.

**Architecture:** Add `valor_realizado` (nullable float) to the existing `OrcamentoEtapa` model. Update the upsert endpoint and financial report logic. Create a new Flutter screen `OrcamentoEditScreen` accessible from `FinanceiroScreen`.

**Tech Stack:** Python/FastAPI/SQLModel (backend), Alembic (migration), Flutter/Dart (mobile)

**Spec:** `docs/superpowers/specs/2026-03-09-orcamento-etapa-editavel-design.md`

---

## Task 1: Backend — Add `valor_realizado` column

**Files:**
- Modify: `server/app/models.py:112-119`
- Modify: `server/app/schemas.py:230-241`
- Create: `server/alembic/versions/20260309_0014_add_valor_realizado.py`

- [ ] **Step 1: Add `valor_realizado` to the model**

In `server/app/models.py`, add field to `OrcamentoEtapa`:

```python
class OrcamentoEtapa(SQLModel, table=True):
    """Orçamento previsto por etapa de uma obra."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    obra_id: UUID = Field(index=True, foreign_key="obra.id")
    etapa_id: UUID = Field(index=True, foreign_key="etapa.id")
    valor_previsto: float
    valor_realizado: Optional[float] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
```

- [ ] **Step 2: Update schemas**

In `server/app/schemas.py`, add `valor_realizado` to both Create and Read:

```python
class OrcamentoEtapaCreate(SQLModel):
    etapa_id: UUID
    valor_previsto: float
    valor_realizado: Optional[float] = None


class OrcamentoEtapaRead(SQLModel):
    id: UUID
    obra_id: UUID
    etapa_id: UUID
    valor_previsto: float
    valor_realizado: Optional[float] = None
    created_at: datetime
    updated_at: datetime
```

- [ ] **Step 3: Create Alembic migration**

Create `server/alembic/versions/20260309_0014_add_valor_realizado.py`:

```python
"""add valor_realizado to orcamentoetapa

Revision ID: 20260309_0014
Revises: 20260311_0013
Create Date: 2026-03-09 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa

revision = "20260309_0014"
down_revision = "20260311_0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("orcamentoetapa", sa.Column("valor_realizado", sa.Float(), nullable=True))


def downgrade() -> None:
    op.drop_column("orcamentoetapa", "valor_realizado")
```

- [ ] **Step 4: Commit**

```bash
git add server/app/models.py server/app/schemas.py server/alembic/versions/20260309_0014_add_valor_realizado.py
git commit -m "feat: add valor_realizado column to OrcamentoEtapa"
```

---

## Task 2: Backend — Update endpoint and relatório logic

**Files:**
- Modify: `server/app/main.py:783-815` (upsert endpoint)
- Modify: `server/app/main.py:870-929` (relatorio financeiro)

- [ ] **Step 1: Update upsert endpoint to handle `valor_realizado`**

In `server/app/main.py`, in `registrar_orcamento`, update the upsert logic:

```python
@app.post("/api/obras/{obra_id}/orcamento", response_model=List[OrcamentoEtapaRead])
def registrar_orcamento(
    obra_id: UUID,
    payload: List[OrcamentoEtapaCreate],
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[OrcamentoEtapa]:
    """Registra ou atualiza o orçamento previsto e realizado por etapa (upsert)."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    resultado: list[OrcamentoEtapa] = []
    for item in payload:
        existing = session.exec(
            select(OrcamentoEtapa)
            .where(OrcamentoEtapa.obra_id == obra_id)
            .where(OrcamentoEtapa.etapa_id == item.etapa_id)
        ).first()
        if existing:
            existing.valor_previsto = item.valor_previsto
            existing.valor_realizado = item.valor_realizado
            existing.updated_at = datetime.utcnow()
            session.add(existing)
            resultado.append(existing)
        else:
            orcamento = OrcamentoEtapa(
                obra_id=obra_id,
                etapa_id=item.etapa_id,
                valor_previsto=item.valor_previsto,
                valor_realizado=item.valor_realizado,
            )
            session.add(orcamento)
            resultado.append(orcamento)
    session.commit()
    for o in resultado:
        session.refresh(o)
    return resultado
```

- [ ] **Step 2: Update relatório financeiro — realizado com prioridade**

In `server/app/main.py`, in the `relatorio_financeiro` function, change the `orcamento_por_etapa` dict and the gasto lookup:

Replace the line:
```python
orcamento_por_etapa = {str(o.etapa_id): o.valor_previsto for o in orcamentos}
```

With:
```python
orcamento_por_etapa = {str(o.etapa_id): o.valor_previsto for o in orcamentos}
realizado_por_etapa = {str(o.etapa_id): o.valor_realizado for o in orcamentos if o.valor_realizado is not None}
```

Then change the gasto lookup inside the etapa loop from:
```python
gasto = gasto_por_etapa.get(str(etapa.id), 0.0)
```
To:
```python
gasto = realizado_por_etapa.get(str(etapa.id), gasto_por_etapa.get(str(etapa.id), 0.0))
```

This means: use `valor_realizado` if set, else fallback to sum of despesas.

- [ ] **Step 3: Commit**

```bash
git add server/app/main.py
git commit -m "feat: update orcamento endpoint and relatório to support valor_realizado"
```

---

## Task 3: Flutter — Update model and API client

**Files:**
- Modify: `mobile/lib/models/financeiro.dart:1-25` (OrcamentoEtapa model)
- Modify: `mobile/lib/services/api_client.dart:566-586` (API methods)

- [ ] **Step 1: Add `valorRealizado` to Flutter model**

In `mobile/lib/models/financeiro.dart`, update `OrcamentoEtapa`:

```dart
class OrcamentoEtapa {
  OrcamentoEtapa({
    required this.id,
    required this.obraId,
    required this.etapaId,
    required this.valorPrevisto,
    this.valorRealizado,
    this.etapaNome,
  });

  final String id;
  final String obraId;
  final String etapaId;
  final double valorPrevisto;
  final double? valorRealizado;
  final String? etapaNome;

  factory OrcamentoEtapa.fromJson(Map<String, dynamic> json) {
    return OrcamentoEtapa(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      etapaId: json["etapa_id"] as String,
      valorPrevisto: (json["valor_previsto"] as num?)?.toDouble() ?? 0.0,
      valorRealizado: (json["valor_realizado"] as num?)?.toDouble(),
      etapaNome: json["etapa_nome"] as String?,
    );
  }
}
```

- [ ] **Step 2: Fix `salvarOrcamento` to send a raw list**

The backend expects `List[OrcamentoEtapaCreate]` (raw JSON array), but the current Flutter code wraps it in `{"itens": ...}`. Fix in `mobile/lib/services/api_client.dart`:

```dart
  Future<void> salvarOrcamento(
      String obraId, List<Map<String, dynamic>> itens) async {
    final response = await _post(
      "/api/obras/$obraId/orcamento",
      body: itens,
    );
    if (response.statusCode != 200) {
      throw Exception("Erro ao salvar orçamento");
    }
  }
```

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/models/financeiro.dart mobile/lib/services/api_client.dart
git commit -m "feat: add valorRealizado to Flutter model and fix salvarOrcamento payload"
```

---

## Task 4: Flutter — Create `OrcamentoEditScreen`

**Files:**
- Create: `mobile/lib/screens/financeiro/orcamento_edit_screen.dart`

- [ ] **Step 1: Create the screen**

Create `mobile/lib/screens/financeiro/orcamento_edit_screen.dart`:

```dart
import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../api/api.dart";
import "../../models/financeiro.dart";
import "../../services/api_client.dart";

class OrcamentoEditScreen extends StatefulWidget {
  const OrcamentoEditScreen({
    super.key,
    required this.obraId,
    required this.api,
  });

  final String obraId;
  final ApiClient api;

  @override
  State<OrcamentoEditScreen> createState() => _OrcamentoEditScreenState();
}

class _OrcamentoEditScreenState extends State<OrcamentoEditScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Etapa> _etapas = [];
  Map<String, OrcamentoEtapa> _orcamentos = {};
  final Map<String, TextEditingController> _previstoControllers = {};
  final Map<String, TextEditingController> _realizadoControllers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final c in _previstoControllers.values) {
      c.dispose();
    }
    for (final c in _realizadoControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final etapas = await widget.api.listarEtapas(widget.obraId);
      final orcamentos = await widget.api.listarOrcamento(widget.obraId);
      final orcMap = <String, OrcamentoEtapa>{};
      for (final o in orcamentos) {
        orcMap[o.etapaId] = o;
      }
      setState(() {
        _etapas = etapas;
        _orcamentos = orcMap;
        for (final etapa in etapas) {
          final orc = orcMap[etapa.id];
          _previstoControllers[etapa.id] = TextEditingController(
            text: orc != null && orc.valorPrevisto > 0
                ? orc.valorPrevisto.toStringAsFixed(2)
                : "",
          );
          _realizadoControllers[etapa.id] = TextEditingController(
            text: orc?.valorRealizado != null
                ? orc!.valorRealizado!.toStringAsFixed(2)
                : "",
          );
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _salvar() async {
    setState(() => _saving = true);
    try {
      final itens = <Map<String, dynamic>>[];
      for (final etapa in _etapas) {
        final prevText =
            _previstoControllers[etapa.id]?.text.replaceAll(",", ".") ?? "";
        final realText =
            _realizadoControllers[etapa.id]?.text.replaceAll(",", ".") ?? "";
        final previsto = double.tryParse(prevText) ?? 0.0;
        final realizado = realText.isEmpty ? null : double.tryParse(realText);
        itens.add({
          "etapa_id": etapa.id,
          "valor_previsto": previsto,
          if (realizado != null) "valor_realizado": realizado,
        });
      }
      await widget.api.salvarOrcamento(widget.obraId, itens);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Orçamento salvo com sucesso")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar Orçamento"),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _salvar,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text("Salvar"),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text("Erro: $_error"));
    }
    if (_etapas.isEmpty) {
      return const Center(child: Text("Nenhuma etapa encontrada"));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _etapas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final etapa = _etapas[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etapa.nome,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _previstoControllers[etapa.id],
                        decoration: const InputDecoration(
                          labelText: "Previsto (R\$)",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r"[\d.,]")),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _realizadoControllers[etapa.id],
                        decoration: const InputDecoration(
                          labelText: "Realizado (R\$)",
                          border: OutlineInputBorder(),
                          isDense: true,
                          hintText: "Auto (despesas)",
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r"[\d.,]")),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add mobile/lib/screens/financeiro/orcamento_edit_screen.dart
git commit -m "feat: create OrcamentoEditScreen with previsto and realizado fields"
```

---

## Task 5: Flutter — Add navigation from FinanceiroScreen

**Files:**
- Modify: `mobile/lib/screens/financeiro/financeiro_screen.dart:1-10` (imports)
- Modify: `mobile/lib/screens/financeiro/financeiro_screen.dart:139-154` (AppBar actions)

- [ ] **Step 1: Add import and navigation method**

In `mobile/lib/screens/financeiro/financeiro_screen.dart`, add import:

```dart
import "orcamento_edit_screen.dart";
```

Add method to `_FinanceiroScreenState`:

```dart
  Future<void> _abrirEditarOrcamento() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OrcamentoEditScreen(
          obraId: widget.obraId,
          api: widget.api,
        ),
      ),
    );
    if (result == true) {
      await _refresh();
    }
  }
```

- [ ] **Step 2: Add edit button to AppBar**

In the `actions` list of the AppBar, add before the existing buttons:

```dart
IconButton(
  onPressed: _abrirEditarOrcamento,
  icon: const Icon(Icons.edit_note),
  tooltip: "Editar Orçamento",
),
```

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/screens/financeiro/financeiro_screen.dart
git commit -m "feat: add navigation to OrcamentoEditScreen from FinanceiroScreen"
```

---

## Task 6: Deploy migration to Supabase

- [ ] **Step 1: Apply migration**

```bash
cd server && alembic upgrade head
```

Or apply directly via Supabase SQL:

```sql
ALTER TABLE orcamentoetapa ADD COLUMN valor_realizado FLOAT NULL;
```

- [ ] **Step 2: Deploy backend to Cloud Run**

```bash
bash server/deploy-cloudrun.sh
```

- [ ] **Step 3: Test end-to-end**

1. Open the app → select an obra → Financeiro
2. Tap the edit icon (pencil) in AppBar
3. Enter valor_previsto and valor_realizado for some etapas
4. Tap Salvar → verify snackbar "Orçamento salvo com sucesso"
5. Back on FinanceiroScreen → verify values updated
6. Clear valor_realizado for an etapa → verify it falls back to despesas sum
