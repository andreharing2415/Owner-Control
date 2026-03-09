# Google Sign-In + Biometric Login Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Adicionar login com Google e login biométrico opcional ao app Mestre da Obra, mantendo o fluxo email/senha intacto.

**Architecture:** Flutter obtém ID Token via `google_sign_in`, backend FastAPI verifica com `google-auth`, emite JWT próprio. Biometria desbloqueia tokens armazenados em `flutter_secure_storage` localmente, sem nova chamada de auth no backend.

**Tech Stack:** FastAPI + `google-auth` (backend), `google_sign_in` + `local_auth` + `flutter_secure_storage` (Flutter).

---

## Task 1: GCP — Configurar OAuth 2.0

**Files:** nenhum arquivo de código — passos manuais no console GCP.

**Passo 1: Tela de consentimento OAuth**

1. Acessar [console.cloud.google.com](https://console.cloud.google.com) → projeto `mestreobra`
2. Menu → APIs & Services → OAuth consent screen
3. Tipo: **External** → Create
4. Preencher: App name = "Mestre da Obra", User support email = `andrefharing@gmail.com`
5. Scopes: adicionar `email` e `profile`
6. Save and Continue em todas as etapas

**Passo 2: Criar Client ID Web (usado pelo backend)**

1. APIs & Services → Credentials → Create Credentials → OAuth 2.0 Client ID
2. Application type: **Web application**
3. Name: `mestreobra-backend`
4. Authorized redirect URIs: deixar vazio (não usamos redirect, usamos ID Token)
5. Criar → copiar o **Client ID** (formato: `XXXXX.apps.googleusercontent.com`)
6. Salvar — este será o `GOOGLE_CLIENT_ID` do Cloud Run

**Passo 3: Criar Client ID Android**

1. Create Credentials → OAuth 2.0 Client ID
2. Application type: **Android**
3. Package name: `br.mestredaobra.app`
4. SHA-1 do debug keystore — obter rodando:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
   (No Windows: `%USERPROFILE%\.android\debug.keystore`)
5. Criar → não precisa baixar nada, só registrar o SHA-1

**Passo 4: Configurar variável no Cloud Run**

```bash
gcloud run services update mestreobra-backend \
  --region us-central1 \
  --update-env-vars GOOGLE_CLIENT_ID=SEU_WEB_CLIENT_ID_AQUI \
  --project mestreobra
```

**Verificação:** `gcloud run services describe mestreobra-backend --region us-central1 --project mestreobra --format="value(spec.template.spec.containers[0].env)"` deve mostrar `GOOGLE_CLIENT_ID`.

---

## Task 2: Backend — Migração Alembic

**Files:**
- Create: `server/alembic/versions/20260308_0010_google_auth.py`
- Modify: `server/app/models.py`

**Passo 1: Editar `server/app/models.py`**

Localizar a classe `User` (linha 10) e fazer duas alterações:

```python
# ANTES:
password_hash: str

# DEPOIS:
password_hash: Optional[str] = Field(default=None)
google_id: Optional[str] = Field(default=None, unique=True, index=True)
```

Resultado final da classe `User`:

```python
class User(SQLModel, table=True):
    """Usuário proprietário da plataforma."""
    id: UUID = Field(default_factory=uuid4, primary_key=True, index=True)
    email: str = Field(unique=True, index=True)
    password_hash: Optional[str] = Field(default=None)
    google_id: Optional[str] = Field(default=None, unique=True, index=True)
    nome: str
    telefone: Optional[str] = None
    role: str = Field(default="owner")
    ativo: bool = Field(default=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
```

**Passo 2: Criar a migração**

Criar arquivo `server/alembic/versions/20260308_0010_google_auth.py`:

```python
"""add google_id to user, make password_hash nullable

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
    op.add_column("user", sa.Column("google_id", sa.String(), nullable=True))
    op.create_unique_constraint("uq_user_google_id", "user", ["google_id"])
    op.create_index("ix_user_google_id", "user", ["google_id"])
    op.alter_column("user", "password_hash", nullable=True)


def downgrade() -> None:
    op.alter_column("user", "password_hash", nullable=False)
    op.drop_index("ix_user_google_id", table_name="user")
    op.drop_constraint("uq_user_google_id", "user", type_="unique")
    op.drop_column("user", "google_id")
```

**Passo 3: Rodar a migração localmente para testar (opcional, roda em produção no deploy)**

```bash
cd server
alembic upgrade head
```

**Passo 4: Commit**

```bash
git add server/app/models.py server/alembic/versions/20260308_0010_google_auth.py
git commit -m "feat: add google_id to User, make password_hash optional"
```

---

## Task 3: Backend — Dependência `google-auth`

**Files:**
- Modify: `server/requirements.txt`

**Passo 1: Adicionar ao `server/requirements.txt`**

Após a linha `python-jose[cryptography]==3.3.0`, adicionar:

```
google-auth==2.29.0
```

**Passo 2: Verificar se instala sem conflito**

```bash
cd server
pip install google-auth==2.29.0
```

Esperado: instalação sem erros.

**Passo 3: Commit**

```bash
git add server/requirements.txt
git commit -m "feat: add google-auth dependency"
```

---

## Task 4: Backend — Schemas para Google Auth

**Files:**
- Modify: `server/app/schemas.py`

**Passo 1: Adicionar novos schemas em `server/app/schemas.py`**

Logo após a classe `TokenRefreshRequest` (linha 43), adicionar:

```python
class GoogleLoginRequest(SQLModel):
    id_token: str


class GoogleTokenResponse(SQLModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: "UserRead"
    is_new_user: bool


class UpdateProfileRequest(SQLModel):
    nome: Optional[str] = None
    telefone: Optional[str] = None
```

Também atualizar `UserRead` para expor `has_password` (útil no Flutter para saber se o user pode fazer login com senha):

```python
class UserRead(SQLModel):
    id: UUID
    email: str
    nome: str
    telefone: Optional[str] = None
    role: str
    has_password: bool = False
    created_at: datetime

    @classmethod
    def from_user(cls, user: "User") -> "UserRead":
        return cls(
            id=user.id,
            email=user.email,
            nome=user.nome,
            telefone=user.telefone,
            role=user.role,
            has_password=user.password_hash is not None,
            created_at=user.created_at,
        )
```

> **Nota:** Como `UserRead` é usado em `TokenResponse`, e `TokenResponse.user` é um `UserRead`, o campo `has_password` será incluído automaticamente em todas as respostas de auth.

**Passo 2: Atualizar `TokenResponse` para usar `from_user` nos endpoints**

Não é necessário alterar a schema `TokenResponse` em si — o ajuste fica nos endpoints em `main.py` (Task 5).

**Passo 3: Commit**

```bash
git add server/app/schemas.py
git commit -m "feat: add Google auth schemas and has_password to UserRead"
```

---

## Task 5: Backend — Endpoint `POST /api/auth/google`

**Files:**
- Modify: `server/app/main.py`

**Passo 1: Adicionar imports no topo de `main.py`**

Após a linha `from .auth import hash_password, ...`, adicionar:

```python
from google.oauth2 import id_token as google_id_token
from google.auth.transport import requests as google_requests
```

Adicionar import dos novos schemas (atualizar a lista de imports do schemas):

```python
from .schemas import (
    # ... (todos os existentes) ...,
    GoogleLoginRequest,
    GoogleTokenResponse,
    UpdateProfileRequest,
)
```

**Passo 2: Atualizar endpoint de registro para usar `UserRead.from_user()`**

Localizar `@app.post("/api/auth/register", ...)` e substituir a linha de retorno:

```python
# ANTES:
return TokenResponse(
    access_token=create_access_token(str(user.id)),
    refresh_token=create_refresh_token(str(user.id)),
    user=UserRead.model_validate(user),
)

# DEPOIS:
return TokenResponse(
    access_token=create_access_token(str(user.id)),
    refresh_token=create_refresh_token(str(user.id)),
    user=UserRead.from_user(user),
)
```

Fazer o mesmo para `@app.post("/api/auth/login", ...)` — trocar `UserRead.model_validate(user)` por `UserRead.from_user(user)`.

**Passo 3: Adicionar endpoint Google logo após os endpoints de auth existentes**

```python
@app.post("/api/auth/google", response_model=GoogleTokenResponse)
def login_google(payload: GoogleLoginRequest, session: Session = Depends(get_session)):
    """Verifica um Google ID Token e retorna JWT próprio."""
    google_client_id = os.getenv("GOOGLE_CLIENT_ID")
    if not google_client_id:
        raise HTTPException(status_code=500, detail="Google login nao configurado")

    try:
        info = google_id_token.verify_oauth2_token(
            payload.id_token,
            google_requests.Request(),
            google_client_id,
        )
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Token Google invalido: {e}")

    google_sub = info["sub"]
    email = info.get("email", "").lower().strip()
    nome_google = info.get("name", "")

    # Buscar por google_id primeiro, depois por email
    user = session.exec(select(User).where(User.google_id == google_sub)).first()
    is_new_user = False

    if not user and email:
        user = session.exec(select(User).where(User.email == email)).first()
        if user:
            # Usuário existente (email/senha) — vincular google_id
            user.google_id = google_sub
            session.add(user)
            session.commit()
            session.refresh(user)

    if not user:
        # Novo usuário via Google
        is_new_user = True
        user = User(
            email=email,
            password_hash=None,
            google_id=google_sub,
            nome=nome_google or email.split("@")[0],
        )
        session.add(user)
        session.commit()
        session.refresh(user)

    if not user.ativo:
        raise HTTPException(status_code=403, detail="Conta desativada")

    return GoogleTokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        user=UserRead.from_user(user),
        is_new_user=is_new_user,
    )
```

**Passo 4: Adicionar endpoint `PATCH /api/auth/me`**

```python
@app.patch("/api/auth/me", response_model=UserRead)
def atualizar_perfil(
    payload: UpdateProfileRequest,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Atualiza nome e/ou telefone do usuário autenticado."""
    if payload.nome is not None:
        current_user.nome = payload.nome.strip()
    if payload.telefone is not None:
        current_user.telefone = payload.telefone.strip() or None
    current_user.updated_at = datetime.utcnow()
    session.add(current_user)
    session.commit()
    session.refresh(current_user)
    return UserRead.from_user(current_user)
```

**Passo 5: Commit**

```bash
git add server/app/main.py
git commit -m "feat: add POST /api/auth/google and PATCH /api/auth/me endpoints"
```

---

## Task 6: Backend — Deploy

**Files:** nenhum novo.

**Passo 1: Deploy para Cloud Run**

```bash
cd server
bash deploy-cloudrun.sh
```

Aguardar conclusão. O script já sobe a imagem e roda as migrações Alembic.

**Passo 2: Verificar endpoint Google**

```bash
curl -X POST https://mestreobra-backend-530484413221.us-central1.run.app/api/auth/google \
  -H "Content-Type: application/json" \
  -d '{"id_token": "token_invalido_para_teste"}'
```

Esperado: `401 Token Google invalido`.

**Passo 3: Verificar endpoint patch**

```bash
curl -X PATCH https://mestreobra-backend-530484413221.us-central1.run.app/api/auth/me \
  -H "Authorization: Bearer SEU_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"nome": "Teste", "telefone": "11999999999"}'
```

Esperado: `200` com dados do usuário.

---

## Task 7: Flutter — Adicionar packages

**Files:**
- Modify: `mobile/pubspec.yaml`
- Modify: `mobile/android/app/src/main/AndroidManifest.xml`

**Passo 1: Adicionar ao `mobile/pubspec.yaml`** (seção `dependencies:`):

```yaml
  google_sign_in: ^6.2.1
  local_auth: ^2.3.0
  flutter_secure_storage: ^9.2.2
```

**Passo 2: Adicionar permissões Android em `mobile/android/app/src/main/AndroidManifest.xml`**

Dentro de `<manifest>`, antes de `<application>`:

```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.USE_FINGERPRINT"/>
```

Dentro de `<application>`:

```xml
<!-- Google Sign-In: necessário para o fluxo OAuth -->
<meta-data
    android:name="com.google.android.gms.version"
    android:value="@integer/google_play_services_version" />
```

**Passo 3: Rodar `flutter pub get`**

```bash
cd mobile
flutter pub get
```

Esperado: sem erros. Se houver conflito de versão, ajustar para versão compatível.

**Passo 4: Commit**

```bash
git add mobile/pubspec.yaml mobile/pubspec.lock mobile/android/app/src/main/AndroidManifest.xml
git commit -m "feat: add google_sign_in, local_auth, flutter_secure_storage packages"
```

---

## Task 8: Flutter — Serviço de armazenamento seguro de tokens

**Files:**
- Create: `mobile/lib/services/secure_storage.dart`

**Passo 1: Criar `mobile/lib/services/secure_storage.dart`**

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centraliza o armazenamento seguro de tokens e preferências de auth.
class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _accessKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';
  static const _biometricsEnabledKey = 'biometrics_enabled';
  static const _biometricsPromptedKey = 'biometrics_prompted';

  static Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  static Future<({String access, String refresh})?> loadTokens() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) return null;
    return (access: access, refresh: refresh);
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  static Future<bool> isBiometricsEnabled() async {
    return await _storage.read(key: _biometricsEnabledKey) == 'true';
  }

  static Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _biometricsEnabledKey, value: enabled.toString());
  }

  static Future<bool> wasBiometricsPrompted() async {
    return await _storage.read(key: _biometricsPromptedKey) == 'true';
  }

  static Future<void> markBiometricsPrompted() async {
    await _storage.write(key: _biometricsPromptedKey, value: 'true');
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
```

**Passo 2: Commit**

```bash
git add mobile/lib/services/secure_storage.dart
git commit -m "feat: add SecureStorage service for tokens and biometric prefs"
```

---

## Task 9: Flutter — Atualizar modelo `auth.dart` e `api_client.dart`

**Files:**
- Modify: `mobile/lib/models/auth.dart`
- Modify: `mobile/lib/services/api_client.dart`

**Passo 1: Atualizar classe `User` em `mobile/lib/models/auth.dart`**

Localizar a classe `User` e adicionar o campo `hasPassword`:

```dart
class User {
  User({
    required this.id,
    required this.email,
    required this.nome,
    this.telefone,
    required this.role,
    this.hasPassword = true,
  });

  final String id;
  final String email;
  final String nome;
  final String? telefone;
  final String role;
  final bool hasPassword;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      nome: json['nome'] as String,
      telefone: json['telefone'] as String?,
      role: json['role'] as String? ?? 'owner',
      hasPassword: json['has_password'] as bool? ?? true,
    );
  }
}
```

Adicionar classe `GoogleAuthResult` após `AuthTokens`:

```dart
class GoogleAuthResult {
  GoogleAuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.isNewUser,
  });

  final String accessToken;
  final String refreshToken;
  final User user;
  final bool isNewUser;

  factory GoogleAuthResult.fromJson(Map<String, dynamic> json) {
    return GoogleAuthResult(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      isNewUser: json['is_new_user'] as bool? ?? false,
    );
  }
}
```

**Passo 2: Adicionar métodos em `mobile/lib/services/api_client.dart`**

Localizar o final dos métodos de auth (após `getMe()`) e adicionar:

```dart
Future<GoogleAuthResult> loginWithGoogle(String idToken) async {
  final response = await _post('/api/auth/google', body: {'id_token': idToken});
  _assertOk(response, 'Login com Google falhou');
  return GoogleAuthResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>);
}

