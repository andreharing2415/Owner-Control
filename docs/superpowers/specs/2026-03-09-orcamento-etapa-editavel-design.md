# Orçamento por Etapa — Previsto + Realizado Editáveis

**Data:** 2026-03-09
**Status:** Aprovado

## Objetivo

Permitir que o dono da obra edite manualmente `valor_previsto` e `valor_realizado` por etapa em uma tela dedicada. O `valor_realizado` manual tem prioridade sobre a soma automática de despesas (fallback).

## Decisões

- **Ambos editáveis** — `valor_previsto` e `valor_realizado` são campos manuais
- **Prioridade do realizado** — se `valor_realizado` preenchido, usa ele; senão, soma despesas
- **Tela separada** — botão na FinanceiroScreen abre OrcamentoEditScreen com todas as etapas
- **Abordagem A** — coluna nova na tabela `OrcamentoEtapa` existente (sem tabela extra)

## Backend

### Modelo

`OrcamentoEtapa` ganha 1 coluna:

```python
valor_realizado: Optional[float] = None  # None = fallback para soma despesas
```

### Migração Alembic

`20260309_0014_add_valor_realizado.py`:

```sql
ALTER TABLE orcamentoetapa ADD COLUMN valor_realizado FLOAT NULL;
```

### Schemas

`OrcamentoEtapaCreate` e `OrcamentoEtapaRead` ganham:

```python
valor_realizado: Optional[float] = None
```

### Endpoints

- `POST /api/obras/{obra_id}/orcamento` — já faz upsert, passa a gravar `valor_realizado` também
- `GET /api/obras/{obra_id}/orcamento` — retorna o novo campo

### Relatório Financeiro

Lógica de cálculo do realizado por etapa muda:

```
gasto = orcamento.valor_realizado se preenchido, senão soma_despesas_da_etapa
```

## Flutter

### Nova Tela: `OrcamentoEditScreen`

- Localização: `mobile/lib/screens/financeiro/orcamento_edit_screen.dart`
- Recebe `obraId` e `api`
- Carrega etapas da obra + orçamentos existentes
- Lista de etapas com 2 `TextFormField` cada: "Previsto (R$)" e "Realizado (R$)"
- Botão "Salvar" → `POST /api/obras/{obra_id}/orcamento`
- Validação: >= 0, numérico
- Sucesso: volta e faz refresh da FinanceiroScreen

### Acesso

- Botão na AppBar da `FinanceiroScreen` (ícone edição) → navega para `OrcamentoEditScreen`

### Model Flutter

`OrcamentoEtapa` em `financeiro.dart` ganha `valorRealizado: double?`

### API Client

`salvarOrcamento()` já existe — payload estendido com `valor_realizado`

## Fluxo

```
OrcamentoEditScreen → POST /orcamento [{etapa_id, valor_previsto, valor_realizado}]
                    → Backend upsert OrcamentoEtapa
                    → Pop → FinanceiroScreen refresh → GET /relatorio
                    → Relatório: valor_realizado ?? soma_despesas
```
