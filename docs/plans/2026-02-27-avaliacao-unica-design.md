# Design: Avaliacao Unica por Usuario+Prestador

## Problema

O model `Avaliacao` nao tem `user_id`, permitindo avaliacoes ilimitadas do mesmo prestador pelo mesmo usuario. Isso infla as medias e nao reflete a realidade.

## Regra de Negocio

- Cada usuario pode avaliar um prestador **apenas 1 vez**
- Se quiser mudar, deve **editar** a avaliacao existente
- A UI deve refletir isso: FAB muda de "Avaliar" para "Editar Avaliacao"

## Solucao

### Backend

1. **Model `Avaliacao`** — Adicionar `user_id: UUID` (FK para `user.id`), com `UniqueConstraint("prestador_id", "user_id")`
2. **Migration Alembic** — Nova migration adicionando coluna `user_id` (nullable para dados legados) e unique constraint parcial (onde `user_id IS NOT NULL`)
3. **POST `/api/prestadores/{id}/avaliacoes`** — Verificar se ja existe avaliacao do user. Se existir, retornar `409 Conflict` com body contendo a avaliacao existente
4. **PATCH `/api/prestadores/{id}/avaliacoes/{avaliacao_id}`** — Novo endpoint para editar. Valida ownership (`avaliacao.user_id == current_user.id`)
5. **GET `/api/prestadores/{id}/minha-avaliacao`** — Retorna avaliacao do user atual ou 404
6. **Schema `AvaliacaoRead`** — Incluir `user_id: Optional[UUID]`

### Flutter

1. **ApiClient** — Novos metodos: `getMinhaAvaliacao(prestadorId)`, `atualizarAvaliacao(prestadorId, avaliacaoId, dados)`
2. **DetalhePrestadorScreen** — Ao carregar, chamar `getMinhaAvaliacao()`. Se existir: FAB com icone edit e texto "Editar Avaliacao". Se nao: FAB com icone star e texto "Avaliar"
3. **AvaliarPrestadorScreen** — Aceitar `AvaliacaoPrestador?` opcional. Se preenchido: pre-preencher campos, usar `atualizarAvaliacao()` no submit, titulo "Editar Avaliacao". Se nao: fluxo atual de criacao
4. **Lista de avaliacoes** — Destacar a avaliacao do proprio usuario com badge "Sua avaliacao"

### Dados Existentes

- Avaliacoes sem `user_id` ficam com `NULL` — constraint unique so se aplica onde `user_id IS NOT NULL`
- Nenhum dado existente e perdido ou quebrado