Future<User> updateProfile({String? nome, String? telefone}) async {
  final body = <String, dynamic>{};
  if (nome != null) body['nome'] = nome;
  if (telefone != null) body['telefone'] = telefone;
  final response = await _patch('/api/auth/me', body: body);
  _assertOk(response, 'Erro ao atualizar perfil');
  return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
}
```

> **Nota:** Se não existir método `_patch` no `api_client.dart`, adicioná-lo seguindo o mesmo padrão de `_post`:
>
> ```dart
> Future<http.Response> _patch(String path, {Object? body}) async {
>   final response = await _client.patch(
>     _uri(path),
>     headers: _headers,
>     body: body != null ? jsonEncode(body) : null,
>   );
>   if (response.statusCode == 401 && _refreshToken != null) {
>     final refreshed = await _tryRefresh();
>     if (refreshed) {
>       return _client.patch(
>         _uri(path),
>         headers: _headers,
>         body: body != null ? jsonEncode(body) : null,
>       );
>     }
>   }
>   return response;
> }
> ```

**Passo 3: Commit**

```bash
git add mobile/lib/models/auth.dart mobile/lib/services/api_client.dart
git commit -m "feat: add GoogleAuthResult model, loginWithGoogle and updateProfile to ApiClient"
```

---

## Task 10: Flutter — Atualizar `AuthProvider`

**Files:**
- Modify: `mobile/lib/providers/auth_provider.dart`

**Passo 1: Substituir o conteúdo de `auth_provider.dart` pelo seguinte:**

```dart
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';

