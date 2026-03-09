# Checklist Grupos, Detalhe do Item e Integração Normas — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Adicionar agrupamento por categoria, tela de detalhe do item com fotos/status/observação, prazo previsto/executado por etapa, e integração das normas do checklist na Biblioteca Normativa.

**Architecture:** Opção B — campos `grupo` e `ordem` em `ChecklistItem`; campos `prazo_previsto` e `prazo_executado` em `Etapa`. Migração Alembic → atualização backend → atualização Flutter models → refatoração da ChecklistScreen → nova DetalheItemScreen → integração NormasScreen.

**Tech Stack:** FastAPI + SQLModel + Alembic (backend), Flutter + Provider + http (mobile). Sem testes automatizados — verificação via `curl` no backend e hot-reload no Flutter.

---

## Task 1: Migração Alembic — grupo, ordem, prazo

**Files:**
- Create: `server/alembic/versions/20260308_0010_checklist_grupo_etapa_prazo.py`

**Step 1: Criar o arquivo de migração**

```python
"""checklist grupo/ordem + etapa prazo

Revision ID: 20260308_0010
Revises: 20260307_0009
Create Date: 2026-03-08 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa

revision = "20260308_0010"
down_revision = "20260307_0009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("checklistitem",
        sa.Column("grupo", sa.String(), nullable=False, server_default="Geral"))
    op.add_column("checklistitem",
        sa.Column("ordem", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("etapa",
        sa.Column("prazo_previsto", sa.Date(), nullable=True))
    op.add_column("etapa",
        sa.Column("prazo_executado", sa.Date(), nullable=True))


def downgrade() -> None:
    op.drop_column("etapa", "prazo_executado")
    op.drop_column("etapa", "prazo_previsto")
    op.drop_column("checklistitem", "ordem")
    op.drop_column("checklistitem", "grupo")
```

**Step 2: Aplicar migração**

```bash
cd server
CLOUDSDK_PYTHON="C:/Users/Administrator/AppData/Local/Programs/Python/Python314/python.exe"
alembic upgrade head
```

Expected: `Running upgrade 20260307_0009 -> 20260308_0010, checklist grupo/ordem + etapa prazo`

**Step 3: Verificar colunas no Supabase**

No painel Supabase SQL Editor ou via psql, rodar:
```sql
SELECT column_name FROM information_schema.columns
WHERE table_name = 'checklistitem' AND column_name IN ('grupo','ordem');
SELECT column_name FROM information_schema.columns
WHERE table_name = 'etapa' AND column_name IN ('prazo_previsto','prazo_executado');
```
Expected: 4 linhas retornadas.

**Step 4: Commit**

```bash
git add server/alembic/versions/20260308_0010_checklist_grupo_etapa_prazo.py
git commit -m "feat: migration - add grupo/ordem to checklistitem, prazo to etapa"
```

---

## Task 2: Backend — atualizar models e schemas

**Files:**
- Modify: `server/app/models.py`
- Modify: `server/app/schemas.py`

### models.py

**Step 1: Adicionar campos ao `ChecklistItem` (linha ~56)**

Localizar o bloco:
```python
    norma_referencia: Optional[str] = None          # ex: "NBR 5410:2004"
    origem: str = Field(default="padrao")            # "padrao" | "ia"
```

Adicionar após `norma_referencia`:
```python
    grupo: str = Field(default="Geral")              # ex: "Piscina", "Churrasqueira"
    ordem: int = Field(default=0)                    # ordenação cronológica dentro do grupo
```

**Step 2: Adicionar campos ao `Etapa` (linha ~40)**

Localizar o bloco:
```python
    score: Optional[float] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
```

Adicionar após `score`:
```python
    prazo_previsto: Optional[date] = None
    prazo_executado: Optional[date] = None
```

Verificar que `from datetime import date, datetime` já está no topo do arquivo. Se não estiver, adicionar.

### schemas.py

**Step 3: Atualizar `ChecklistItemCreate` — adicionar grupo e ordem**

Localizar:
```python
class ChecklistItemCreate(SQLModel):
    titulo: str
    descricao: Optional[str] = None
    status: ChecklistStatus = ChecklistStatus.PENDENTE
    critico: Optional[bool] = False
    observacao: Optional[str] = None
    norma_referencia: Optional[str] = None
    origem: str = "padrao"
```

Adicionar após `norma_referencia`:
```python
    grupo: str = "Geral"
    ordem: int = 0
```

**Step 4: Atualizar `ChecklistItemRead` — adicionar grupo e ordem**

Localizar:
```python
class ChecklistItemRead(SQLModel):
    ...
    norma_referencia: Optional[str] = None
    origem: str
    created_at: datetime
    updated_at: datetime
```

Adicionar após `norma_referencia`:
```python
    grupo: str
    ordem: int
```

**Step 5: Atualizar `ChecklistItemUpdate` — adicionar grupo e ordem**

Localizar:
```python
class ChecklistItemUpdate(SQLModel):
    ...
    norma_referencia: Optional[str] = None
```

