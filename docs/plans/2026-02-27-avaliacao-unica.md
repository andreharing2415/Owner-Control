# Avaliacao Unica por Usuario+Prestador — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enforce one rating per user per prestador, with edit capability for existing ratings.

**Architecture:** Add `user_id` FK to `Avaliacao` model, unique constraint on `(prestador_id, user_id)`, new endpoints for fetching/updating user's rating, and Flutter UI changes to detect existing rating and switch between create/edit modes.

**Tech Stack:** Python/FastAPI/SQLModel (backend), Alembic (migration), Flutter/Dart (frontend)

---

### Task 1: Alembic Migration — add user_id + unique constraint

**Files:**
- Create: `server/alembic/versions/20260227_0008_avaliacao_user_id.py`

**Step 1: Create migration file**

```python
"""avaliacao: add user_id + unique constraint (prestador_id, user_id)

Revision ID: 20260227_0008
Revises: 20260225_0007
Create Date: 2026-02-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "20260227_0008"
down_revision = "20260225_0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "avaliacao",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True),
    )
    op.create_foreign_key(
        "fk_avaliacao_user_id",
        "avaliacao",
        "user",
        ["user_id"],
        ["id"],
    )
    op.create_index(
        "ix_avaliacao_user_id",
        "avaliacao",
        ["user_id"],
    )
    # Partial unique: only enforced where user_id IS NOT NULL (preserves legacy rows)
    op.execute(
        "CREATE UNIQUE INDEX uq_avaliacao_prestador_user "
        "ON avaliacao (prestador_id, user_id) "
        "WHERE user_id IS NOT NULL"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS uq_avaliacao_prestador_user")
    op.drop_index("ix_avaliacao_user_id", table_name="avaliacao")
    op.drop_constraint("fk_avaliacao_user_id", "avaliacao", type_="foreignkey")
    op.drop_column("avaliacao", "user_id")
```

**Step 2: Commit**

```bash
git add server/alembic/versions/20260227_0008_avaliacao_user_id.py
git commit -m "migration: add user_id to avaliacao with partial unique constraint"
```

---

### Task 2: Backend Model — add user_id to Avaliacao

**Files:**
- Modify: `server/app/models.py:227-240`

**Step 1: Add user_id field to Avaliacao model**

At line 230, after `prestador_id`, add:

```python
    user_id: Optional[UUID] = Field(default=None, index=True, foreign_key="user.id")
```

The model should look like:

```python
class Avaliacao(SQLModel, table=True):
    """Avaliacao (rating) de um prestador/fornecedor."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    prestador_id: UUID = Field(index=True, foreign_key="prestador.id")
    user_id: Optional[UUID] = Field(default=None, index=True, foreign_key="user.id")
    # ... rest unchanged
```

**Step 2: Commit**

```bash
git add server/app/models.py
git commit -m "model: add user_id FK to Avaliacao"
```

---

### Task 3: Backend Schema — add user_id to AvaliacaoRead

**Files:**
- Modify: `server/app/schemas.py:368-377`

**Step 1: Add user_id to AvaliacaoRead**

At line 370, after `prestador_id: UUID`, add:

```python
    user_id: Optional[UUID] = None
```

Need to ensure `Optional` and `UUID` are imported (they already are at top of file).

**Step 2: Commit**

```bash
git add server/app/schemas.py
git commit -m "schema: add user_id to AvaliacaoRead"
```

---

### Task 4: Backend Endpoints — enforce unique + add minha-avaliacao + PATCH

**Files:**
- Modify: `server/app/main.py:1238-1292` (avaliacao endpoints section)

**Step 1: Modify `criar_avaliacao` to set user_id and check for existing**

In `criar_avaliacao` (line 1238), after the prestador existence check, add duplicate detection:

```python
    # Check if user already rated this prestador
    existing = session.exec(
        select(Avaliacao)
        .where(Avaliacao.prestador_id == prestador_id)
        .where(Avaliacao.user_id == current_user.id)
    ).first()
    if existing:
        raise HTTPException(
            status_code=409,
            detail="Voce ja avaliou este prestador. Use PATCH para editar.",
        )
```

And at line 1270, change the Avaliacao creation to include `user_id`:

```python
    avaliacao = Avaliacao(prestador_id=prestador_id, user_id=current_user.id, **payload.model_dump())
```

**Step 2: Add GET /api/prestadores/{id}/minha-avaliacao endpoint**