import '../models/auth.dart';
import '../services/api_client.dart';
import '../services/secure_storage.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({required this.api});

  final ApiClient api;
  User? _user;
  bool _loading = true;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get loading => _loading;

  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // serverClientId: lido de dart-define ou hardcoded — ver Task 11
  );
  final _localAuth = LocalAuthentication();

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    try {
      final tokens = await SecureStorage.loadTokens();
      if (tokens != null) {
        api.setTokens(access: tokens.access, refresh: tokens.refresh);
        _user = await api.getMe();
      }
    } catch (_) {
      api.clearTokens();
      await SecureStorage.clearTokens();
    }
    _loading = false;
    notifyListeners();
  }

  // ─── Email/Senha ───────────────────────────────────────────────────────────

  Future<void> login({required String email, required String password}) async {
    final tokens = await api.login(email: email, password: password);
    await SecureStorage.saveTokens(tokens.accessToken, tokens.refreshToken);
    api.setTokens(access: tokens.accessToken, refresh: tokens.refreshToken);
    _user = await api.getMe();
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String nome,
    String? telefone,
  }) async {
    final tokens = await api.register(
      email: email,
      password: password,
      nome: nome,
      telefone: telefone,
    );
    await SecureStorage.saveTokens(tokens.accessToken, tokens.refreshToken);
    api.setTokens(access: tokens.accessToken, refresh: tokens.refreshToken);
    _user = await api.getMe();
    notifyListeners();
  }

  // ─── Google ────────────────────────────────────────────────────────────────

  /// Retorna `true` se for usuário novo (precisa completar perfil).
  Future<bool> loginWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Login cancelado');

    final auth = await googleUser.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw Exception('Não foi possível obter token Google');

    final result = await api.loginWithGoogle(idToken);
    await SecureStorage.saveTokens(result.accessToken, result.refreshToken);
    api.setTokens(access: result.accessToken, refresh: result.refreshToken);
    _user = result.user;
    notifyListeners();
    return result.isNewUser;
  }

  Future<void> updateProfile({String? nome, String? telefone}) async {
    _user = await api.updateProfile(nome: nome, telefone: telefone);
    notifyListeners();
  }

  // ─── Biometria ─────────────────────────────────────────────────────────────

  Future<bool> isBiometricsAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricsEnabled() => SecureStorage.isBiometricsEnabled();
  Future<bool> wasBiometricsPrompted() => SecureStorage.wasBiometricsPrompted();
  Future<void> markBiometricsPrompted() => SecureStorage.markBiometricsPrompted();

  Future<void> setBiometricsEnabled(bool enabled) async {
    await SecureStorage.setBiometricsEnabled(enabled);
    notifyListeners();
  }

  /// Autentica via biometria e carrega o usuário com os tokens guardados.
  Future<void> loginWithBiometrics() async {
    final authenticated = await _localAuth.authenticate(
      localizedReason: 'Use sua biometria para entrar no Mestre da Obra',
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: true,
      ),
    );
    if (!authenticated) throw Exception('Autenticação biométrica cancelada');

    final tokens = await SecureStorage.loadTokens();
    if (tokens == null) throw Exception('Nenhuma sessão salva');

    api.setTokens(access: tokens.access, refresh: tokens.refresh);
    _user = await api.getMe();
    notifyListeners();
  }

  // ─── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    api.clearTokens();
    _user = null;
    await SecureStorage.clearTokens();
    await _googleSignIn.signOut().catchError((_) {});
    notifyListeners();
  }
}
```

**Passo 2: Commit**

```bash
git add mobile/lib/providers/auth_provider.dart
git commit -m "feat: update AuthProvider with Google, biometric, and secure storage"
```

---

## Task 11: Flutter — Configurar `serverClientId` do Google Sign-In

**Files:**
- Modify: `mobile/lib/providers/auth_provider.dart`

O `serverClientId` (Web Client ID do GCP) precisa ser passado para `GoogleSignIn`. Após obter o Client ID no Task 1, substituir a linha de instanciação:

```dart
// ANTES:
final _googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
  // serverClientId: lido de dart-define ou hardcoded — ver Task 11
);