Adicionar após `norma_referencia`:
```python
    grupo: Optional[str] = None
    ordem: Optional[int] = None
```

**Step 6: Atualizar `EtapaRead` — adicionar prazo**

Localizar:
```python
class EtapaRead(SQLModel):
    id: UUID
    obra_id: UUID
    nome: str
    ordem: int
    status: EtapaStatus
    score: Optional[float] = None
    created_at: datetime
    updated_at: datetime
```

Adicionar após `score`:
```python
    prazo_previsto: Optional[date] = None
    prazo_executado: Optional[date] = None
```

Verificar que `from datetime import date, datetime` já está no topo de `schemas.py`. Se não estiver, adicionar (já existe na linha 1).

**Step 7: Criar novo schema `EtapaPrazoUpdate`**

Logo após `EtapaStatusUpdate`:
```python
class EtapaPrazoUpdate(SQLModel):
    prazo_previsto: Optional[date] = None
    prazo_executado: Optional[date] = None
```

**Step 8: Criar schema para retorno de normas da etapa**

No final da seção Normas em schemas.py:
```python
class EtapaNormasChecklistRead(SQLModel):
    etapa_id: UUID
    normas: List[str]  # lista de norma_referencia distintas, ex: ["NBR 5410:2004"]
```

**Step 9: Criar schemas para sugestão de grupo**

```python
class SugerirGrupoRequest(SQLModel):
    titulo: str

class SugerirGrupoResponse(SQLModel):
    grupo: str
    ordem: int
```

**Step 10: Commit**

```bash
git add server/app/models.py server/app/schemas.py
git commit -m "feat: add grupo/ordem to ChecklistItem, prazo to Etapa schemas"
```

---

## Task 3: Backend — novos e atualizados endpoints

**Files:**
- Modify: `server/app/main.py`

### 3a: Atualizar importação dos schemas

No bloco de imports do `main.py`, adicionar ao import de schemas:
```python
    EtapaPrazoUpdate,
    EtapaNormasChecklistRead,
    SugerirGrupoRequest,
    SugerirGrupoResponse,
```

### 3b: Endpoint PATCH prazo da etapa

Procurar o endpoint `PATCH /api/etapas/{etapa_id}/status` e adicionar logo após:

```python
@app.patch("/api/etapas/{etapa_id}/prazo", response_model=EtapaRead)
def atualizar_prazo_etapa(
    etapa_id: UUID,
    payload: EtapaPrazoUpdate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> EtapaRead:
    etapa = session.get(Etapa, etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")
    # Verifica que a etapa pertence a uma obra do usuario
    obra = session.get(Obra, etapa.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acesso negado")
    if payload.prazo_previsto is not None:
        etapa.prazo_previsto = payload.prazo_previsto
    if payload.prazo_executado is not None:
        etapa.prazo_executado = payload.prazo_executado
    etapa.updated_at = datetime.utcnow()
    session.add(etapa)
    session.commit()
    session.refresh(etapa)
    return EtapaRead.model_validate(etapa)
```

### 3c: Endpoint GET normas da etapa (do checklist)

```python
@app.get("/api/etapas/{etapa_id}/checklist-normas", response_model=EtapaNormasChecklistRead)
def listar_normas_checklist_etapa(
    etapa_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> EtapaNormasChecklistRead:
    etapa = session.get(Etapa, etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")
    obra = session.get(Obra, etapa.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acesso negado")
    itens = session.exec(
        select(ChecklistItem).where(
            ChecklistItem.etapa_id == etapa_id,
            ChecklistItem.norma_referencia != None,
        )
    ).all()
    normas = sorted({i.norma_referencia for i in itens if i.norma_referencia})
    return EtapaNormasChecklistRead(etapa_id=etapa_id, normas=list(normas))
```

### 3d: Endpoint POST sugerir grupo

```python
@app.post("/api/etapas/{etapa_id}/checklist-items/sugerir-grupo", response_model=SugerirGrupoResponse)
def sugerir_grupo_item(
    etapa_id: UUID,
    payload: SugerirGrupoRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> SugerirGrupoResponse:
    etapa = session.get(Etapa, etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")
    obra = session.get(Obra, etapa.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acesso negado")
    # Coletar grupos existentes e suas ordens máximas
    itens = session.exec(
        select(ChecklistItem).where(ChecklistItem.etapa_id == etapa_id)
    ).all()
    grupos_ordens: dict[str, int] = {}
    for item in itens:
        grupos_ordens[item.grupo] = max(grupos_ordens.get(item.grupo, 0), item.ordem)
    # Heurística simples: verificar se o título contém palavras-chave de grupos existentes
    titulo_lower = payload.titulo.lower()
    for grupo in grupos_ordens:
        if grupo.lower() != "geral" and grupo.lower() in titulo_lower:
            return SugerirGrupoResponse(
                grupo=grupo,
                ordem=grupos_ordens[grupo] + 1,
            )
    # Default: Geral, próxima ordem
    return SugerirGrupoResponse(
        grupo="Geral",
        ordem=grupos_ordens.get("Geral", 0) + 1,
    )
```