Insert before `listar_avaliacoes` (line 1277):

```python
@app.get("/api/prestadores/{prestador_id}/minha-avaliacao", response_model=AvaliacaoRead)
def minha_avaliacao(
    prestador_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Retorna a avaliacao do usuario atual para este prestador, ou 404."""
    prestador = session.get(Prestador, prestador_id)
    if not prestador:
        raise HTTPException(status_code=404, detail="Prestador nao encontrado")
    avaliacao = session.exec(
        select(Avaliacao)
        .where(Avaliacao.prestador_id == prestador_id)
        .where(Avaliacao.user_id == current_user.id)
    ).first()
    if not avaliacao:
        raise HTTPException(status_code=404, detail="Voce ainda nao avaliou este prestador")
    return avaliacao
```

**Step 3: Add PATCH /api/prestadores/{id}/avaliacoes/{avaliacao_id} endpoint**

Insert after `listar_avaliacoes`:

```python
@app.patch("/api/prestadores/{prestador_id}/avaliacoes/{avaliacao_id}", response_model=AvaliacaoRead)
def atualizar_avaliacao(
    prestador_id: UUID,
    avaliacao_id: UUID,
    payload: AvaliacaoCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> Avaliacao:
    """Atualiza a avaliacao do usuario (somente o autor pode editar)."""
    avaliacao = session.get(Avaliacao, avaliacao_id)
    if not avaliacao or avaliacao.prestador_id != prestador_id:
        raise HTTPException(status_code=404, detail="Avaliacao nao encontrada")
    if avaliacao.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Voce so pode editar sua propria avaliacao")

    prestador = session.get(Prestador, prestador_id)
    if prestador.categoria == CategoriaPrestador.PRESTADOR_SERVICO.value:
        campos_validos = NOTAS_SERVICO
        campos_invalidos = NOTAS_MATERIAL
    else:
        campos_validos = NOTAS_MATERIAL
        campos_invalidos = NOTAS_SERVICO

    for campo in campos_invalidos:
        if getattr(payload, campo) is not None:
            raise HTTPException(
                status_code=422,
                detail=f"Campo '{campo}' nao se aplica a categoria '{prestador.categoria}'",
            )

    notas_preenchidas = [getattr(payload, c) for c in campos_validos if getattr(payload, c) is not None]
    if not notas_preenchidas:
        raise HTTPException(status_code=422, detail="Informe ao menos uma nota")

    updates = payload.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(avaliacao, key, value)
    avaliacao.updated_at = datetime.utcnow()
    session.add(avaliacao)
    session.commit()
    session.refresh(avaliacao)
    return avaliacao
```

**Step 4: Commit**

```bash
git add server/app/main.py
git commit -m "endpoints: enforce unique avaliacao per user, add minha-avaliacao and PATCH"
```

---

### Task 5: Flutter ApiClient — add new methods + user_id to model

**Files:**
- Modify: `lib/api/api.dart:717-753` (AvaliacaoPrestador model)
- Modify: `lib/api/api.dart:1505-1557` (API methods section)

**Step 1: Add user_id to AvaliacaoPrestador model**

At line 720, add `this.userId,` to constructor. Add field `final String? userId;`. Update `fromJson`:

```dart
class AvaliacaoPrestador {
  AvaliacaoPrestador({
    required this.id,
    required this.prestadorId,
    this.userId,
    this.notaQualidadeServico,
    // ... rest same
  });

  final String id;
  final String prestadorId;
  final String? userId;
  // ... rest same

  factory AvaliacaoPrestador.fromJson(Map<String, dynamic> json) {
    return AvaliacaoPrestador(
      id: json["id"] as String,
      prestadorId: json["prestador_id"] as String,
      userId: json["user_id"] as String?,
      // ... rest same
    );
  }
}
```

**Step 2: Add `getMinhaAvaliacao` method**

After `criarAvaliacao` method (~line 1557), add:

```dart
  /// Returns the current user's rating for this prestador, or null if none.
  Future<AvaliacaoPrestador?> getMinhaAvaliacao(String prestadorId) async {
    final response = await _client.get(
      _uri("/api/prestadores/$prestadorId/minha-avaliacao"),
      headers: _headers(json: false),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception("Erro ao buscar sua avaliacao");
    }
    return AvaliacaoPrestador.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
```

**Step 3: Add `atualizarAvaliacao` method**

After `getMinhaAvaliacao`, add:

```dart
  Future<AvaliacaoPrestador> atualizarAvaliacao({
    required String prestadorId,
    required String avaliacaoId,
    int? notaQualidadeServico,
    int? notaCumprimentoPrazos,
    int? notaFidelidadeProjeto,
    int? notaPrazoEntrega,
    int? notaQualidadeMaterial,
    String? comentario,
  }) async {
    final payload = <String, dynamic>{};
    if (notaQualidadeServico != null) {
      payload["nota_qualidade_servico"] = notaQualidadeServico;
    }
    if (notaCumprimentoPrazos != null) {
      payload["nota_cumprimento_prazos"] = notaCumprimentoPrazos;
    }
    if (notaFidelidadeProjeto != null) {
      payload["nota_fidelidade_projeto"] = notaFidelidadeProjeto;
    }
    if (notaPrazoEntrega != null) {
      payload["nota_prazo_entrega"] = notaPrazoEntrega;
    }
    if (notaQualidadeMaterial != null) {
      payload["nota_qualidade_material"] = notaQualidadeMaterial;
    }
    if (comentario != null && comentario.isNotEmpty) {
      payload["comentario"] = comentario;
    }

    final response = await _client.patch(
      _uri("/api/prestadores/$prestadorId/avaliacoes/$avaliacaoId"),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro ao atualizar avaliacao");
    }
    return AvaliacaoPrestador.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
```

**Step 4: Commit**

```bash
git add lib/api/api.dart
git commit -m "flutter: add userId to AvaliacaoPrestador, add getMinhaAvaliacao and atualizarAvaliacao"
```

---

### Task 6: Flutter DetalhePrestadorScreen — dynamic FAB + highlight user rating

**Files:**
- Modify: `lib/screens/detalhe_prestador_screen.dart:19-141`

**Step 1: Add minhaAvaliacao state and fetch**

In `_DetalhePrestadorScreenState`, add a new field and fetch logic:

```dart
class _DetalhePrestadorScreenState extends State<DetalhePrestadorScreen> {
  final ApiClient _api = ApiClient();
  late Future<PrestadorDetalhe> _detalheFuture;
  AvaliacaoPrestador? _minhaAvaliacao;
  bool _loadingMinha = true;

  @override
  void initState() {
    super.initState();
    _detalheFuture = _api.obterPrestador(widget.prestadorId);
    _carregarMinhaAvaliacao();
  }

  Future<void> _carregarMinhaAvaliacao() async {
    try {
      _minhaAvaliacao = await _api.getMinhaAvaliacao(widget.prestadorId);
    } catch (_) {
      _minhaAvaliacao = null;
    }
    if (mounted) setState(() => _loadingMinha = false);
  }

  void _recarregar() {
    setState(() {
      _detalheFuture = _api.obterPrestador(widget.prestadorId);
      _loadingMinha = true;
    });
    _carregarMinhaAvaliacao();
  }
```

**Step 2: Update `_abrirAvaliacao` to pass existing rating**

```dart
  Future<void> _abrirAvaliacao(String categoria) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AvaliarPrestadorScreen(
          prestadorId: widget.prestadorId,
          categoria: categoria,
          avaliacaoExistente: _minhaAvaliacao,
        ),
      ),
    );
    if (ok == true) _recarregar();
  }
```

**Step 3: Update FAB to show "Editar Avaliacao" when already rated**

Replace the `floatingActionButton` in the inner Scaffold:

```dart
floatingActionButton: _loadingMinha
    ? null
    : FloatingActionButton.extended(
        onPressed: () => _abrirAvaliacao(p.categoria),
        icon: Icon(_minhaAvaliacao != null
            ? Icons.edit_rounded
            : Icons.star_rounded),
        label: Text(_minhaAvaliacao != null
            ? 'Editar Avaliacao'
            : 'Avaliar'),
      ),
```

**Step 4: Highlight user's own rating in the list with "Sua avaliacao" badge**

In the `_AvaliacaoCard` widget, add an `isOwn` parameter. In the avaliacoes list builder, compare `a.userId` with the current user ID from AuthService:

```dart
// In the avaliacoes list mapping, pass isOwn:
...detalhe.avaliacoes.map(
  (a) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: _AvaliacaoCard(
      avaliacao: a,
      isOwn: _minhaAvaliacao != null && a.id == _minhaAvaliacao!.id,
    ),
  ),
),
```