// DEPOIS (substituir com o Web Client ID real):
final _googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
  serverClientId: const String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: 'SEU_WEB_CLIENT_ID.apps.googleusercontent.com',
  ),
);
```

Para build/run local, passar via `--dart-define`:

```bash
flutter run --dart-define=GOOGLE_CLIENT_ID=SEU_WEB_CLIENT_ID.apps.googleusercontent.com
```

**Passo 2: Commit**

```bash
git add mobile/lib/providers/auth_provider.dart
git commit -m "feat: configure GoogleSignIn serverClientId via dart-define"
```

---

## Task 12: Flutter — Atualizar `LoginScreen`

**Files:**
- Modify: `mobile/lib/screens/auth/login_screen.dart`

**Passo 1: Adicionar botão Google e botão biometria**

Adicionar método `_loginWithGoogle()` à classe `_LoginScreenState`:

```dart
Future<void> _loginWithGoogle() async {
  setState(() { _carregando = true; _erro = null; });
  try {
    final auth = context.read<AuthProvider>();
    final isNewUser = await auth.loginWithGoogle();
    if (!mounted) return;
    if (isNewUser) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CompleteProfileScreen()),
      );
    }
    if (mounted) await _checkAndPromptBiometrics();
  } catch (e) {
    if (mounted) setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
  } finally {
    if (mounted) setState(() => _carregando = false);
  }
}