### 3e: Verificar que PATCH /api/checklist-items/{id} já aceita grupo/ordem

Localizar o endpoint PATCH existente em `main.py`. Verificar se ele usa `ChecklistItemUpdate` para atualizar campos. Se sim, como agora `ChecklistItemUpdate` inclui `grupo` e `ordem`, eles serão atualizados automaticamente via o loop de campos. Verificar o padrão do código existente. Caso use `.model_dump(exclude_unset=True)`, os novos campos serão incluídos automaticamente.

**Step final: Verificar servidor localmente**

```bash
cd server
uvicorn app.main:app --reload --port 8000
```

Testar com curl:
```bash
# Verificar que EtapaRead retorna prazo_previsto
curl http://localhost:8000/api/obras/<obra_id>/etapas -H "Authorization: Bearer <token>"
# Deve mostrar prazo_previsto: null, prazo_executado: null

# Testar normas do checklist
curl http://localhost:8000/api/etapas/<etapa_id>/checklist-normas -H "Authorization: Bearer <token>"
# Deve retornar {"etapa_id": "...", "normas": [...]}
```

**Step: Commit**

```bash
git add server/app/main.py
git commit -m "feat: add prazo endpoint, checklist-normas endpoint, sugerir-grupo endpoint"
```

---

## Task 4: Backend — atualizar aplicar_checklist_inteligente com grupo/ordem

**Files:**
- Modify: `server/app/main.py` (função `aplicar_checklist_inteligente`, linha ~1554)

**Step 1: Atualizar `ItemParaAplicar` schema em schemas.py**

Localizar `ItemParaAplicar` em `schemas.py` e adicionar os campos:
```python
    grupo: str = "Geral"
    ordem: int = 0
```

**Step 2: Atualizar a criação de `ChecklistItem` no endpoint**

Localizar em `main.py` o bloco:
```python
        novo_item = ChecklistItem(
            etapa_id=etapa_id,
            titulo=item_data.titulo,
            descricao=item_data.descricao,
            critico=item_data.critico,
            norma_referencia=item_data.norma_referencia,
            origem="ia",
            status=ChecklistStatus.PENDENTE.value,
        )
```

Substituir por:
```python
        # Capitalizar grupo da caracteristica_origem (ex: "piscina" -> "Piscina")
        grupo = getattr(item_data, "grupo", "Geral") or "Geral"
        grupo = grupo.replace("_", " ").title()

        novo_item = ChecklistItem(
            etapa_id=etapa_id,
            titulo=item_data.titulo,
            descricao=item_data.descricao,
            critico=item_data.critico,
            norma_referencia=item_data.norma_referencia,
            origem="ia",
            status=ChecklistStatus.PENDENTE.value,
            grupo=grupo,
            ordem=getattr(item_data, "ordem", 0),
        )
```

**Step 3: Atualizar `toJsonForApply()` no Flutter model (será feito na Task 6)**

Anotar que `ChecklistGeracaoItemModel.toJsonForApply()` precisa incluir `grupo` (mapeado de `caracteristicaOrigem`) e `ordem`.

**Step 4: Commit**

```bash
git add server/app/main.py server/app/schemas.py
git commit -m "feat: aplicar checklist inteligente passes grupo/ordem to ChecklistItem"
```

---

## Task 5: Deploy backend

**Step 1: Deploy para Cloud Run**

```bash
cd server
bash deploy-cloudrun.sh
```

Aguardar conclusão. Verificar no console GCP que o serviço `mestreobra-backend` está rodando a nova revisão.

**Step 2: Smoke test na URL de produção**

```bash
curl https://mestreobra-backend-530484413221.us-central1.run.app/api/obras \
  -H "Authorization: Bearer <token_valido>"
```

Expected: resposta 200.

---

## Task 6: Flutter — atualizar models

**Files:**
- Modify: `mobile/lib/models/checklist_item.dart`
- Modify: `mobile/lib/models/etapa.dart`

### checklist_item.dart

**Step 1: Adicionar campos ao model**

```dart
class ChecklistItem {
  ChecklistItem({
    required this.id,
    required this.etapaId,
    required this.titulo,
    this.descricao,
    required this.status,
    required this.critico,
    this.observacao,
    this.normaReferencia,
    this.grupo = 'Geral',
    this.ordem = 0,
  });

  final String id;
  final String etapaId;
  final String titulo;
  final String? descricao;
  final String status;
  final bool critico;
  final String? observacao;
  final String? normaReferencia;
  final String grupo;
  final int ordem;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json["id"] as String,
      etapaId: json["etapa_id"] as String,
      titulo: json["titulo"] as String,
      descricao: json["descricao"] as String?,
      status: json["status"] as String? ?? "pendente",
      critico: json["critico"] as bool? ?? false,
      observacao: json["observacao"] as String?,
      normaReferencia: json["norma_referencia"] as String?,
      grupo: json["grupo"] as String? ?? "Geral",
      ordem: json["ordem"] as int? ?? 0,
    );
  }
}
```