Update `_AvaliacaoCard` to accept and display `isOwn`:

```dart
class _AvaliacaoCard extends StatelessWidget {
  const _AvaliacaoCard({required this.avaliacao, this.isOwn = false});
  final AvaliacaoPrestador avaliacao;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    // ... existing code, but add after the date Row:
    if (isOwn)
      Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Sua avaliacao',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    // ... rest of existing build
  }
}
```

**Step 5: Commit**

```bash
git add lib/screens/detalhe_prestador_screen.dart
git commit -m "flutter: dynamic FAB create/edit, highlight user's own rating"
```

---

### Task 7: Flutter AvaliarPrestadorScreen — support edit mode

**Files:**
- Modify: `lib/screens/avaliar_prestador_screen.dart:7-194`

**Step 1: Add optional avaliacaoExistente parameter**

```dart
class AvaliarPrestadorScreen extends StatefulWidget {
  const AvaliarPrestadorScreen({
    super.key,
    required this.prestadorId,
    required this.categoria,
    this.avaliacaoExistente,
  });

  final String prestadorId;
  final String categoria;
  final AvaliacaoPrestador? avaliacaoExistente;
  // ...
}
```

**Step 2: Pre-fill fields in initState when editing**

In `_AvaliarPrestadorScreenState`, add:

```dart
  bool get _isEditing => widget.avaliacaoExistente != null;

  @override
  void initState() {
    super.initState();
    final av = widget.avaliacaoExistente;
    if (av != null) {
      _notaQualidadeServico = av.notaQualidadeServico ?? 0;
      _notaCumprimentoPrazos = av.notaCumprimentoPrazos ?? 0;
      _notaFidelidadeProjeto = av.notaFidelidadeProjeto ?? 0;
      _notaPrazoEntrega = av.notaPrazoEntrega ?? 0;
      _notaQualidadeMaterial = av.notaQualidadeMaterial ?? 0;
      _comentarioCtrl.text = av.comentario ?? '';
    }
  }
```

**Step 3: Update `_salvar` to call update vs create**

In the `_salvar` method, replace the `await _api.criarAvaliacao(...)` call:

```dart
      if (_isEditing) {
        await _api.atualizarAvaliacao(
          prestadorId: widget.prestadorId,
          avaliacaoId: widget.avaliacaoExistente!.id,
          notaQualidadeServico:
              _notaQualidadeServico > 0 ? _notaQualidadeServico : null,
          notaCumprimentoPrazos:
              _notaCumprimentoPrazos > 0 ? _notaCumprimentoPrazos : null,
          notaFidelidadeProjeto:
              _notaFidelidadeProjeto > 0 ? _notaFidelidadeProjeto : null,
          notaPrazoEntrega: _notaPrazoEntrega > 0 ? _notaPrazoEntrega : null,
          notaQualidadeMaterial:
              _notaQualidadeMaterial > 0 ? _notaQualidadeMaterial : null,
          comentario: _comentarioCtrl.text.trim().isNotEmpty
              ? _comentarioCtrl.text.trim()
              : null,
        );
      } else {
        await _api.criarAvaliacao(
          prestadorId: widget.prestadorId,
          // ... existing params unchanged
        );
      }
```

**Step 4: Update AppBar title and button text**

```dart
appBar: AppBar(
  title: Text(_isEditing ? 'Editar Avaliacao' : 'Avaliar Prestador'),
  centerTitle: false,
),
```

And the submit button:

```dart
label: Text(_salvando
    ? 'Salvando...'
    : _isEditing
        ? 'Atualizar Avaliacao'
        : 'Enviar Avaliacao'),
```

**Step 5: Commit**

```bash
git add lib/screens/avaliar_prestador_screen.dart
git commit -m "flutter: support edit mode in AvaliarPrestadorScreen"
```

---

### Task 8: Run migration and verify

**Step 1: Run Alembic migration**

```bash
cd server && alembic upgrade head
```

Expected: migration applies cleanly, `avaliacao` table now has `user_id` column and partial unique index.

**Step 2: Run Flutter analyze**

```bash
flutter analyze
```

Expected: No errors.

**Step 3: Commit (if any fixes needed)**

---

### Task 9: Final commit and cleanup

**Step 1: Verify all files are committed**

```bash
git status
```

**Step 2: Final commit if anything outstanding**

```bash
git add -A && git commit -m "feat: enforce one rating per user per prestador with edit support"
```