Future<void> _loginWithBiometrics() async {
  setState(() { _carregando = true; _erro = null; });
  try {
    await context.read<AuthProvider>().loginWithBiometrics();
  } catch (e) {
    if (mounted) setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
  } finally {
    if (mounted) setState(() => _carregando = false);
  }
}

Future<void> _checkAndPromptBiometrics() async {
  final auth = context.read<AuthProvider>();
  final available = await auth.isBiometricsAvailable();
  final prompted = await auth.wasBiometricsPrompted();
  if (!available || prompted || !mounted) return;

  await auth.markBiometricsPrompted();
  if (!mounted) return;

  final enable = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Login mais rápido'),
      content: const Text(
        'Deseja usar biometria (digital ou reconhecimento facial) para entrar sem digitar senha?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Não agora'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Ativar'),
        ),
      ],
    ),
  );
  if (enable == true && mounted) {
    await auth.setBiometricsEnabled(true);
  }
}
```

Atualizar o método `_login()` existente para chamar `_checkAndPromptBiometrics()` após login bem-sucedido:

```dart
Future<void> _login() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() { _carregando = true; _erro = null; });
  try {
    await context.read<AuthProvider>().login(
      email: _emailController.text.trim(),
      password: _senhaController.text,
    );
    if (mounted) await _checkAndPromptBiometrics();
  } catch (e) {
    if (mounted) setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
  } finally {
    if (mounted) setState(() => _carregando = false);
  }
}
```

Adicionar no `initState()` — verificar se biometria está habilitada para mostrar botão:

```dart
bool _biometricsEnabled = false;