### etapa.dart

**Step 2: Adicionar campos de prazo**

```dart
class Etapa {
  Etapa({
    required this.id,
    required this.obraId,
    required this.nome,
    required this.ordem,
    required this.status,
    this.score,
    this.prazoPrevisto,
    this.prazoExecutado,
  });

  final String id;
  final String obraId;
  final String nome;
  final int ordem;
  final String status;
  final double? score;
  final DateTime? prazoPrevisto;
  final DateTime? prazoExecutado;

  factory Etapa.fromJson(Map<String, dynamic> json) {
    return Etapa(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      nome: json["nome"] as String,
      ordem: json["ordem"] as int,
      status: json["status"] as String,
      score: (json["score"] as num?)?.toDouble(),
      prazoPrevisto: json["prazo_previsto"] != null
          ? DateTime.parse(json["prazo_previsto"] as String)
          : null,
      prazoExecutado: json["prazo_executado"] != null
          ? DateTime.parse(json["prazo_executado"] as String)
          : null,
    );
  }
}
```

**Step 3: Commit**

```bash
git add mobile/lib/models/checklist_item.dart mobile/lib/models/etapa.dart
git commit -m "feat: add grupo/ordem to ChecklistItem, prazo to Etapa Flutter models"
```

---

## Task 7: Flutter — atualizar api_client.dart

**Files:**
- Modify: `mobile/lib/services/api_client.dart`

### 7a: Atualizar `criarItem` para aceitar grupo e ordem

Localizar `Future<ChecklistItem> criarItem(...)` e adicionar parâmetros:
```dart
  Future<ChecklistItem> criarItem({
    required String etapaId,
    required String titulo,
    String? descricao,
    bool critico = false,
    String grupo = "Geral",
    int ordem = 0,
  }) async {
    final response = await _post(
      "/api/etapas/$etapaId/checklist-items",
      body: {
        "titulo": titulo,
        if (descricao != null) "descricao": descricao,
        "critico": critico,
        "grupo": grupo,
        "ordem": ordem,
      },
    );
    if (response.statusCode != 201) {
      throw Exception("Erro ao criar item");
    }
    return ChecklistItem.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }
```

### 7b: Atualizar `atualizarItem` para aceitar grupo e observacao

Localizar `Future<ChecklistItem> atualizarItem(...)` e adicionar `grupo`:
```dart
  Future<ChecklistItem> atualizarItem({
    required String itemId,
    String? titulo,
    String? descricao,
    String? status,
    bool? critico,
    String? observacao,
    String? grupo,
  }) async {
    final response = await _patch(
      "/api/checklist-items/$itemId",
      body: {
        if (titulo != null) "titulo": titulo,
        if (descricao != null) "descricao": descricao,
        if (status != null) "status": status,
        if (critico != null) "critico": critico,
        if (observacao != null) "observacao": observacao,
        if (grupo != null) "grupo": grupo,
      },
    );
    if (response.statusCode != 200) {
      throw Exception("Erro ao atualizar item");
    }
    return ChecklistItem.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }
```

### 7c: Novo método `atualizarPrazoEtapa`

```dart
  Future<Etapa> atualizarPrazoEtapa({
    required String etapaId,
    DateTime? prazoPrevisto,
    DateTime? prazoExecutado,
  }) async {
    final body = <String, dynamic>{};
    if (prazoPrevisto != null) {
      body["prazo_previsto"] = prazoPrevisto.toIso8601String().split("T").first;
    }
    if (prazoExecutado != null) {
      body["prazo_executado"] = prazoExecutado.toIso8601String().split("T").first;
    }
    final response = await _patch("/api/etapas/$etapaId/prazo", body: body);
    if (response.statusCode != 200) {
      throw Exception("Erro ao atualizar prazo da etapa");
    }
    return Etapa.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
```

### 7d: Novo método `listarNormasChecklist`

```dart
  Future<List<String>> listarNormasChecklist(String etapaId) async {
    final response = await _get("/api/etapas/$etapaId/checklist-normas");
    if (response.statusCode != 200) {
      throw Exception("Erro ao carregar normas do checklist");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data["normas"] as List<dynamic>).cast<String>();
  }
```

### 7e: Novo método `sugerirGrupoItem`

```dart
  Future<Map<String, dynamic>> sugerirGrupoItem({
    required String etapaId,
    required String titulo,
  }) async {
    final response = await _post(
      "/api/etapas/$etapaId/checklist-items/sugerir-grupo",
      body: {"titulo": titulo},
    );
    if (response.statusCode != 200) {
      throw Exception("Erro ao sugerir grupo");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
```

### 7f: Atualizar `toJsonForApply` no model de checklist inteligente

Localizar `mobile/lib/models/auth.dart` ou onde `ChecklistGeracaoItemModel` é definido:

```bash
grep -r "toJsonForApply" mobile/lib/
```

No método `toJsonForApply()`, adicionar:
```dart
"grupo": caracteristicaOrigem.isNotEmpty
    ? caracteristicaOrigem.replaceAll('_', ' ').split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ')
    : "Geral",
"ordem": 0,
```

**Step: Commit**

```bash
git add mobile/lib/services/api_client.dart
git commit -m "feat: update api_client with grupo, prazo, normas-checklist, sugerir-grupo"
```

---

## Task 8: Flutter — refatorar ChecklistScreen

**Files:**
- Modify: `mobile/lib/screens/checklist/checklist_screen.dart`

O objetivo é:
1. Agrupar itens por `grupo`, ordenados por `ordem`
2. Card inteiro clicável → abre `DetalheItemScreen` (Task 9)
3. Badge de status no canto do card (substitui bolinha esquerda)
4. Menu 3 pontos: apenas "Remover"
5. Prazo no AppBar com BottomSheet de DatePicker
6. Diálogo de criação com sugestão de grupo

**Step 1: Substituir o conteúdo completo do arquivo**

```dart
import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:intl/intl.dart";

import "../../models/checklist_item.dart";
import "../../models/etapa.dart";
import "../../services/api_client.dart";
import "detalhe_item_screen.dart";

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key, required this.etapa, required this.api});

  final Etapa etapa;
  final ApiClient api;

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  late Future<List<ChecklistItem>> _itensFuture;
  late Etapa _etapa;

  @override
  void initState() {
    super.initState();
    _etapa = widget.etapa;
    _itensFuture = widget.api.listarItens(widget.etapa.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _itensFuture = widget.api.listarItens(_etapa.id);
    });
  }

  // Agrupa e ordena itens: por grupo, depois por ordem dentro do grupo.
  // Grupo "Geral" sempre por último.
  Map<String, List<ChecklistItem>> _agrupar(List<ChecklistItem> itens) {
    final map = <String, List<ChecklistItem>>{};
    for (final item in itens) {
      map.putIfAbsent(item.grupo, () => []).add(item);
    }
    for (final grupo in map.keys) {
      map[grupo]!.sort((a, b) => a.ordem.compareTo(b.ordem));
    }
    // Ordenar grupos: "Geral" por último
    final grupos = map.keys.toList()
      ..sort((a, b) {
        if (a == "Geral") return 1;
        if (b == "Geral") return -1;
        return a.compareTo(b);
      });
    return {for (final g in grupos) g: map[g]!};
  }

  Future<void> _criarItem() async {
    final tituloController = TextEditingController();
    final descricaoController = TextEditingController();
    bool critico = false;
    String grupo = "Geral";
    int ordem = 0;
    bool buscandoGrupo = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text("Novo item"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tituloController,
                decoration: const InputDecoration(labelText: "Título *"),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) async {
                  final t = tituloController.text.trim();
                  if (t.length < 5) return;
                  setLocalState(() => buscandoGrupo = true);
                  try {
                    final sugestao = await widget.api.sugerirGrupoItem(
                      etapaId: _etapa.id,
                      titulo: t,
                    );
                    setLocalState(() {
                      grupo = sugestao["grupo"] as String? ?? "Geral";
                      ordem = sugestao["ordem"] as int? ?? 0;
                      buscandoGrupo = false;
                    });
                  } catch (_) {
                    setLocalState(() => buscandoGrupo = false);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descricaoController,
                decoration: const InputDecoration(labelText: "Descrição"),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text("Grupo:", style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  buscandoGrupo
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Chip(
                          label: Text(grupo, style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                        ),
                ],
              ),
              StatefulBuilder(
                builder: (context, ss) => SwitchListTile(
                  title: const Text("Item crítico"),
                  subtitle: const Text("Exige evidência obrigatória"),
                  value: critico,
                  onChanged: (v) => ss(() => critico = v),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancelar")),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Salvar")),
          ],
        ),
      ),
    );

    if (created == true && tituloController.text.trim().isNotEmpty) {
      try {
        await widget.api.criarItem(
          etapaId: _etapa.id,
          titulo: tituloController.text.trim(),
          descricao: descricaoController.text.trim(),
          critico: critico,
          grupo: grupo,
          ordem: ordem,
        );
        await _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Erro: $e")));
        }
      }
    }
  }

  Future<bool> _confirmarRemocao(ChecklistItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remover item"),
        content: Text("Deseja remover \"${item.titulo}\"?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remover", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  Future<void> _deletarItem(ChecklistItem item) async {
    try {
      await widget.api.deletarItem(item.id);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro ao remover: $e")));
      }
    }
  }

  Future<void> _editarPrazo() async {
    DateTime? prazoPrevisto = _etapa.prazoPrevisto;
    DateTime? prazoExecutado = _etapa.prazoExecutado;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Prazo da etapa",
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _DatePickerRow(
                label: "Prazo previsto",
                value: prazoPrevisto,
                onChanged: (d) => setModal(() => prazoPrevisto = d),
              ),
              const SizedBox(height: 16),
              _DatePickerRow(
                label: "Data executado",
                value: prazoExecutado,
                onChanged: (d) => setModal(() => prazoExecutado = d),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      final etapaAtualizada =
                          await widget.api.atualizarPrazoEtapa(
                        etapaId: _etapa.id,
                        prazoPrevisto: prazoPrevisto,
                        prazoExecutado: prazoExecutado,
                      );
                      if (mounted) {
                        setState(() => _etapa = etapaAtualizada);
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Erro: $e")));
                      }
                    }
                  },
                  child: const Text("Salvar prazo"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "ok": return Colors.green;
      case "nao_conforme": return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case "ok": return "OK";
      case "nao_conforme": return "Não conforme";
      default: return "Pendente";
    }
  }

  bool get _prazoPendente =>
      _etapa.prazoPrevisto != null &&
      _etapa.prazoPrevisto!.isBefore(DateTime.now()) &&
      _etapa.prazoExecutado == null;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("dd/MM/yy");
    final prazoLabel = _etapa.prazoPrevisto != null
        ? fmt.format(_etapa.prazoPrevisto!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_etapa.nome),
        actions: [
          IconButton(
            onPressed: _editarPrazo,
            icon: Badge(
              isLabelVisible: _prazoPendente,
              child: const Icon(Icons.calendar_today_outlined),
            ),
            tooltip: prazoLabel != null
                ? "Prazo: $prazoLabel"
                : "Definir prazo",
          ),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _criarItem,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<ChecklistItem>>(
        future: _itensFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }
          final itens = snapshot.data ?? [];
          if (itens.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.checklist, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("Nenhum item no checklist",
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            );
          }
          final grupos = _agrupar(itens);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              children: [
                for (final entry in grupos.entries) ...[
                  _GrupoHeader(
                    nome: entry.key,
                    itens: entry.value,
                  ),
                  const SizedBox(height: 4),
                  for (final item in entry.value)
                    _ItemCard(
                      item: item,
                      statusColor: _statusColor(item.status),
                      statusLabel: _statusLabel(item.status),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetalheItemScreen(
                              item: item,
                              api: widget.api,
                              etapaNome: _etapa.nome,
                            ),
                          ),
                        );
                        await _refresh();
                      },
                      onDelete: () async {
                        if (await _confirmarRemocao(item)) {
                          await _deletarItem(item);
                        }
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Widgets auxiliares ──────────────────────────────────────────────────────

class _GrupoHeader extends StatelessWidget {
  const _GrupoHeader({required this.nome, required this.itens});

  final String nome;
  final List<ChecklistItem> itens;

  @override
  Widget build(BuildContext context) {
    final concluidos = itens.where((i) => i.status == "ok").length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            nome,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(
            "$concluidos/${itens.length}",
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const Expanded(child: Divider(indent: 8)),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.statusColor,
    required this.statusLabel,
    required this.onTap,
    required this.onDelete,
  });

  final ChecklistItem item;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // onDelete gerencia o dismiss
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.titulo,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      if (item.descricao != null && item.descricao!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            item.descricao!,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (item.critico) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Crítico",
                          style: TextStyle(color: Colors.red, fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == "remover") onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: "remover",
                      child: Row(children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text("Remover", style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("dd/MM/yyyy");
    return Row(
      children: [
        Expanded(
          child: Text(
            value != null ? "$label: ${fmt.format(value!)}" : label,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) onChanged(picked);
          },
          child: Text(value != null ? "Alterar" : "Selecionar"),
        ),
        if (value != null)
          IconButton(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () => onChanged(null),
          ),
      ],
    );
  }
}
```

