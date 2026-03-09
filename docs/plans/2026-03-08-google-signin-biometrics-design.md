# Design: Google Sign-In + Login Biométrico

**Data:** 2026-03-08
**Status:** Aprovado

---

## Contexto

Auth atual usa JWT próprio (bcrypt + python-jose). Login via email/senha, cadastro com nome/email/telefone/senha. O objetivo é adicionar Google Sign-In e login biométrico opcional sem quebrar o fluxo existente.

---

## Abordagem Escolhida

**Google ID Token verificado no backend (Opção A)**

O Flutter obtém um ID Token via `google_sign_in`, envia ao backend FastAPI, que verifica com a biblioteca `google-auth` e emite nosso JWT padrão. Biometria desbloqueia tokens armazenados em `flutter_secure_storage`.

---

## Banco de Dados

**Alterações no modelo `User`:**

```python
google_id: Optional[str] = Field(default=None, unique=True, index=True)
password_hash: Optional[str] = Field(default=None)  # era obrigatório
```

**Migração Alembic:**
- Adicionar coluna `google_id` (VARCHAR, nullable, unique)
- Alterar `password_hash` para nullable

---

## Backend (FastAPI)

### Novo endpoint: `POST /auth/google`

```
Body: { id_token: str }
Response: { access_token, refresh_token, is_new_user: bool }
```

Fluxo interno:
1. Verificar `id_token` com `google.oauth2.id_token.verify_oauth2_token()`
2. Extrair `sub` (google_id), `email`, `name` do payload
3. Buscar user por `google_id` ou `email`
   - Encontrou por email (user existente, sem google_id): vincular google_id
   - Encontrou por google_id: login direto
   - Não encontrou: criar user novo (`password_hash=None`)
4. Retornar tokens JWT + `is_new_user`

### Alteração: `PATCH /auth/me`

Já existente ou a criar. Permite atualizar `nome` e `telefone` (para Google users completarem o perfil).

### Variável de ambiente nova

`GOOGLE_CLIENT_ID` — client ID web do OAuth 2.0, usado para verificar tokens.

---

## GCP / OAuth 2.0

1. **Tela de consentimento OAuth** — configurar nome, logo, domínio
2. **Client ID Android** — com SHA-1 do keystore (debug + release)
3. **Client ID iOS** — para publicação futura
4. **Client ID Web** — necessário para o backend verificar ID Tokens
5. **Variável `GOOGLE_CLIENT_ID`** no Cloud Run (client ID web)

---

## Flutter

### Packages novos

| Package | Uso |
|---|---|
| `google_sign_in` | Fluxo OAuth nativo Google |
| `local_auth` | Biometria (fingerprint/face) |
| `flutter_secure_storage` | Tokens em KeyStore/Keychain (substitui SharedPreferences para tokens) |

### Fluxo Google Sign-In

```
LoginScreen
  → botão "Entrar com Google"
  → google_sign_in.signIn() → obter idToken
  → POST /auth/google {id_token}
  → salvar tokens no flutter_secure_storage
  → is_new_user == true → CompleteProfileScreen (nome + telefone)
  → checar biometria disponível → dialog "Ativar biometria?"
  → HomeScreen
```

### Fluxo Email/Senha (sem mudança funcional)

```
LoginScreen → POST /auth/login → salvar tokens → checar biometria → HomeScreen
```

### Fluxo Biometria

```
App start
  → biometria habilitada pelo user?
  → local_auth.authenticate()
  → sucesso → carregar tokens do secure_storage → GET /auth/me
  → HomeScreen
```

### Prompt de ativação de biometria

Após qualquer login bem-sucedido (Google ou email/senha), se:
- Dispositivo suporta biometria (`local_auth.isDeviceSupported()`)
- Usuário ainda não respondeu à pergunta (`biometrics_prompted` não salvo)

Exibir dialog:
> **"Login mais rápido"**
> "Deseja usar biometria (digital ou reconhecimento facial) para entrar sem digitar senha?"
> [Não agora] [Ativar]

Preferência salva em `SharedPreferences` (`biometrics_enabled`, `biometrics_prompted`).

### Telas e arquivos afetados

| Arquivo | Mudança |
|---|---|
| `login_screen.dart` | Adicionar botão Google + botão biometria (se habilitada) |
| `registro_screen.dart` | Sem mudança |
| `complete_profile_screen.dart` | **Nova** — nome + telefone para users Google |
| `auth_provider.dart` | Métodos: `loginWithGoogle()`, `loginWithBiometrics()`, `setBiometricsEnabled()`, migrar tokens para `flutter_secure_storage` |
| `models/auth.dart` | Adicionar campo `googleId` e `hasPassword` no modelo User |
| `services/api_client.dart` | Adicionar chamada `POST /auth/google` e `PATCH /auth/me` |
| `perfil_screen.dart` | Toggle "Gerenciar biometria" (habilitar/desabilitar) |

---

## Segurança

- Tokens JWT armazenados em `flutter_secure_storage` (KeyStore Android, Keychain iOS)
- ID Token do Google tem validade curta (1h) — apenas usado para troca no backend
- Biometria não autentica no backend — apenas desbloqueia tokens locais
- Usuários com `password_hash=None` não podem usar login email/senha

---

## O que NÃO muda

- Fluxo de registro email/senha (nome, email, telefone, senha)
- Geração e validação de JWT no backend
- Todos os outros endpoints (nenhuma mudança de autorização)