@override
void initState() {
  super.initState();
  _checkBiometricsEnabled();
}

Future<void> _checkBiometricsEnabled() async {
  final auth = context.read<AuthProvider>();
  final enabled = await auth.isBiometricsEnabled();
  if (mounted) setState(() => _biometricsEnabled = enabled);
}
```

**Passo 2: Atualizar o `build()` para incluir os botões**

Após o botão "Entrar" existente e antes do TextButton de cadastro, adicionar:

```dart
const SizedBox(height: 16),
Row(
  children: [
    const Expanded(child: Divider()),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text('ou', style: TextStyle(color: Colors.grey[600])),
    ),
    const Expanded(child: Divider()),
  ],
),
const SizedBox(height: 16),
SizedBox(
  width: double.infinity,
  height: 48,
  child: OutlinedButton.icon(
    onPressed: _carregando ? null : _loginWithGoogle,
    icon: Image.asset('assets/images/google_logo.png', width: 20, height: 20),
    label: const Text('Entrar com Google'),
  ),
),
if (_biometricsEnabled) ...[
  const SizedBox(height: 12),
  SizedBox(
    width: double.infinity,
    height: 48,
    child: OutlinedButton.icon(
      onPressed: _carregando ? null : _loginWithBiometrics,
      icon: const Icon(Icons.fingerprint),
      label: const Text('Entrar com biometria'),
    ),
  ),
],
const SizedBox(height: 16),
```

Adicionar import no topo do arquivo:

```dart
import 'complete_profile_screen.dart';
```

**Passo 3: Adicionar logo do Google aos assets**

Baixar o ícone do Google (PNG 48x48) e salvar em `mobile/assets/images/google_logo.png`.

Usando a logo oficial: baixe de https://developers.google.com/identity/branding-guidelines ou use qualquer PNG 48px do logo Google.

**Passo 4: Commit**

```bash
git add mobile/lib/screens/auth/login_screen.dart mobile/assets/images/google_logo.png
git commit -m "feat: add Google Sign-In and biometric buttons to LoginScreen"
```

---

## Task 13: Flutter — Criar `CompleteProfileScreen`

**Files:**
- Create: `mobile/lib/screens/auth/complete_profile_screen.dart`

**Passo 1: Criar o arquivo**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

/// Tela exibida a usuários Google novos para completar nome e telefone.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  final _telefoneController = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    // Pré-preencher nome vindo do Google
    final user = context.read<AuthProvider>().user;
    _nomeController = TextEditingController(text: user?.nome ?? '');
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _salvando = true; _erro = null; });
    try {
      await context.read<AuthProvider>().updateProfile(
        nome: _nomeController.text.trim(),
        telefone: _telefoneController.text.trim().isEmpty
            ? null
            : _telefoneController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete seu perfil'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Precisamos de mais algumas informações para criar sua conta.',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 24),
              if (_erro != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome completo *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outlined),
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe seu nome';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefone (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _salvar(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _salvando ? null : _salvar,
                  child: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Salvar e continuar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Passo 2: Commit**

```bash
git add mobile/lib/screens/auth/complete_profile_screen.dart
git commit -m "feat: add CompleteProfileScreen for new Google users"
```

---

## Task 14: Flutter — Verificar e testar build Android

**Passo 1: Garantir que `minSdk` é compatível com `flutter_secure_storage`**

`flutter_secure_storage` requer `minSdk >= 18`. Verificar em `mobile/android/app/build.gradle.kts`:

```kotlin
defaultConfig {
    minSdk = 21  // flutter.minSdkVersion já é 21, está ok
}
```

Se `flutter.minSdkVersion` for menor que 18 (improvável), setar explicitamente `minSdk = 21`.

**Passo 2: Build debug**

```bash
cd mobile
flutter build apk --debug \
  --dart-define=GOOGLE_CLIENT_ID=SEU_WEB_CLIENT_ID.apps.googleusercontent.com