**Step 2: Verificar que `intl` está no pubspec.yaml**

```bash
grep "intl" mobile/pubspec.yaml
```

Se não estiver, adicionar e rodar `flutter pub get`.

**Step 3: Hot reload e verificar visualmente**

```bash
cd mobile && flutter run -d chrome
```

Navegar até um checklist. Verificar:
- Itens agrupados por grupo com header "Piscina · 0/3"
- Cards clicáveis (navega para detalhe — DetalheItemScreen ainda não existe, causará erro)
- Badge de status no canto direito
- Ícone de calendário no AppBar

**Step 4: Commit**

```bash
git add mobile/lib/screens/checklist/checklist_screen.dart
git commit -m "feat: refactor ChecklistScreen with groups, status badge, prazo, clickable cards"
```

---

## Task 9: Flutter — criar DetalheItemScreen

**Files:**
- Create: `mobile/lib/screens/checklist/detalhe_item_screen.dart`

```dart
import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../../models/checklist_item.dart";
import "../../services/api_client.dart";
import "../normas/normas_screen.dart";

class DetalheItemScreen extends StatefulWidget {
  const DetalheItemScreen({
    super.key,
    required this.item,
    required this.api,
    required this.etapaNome,
  });

  final ChecklistItem item;
  final ApiClient api;
  final String etapaNome;

  @override
  State<DetalheItemScreen> createState() => _DetalheItemScreenState();
}

class _DetalheItemScreenState extends State<DetalheItemScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  late ChecklistItem _item;
  late TextEditingController _obsController;
  bool _salvandoObs = false;
  bool _salvandoStatus = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _obsController = TextEditingController(text: _item.observacao ?? "");
  }

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _atualizarStatus(String novoStatus) async {
    setState(() => _salvandoStatus = true);
    try {
      final atualizado = await widget.api.atualizarItem(
        itemId: _item.id,
        status: novoStatus,
      );
      if (mounted) setState(() => _item = atualizado);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    } finally {
      if (mounted) setState(() => _salvandoStatus = false);
    }
  }

  Future<void> _salvarObservacao() async {
    setState(() => _salvandoObs = true);
    try {
      final atualizado = await widget.api.atualizarItem(
        itemId: _item.id,
        observacao: _obsController.text.trim(),
      );
      if (mounted) {
        setState(() => _item = atualizado);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Observação salva.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    } finally {
      if (mounted) setState(() => _salvandoObs = false);
    }
  }

  Future<void> _adicionarEvidencia() async {
    final opcao = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Adicionar evidência"),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "camera"),
            child: const Row(children: [
              Icon(Icons.camera_alt), SizedBox(width: 12), Text("Tirar foto"),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "galeria"),
            child: const Row(children: [
              Icon(Icons.photo_library), SizedBox(width: 12), Text("Da galeria"),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "arquivo"),
            child: const Row(children: [
              Icon(Icons.attach_file), SizedBox(width: 12), Text("Arquivo"),
            ]),
          ),
        ],
      ),
    );
    if (opcao == null) return;
    try {
      if (opcao == "camera") {
        final img = await _imagePicker.pickImage(
            source: ImageSource.camera, imageQuality: 85);
        if (img == null) return;
        await widget.api.uploadEvidenciaImagem(itemId: _item.id, image: img);
      } else if (opcao == "galeria") {
        final img = await _imagePicker.pickImage(
            source: ImageSource.gallery, imageQuality: 85);
        if (img == null) return;
        await widget.api.uploadEvidenciaImagem(itemId: _item.id, image: img);
      } else {
        final result = await FilePicker.platform.pickFiles(withReadStream: true);
        if (result == null || result.files.isEmpty) return;
        await widget.api.uploadEvidencia(itemId: _item.id, file: result.files.first);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Evidência enviada.")));
        setState(() {}); // trigger FutureBuilder rebuild via refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case "ok": return Colors.green;
      case "nao_conforme": return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalhe do Item"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(_item.titulo,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              if (_item.critico)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text("Crítico",
                      style: TextStyle(color: Colors.red, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text("${_item.grupo} · ${widget.etapaNome}",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),

          // ── Descrição ───────────────────────────────────────────────
          if (_item.descricao != null && _item.descricao!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text("Descrição", style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(_item.descricao!, style: const TextStyle(fontSize: 14)),
          ],

          // ── Norma ───────────────────────────────────────────────────
          if (_item.normaReferencia != null) ...[
            const SizedBox(height: 16),
            Text("Norma de referência", style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.menu_book_outlined,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_item.normaReferencia!,
                      style: const TextStyle(fontSize: 13)),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NormasScreen(
                        api: widget.api,
                        etapaInicial: widget.etapaNome,
                      ),
                    ),
                  ),
                  child: const Text("Ver biblioteca"),
                ),
              ],
            ),
          ],

          // ── Status ──────────────────────────────────────────────────
          const SizedBox(height: 20),
          Text("Status", style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          _salvandoStatus
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    _StatusButton(
                      label: "Pendente",
                      icon: Icons.radio_button_unchecked,
                      color: Colors.grey,
                      selected: _item.status == "pendente",
                      onTap: () => _atualizarStatus("pendente"),
                    ),
                    const SizedBox(width: 8),
                    _StatusButton(
                      label: "OK",
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                      selected: _item.status == "ok",
                      onTap: () => _atualizarStatus("ok"),
                    ),
                    const SizedBox(width: 8),
                    _StatusButton(
                      label: "Não conforme",
                      icon: Icons.cancel_outlined,
                      color: Colors.red,
                      selected: _item.status == "nao_conforme",
                      onTap: () => _atualizarStatus("nao_conforme"),
                    ),
                  ],
                ),

          // ── Evidências ──────────────────────────────────────────────
          const SizedBox(height: 24),
          Row(
            children: [
              Text("Evidências", style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: _adicionarEvidencia,
                icon: const Icon(Icons.add_a_photo, size: 18),
                label: const Text("Adicionar"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder(
            future: widget.api.listarEvidencias(_item.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final evidencias = snapshot.data ?? [];
              if (evidencias.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text("Nenhuma evidência ainda.",
                        style: TextStyle(color: Colors.grey)),
                  ),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: evidencias.length,
                itemBuilder: (context, i) {
                  final ev = evidencias[i];
                  final isImage = ev.mimeType?.startsWith("image/") == true;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: isImage
                        ? Image.network(ev.arquivoUrl, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.attach_file,
                                color: Colors.grey),
                          ),
                  );
                },
              );
            },
          ),

          // ── Observação ──────────────────────────────────────────────
          const SizedBox(height: 24),
          Text("Observação", style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _obsController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: "Anotações sobre este item...",
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _salvandoObs ? null : _salvarObservacao,
              child: _salvandoObs
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text("Salvar observação"),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Widget auxiliar ─────────────────────────────────────────────────────────

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.grey.withValues(alpha: 0.3),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : Colors.grey, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? color : Colors.grey,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 2: Hot reload e testar**

Clicar em um item do checklist. Verificar:
- Tela abre com título, grupo, descrição
- Botões de status funcionam (API call)
- Seção de evidências lista fotos
- Botão "Adicionar" abre picker
- Campo observação salva

**Step 3: Commit**

```bash
git add mobile/lib/screens/checklist/detalhe_item_screen.dart
git commit -m "feat: create DetalheItemScreen with status, evidencias, observacao, norma"
```

---

## Task 10: Flutter — integrar normas do checklist na NormasScreen

**Files:**
- Modify: `mobile/lib/screens/normas/normas_screen.dart`

**Step 1: Adicionar parâmetro `etapaId` opcional ao widget**

Localizar:
```dart
class NormasScreen extends StatefulWidget {
  const NormasScreen({super.key, this.etapaInicial, required this.api});

