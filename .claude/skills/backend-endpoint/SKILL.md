---
name: backend-endpoint
description: Adiciona um novo endpoint FastAPI ao backend do Mestre da Obra. Use quando precisar criar um novo endpoint na API Python.
disable-model-invocation: false
---

# Adicionar endpoint FastAPI — Mestre da Obra

Crie o endpoint: **$ARGUMENTS**

## Contexto do projeto

- Backend: FastAPI + SQLModel + PostgreSQL
- Arquivo principal de rotas: `server/app/main.py`
- Modelos ORM: `server/app/models.py`
- Schemas Pydantic: `server/app/schemas.py`
- Enums: `server/app/enums.py`
- Storage S3: `server/app/storage.py`
- Migrações: `server/alembic/versions/`

## Padrões obrigatórios

1. **Response model**: Sempre declarar `response_model=` no decorator
2. **Dependency injection**: Usar `session: Session = Depends(get_session)`
3. **404**: Sempre verificar existência do recurso antes de operar
4. **Timestamps**: Sempre atualizar `updated_at = datetime.utcnow()` no PATCH
5. **UUID**: Usar `UUID` como tipo dos path params (FastAPI converte automaticamente)
6. **Idioma**: Mensagens de erro em português

## Estrutura de um endpoint padrão

```python
@app.patch("/api/recurso/{recurso_id}", response_model=RecursoRead)
def atualizar_recurso(
    recurso_id: UUID,
    payload: RecursoUpdate,
    session: Session = Depends(get_session),
) -> Recurso:
    recurso = session.get(Recurso, recurso_id)
    if not recurso:
        raise HTTPException(status_code=404, detail="Recurso nao encontrado")
    updates = payload.model_dump(exclude_unset=True, mode="json")
    for key, value in updates.items():
        setattr(recurso, key, value)
    recurso.updated_at = datetime.utcnow()
    session.add(recurso)
    session.commit()
    session.refresh(recurso)
    return recurso
```

## Para novos modelos, siga a ordem:

1. Adicionar classe em `server/app/models.py` herdando de `SQLModel, table=True`
2. Adicionar schemas em `server/app/schemas.py` (Create, Read, Update)
3. Adicionar enums em `server/app/enums.py` se necessário
4. Criar migration em `server/alembic/versions/` com timestamp + descrição
5. Adicionar endpoint em `server/app/main.py`

## Passos

1. Leia `server/app/main.py` para entender os padrões existentes
2. Leia `server/app/models.py` e `server/app/schemas.py`
3. Implemente o endpoint seguindo os padrões acima
4. Se criar nova tabela, crie também a migration Alembic