```

Esperado: build bem-sucedido sem erros.

**Passo 3: Testar manualmente**

- Instalar no dispositivo/emulador: `flutter install`
- Testar fluxo Google Sign-In
- Testar login email/senha normal
- Testar prompt de biometria pós-login
- Testar login biométrico na segunda abertura

**Passo 4: Commit final**

```bash
git add -A
git commit -m "feat: Google Sign-In + biometric login complete"
```

---

## Resumo de arquivos modificados/criados

| Arquivo | Ação |
|---|---|
| `server/app/models.py` | Modificar — `google_id` + `password_hash` opcional |
| `server/app/schemas.py` | Modificar — novos schemas Google + `has_password` |
| `server/app/main.py` | Modificar — endpoints `/api/auth/google` e `/api/auth/me` |
| `server/requirements.txt` | Modificar — adicionar `google-auth` |
| `server/alembic/versions/20260308_0010_google_auth.py` | Criar — migração |
| `mobile/pubspec.yaml` | Modificar — 3 novos packages |
| `mobile/android/app/src/main/AndroidManifest.xml` | Modificar — permissões biometria |
| `mobile/lib/services/secure_storage.dart` | Criar — armazenamento seguro |
| `mobile/lib/models/auth.dart` | Modificar — `GoogleAuthResult` + `hasPassword` |
| `mobile/lib/services/api_client.dart` | Modificar — `loginWithGoogle`, `updateProfile`, `_patch` |
| `mobile/lib/providers/auth_provider.dart` | Modificar — Google + biometria + secure storage |
| `mobile/lib/screens/auth/login_screen.dart` | Modificar — botões Google + biometria + prompt |
| `mobile/lib/screens/auth/complete_profile_screen.dart` | Criar — perfil para users Google |
| `mobile/assets/images/google_logo.png` | Criar — ícone Google |