  final String? etapaInicial;
  final ApiClient api;
```

Substituir por:
```dart
class NormasScreen extends StatefulWidget {
  const NormasScreen({super.key, this.etapaInicial, this.etapaId, required this.api});

  final String? etapaInicial;
  final String? etapaId;   // se fornecido, carrega normas do checklist desta etapa
  final ApiClient api;
```

**Step 2: Adicionar state para normas do checklist**

No `_NormasScreenState`, adicionar:
```dart
  List<String>? _normasChecklist;
  bool _carregandoNormasChecklist = false;
```

**Step 3: Carregar normas no initState**

No `initState`, após `_etapaSelecionada = ...`, adicionar:
```dart
    if (widget.etapaId != null) {
      _carregarNormasChecklist();
    }
```

**Step 4: Método `_carregarNormasChecklist`**

```dart
  Future<void> _carregarNormasChecklist() async {
    setState(() => _carregandoNormasChecklist = true);
    try {
      final normas = await widget.api.listarNormasChecklist(widget.etapaId!);
      if (mounted) setState(() => _normasChecklist = normas);
    } catch (_) {
      // Falha silenciosa — não impede o uso da biblioteca
    } finally {
      if (mounted) setState(() => _carregandoNormasChecklist = false);
    }
  }
```

**Step 5: Exibir seção no body**

Localizar no `build()` o início do `body: Column(...)`, após o container do filtro (`Expanded(...)`), adicionar logo antes do Expanded que mostra os resultados:

```dart
          if (widget.etapaId != null) ...[
            if (_carregandoNormasChecklist)
              const LinearProgressIndicator(),
            if (_normasChecklist != null && _normasChecklist!.isNotEmpty)
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Normas identificadas nesta etapa",
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _normasChecklist!.map((norma) => ActionChip(
                        label: Text(norma, style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          // Pre-selecionar a etapa e buscar
                          _buscar();
                        },
                      )).toList(),
                    ),
                  ],
                ),
              ),
          ],
```

**Step 6: Hot reload e testar**

Navegar: Etapa → Checklist → item com norma → "Ver biblioteca". Verificar que a seção "Normas identificadas nesta etapa" aparece com chips das normas do checklist.

**Step 7: Commit**

```bash
git add mobile/lib/screens/normas/normas_screen.dart
git commit -m "feat: show checklist normas in NormasScreen when opened from etapa"
```

---

## Task 11: Deploy final e smoke test

**Step 1: Build release do Flutter (opcional, para testar APK)**

```bash
cd mobile
flutter build apk --release
```

**Step 2: Deploy backend (se houver mudanças pendentes)**

```bash
cd server
bash deploy-cloudrun.sh
```

**Step 3: Smoke test completo**

1. Criar uma obra com etapas
2. Ir ao Checklist Inteligente → Aplicar itens
3. Verificar que itens aparecem agrupados por categoria (Piscina, Churrasqueira, etc.)
4. Clicar em um item → Tela de detalhe abre
5. Mudar status → Verificar badge atualiza na lista
6. Adicionar foto → Verificar galeria
7. Salvar observação → Verificar persiste
8. AppBar → Calendário → Definir prazo → Verificar badge vermelho se vencido
9. Abrir Biblioteca Normativa a partir de um item → Verificar seção "Normas identificadas"

**Step 4: Commit final**

```bash
git add -A
git commit -m "feat: complete checklist groups, detail screen, normas integration"
```
