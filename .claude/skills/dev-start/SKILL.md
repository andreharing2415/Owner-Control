---
name: dev-start
description: Inicia o ambiente do ObraMaster (local ou produção). Use quando quiser subir o app, rodar o Flutter, reiniciar a aplicação, ou conectar ao backend — qualquer menção a "rodar", "iniciar", "reiniciar", "subir", "start", "run", "produção", "backend" deve ativar esta skill.
disable-model-invocation: true
allowed-tools: Bash
---

# Iniciar ambiente — ObraMaster Owner Control

## Infraestrutura

### Backend de produção (Cloud Run)

| Campo | Valor |
|-------|-------|
| **GCP Project** | `mestreobra` |
| **Region** | `us-central1` |
| **Service** | `mestreobra-backend` |
| **URL** | `https://mestreobra-backend-530484413221.us-central1.run.app` |

Para verificar:
```bash
"C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd" run services describe mestreobra-backend --project=mestreobra --region=southamerica-east1 --format="value(status.url)"
```

Para testar saúde:
```bash
curl -s -o /dev/null -w "HTTP %{http_code}" https://mestreobra-backend-530484413221.us-central1.run.app/docs
```

### Backend local (Docker)

```bash
cd C:\Project\ObraMaster\Owner-Control
docker-compose up -d
# API ficará em http://localhost:8000
```

Ou sem Docker:
```bash
cd C:\Project\ObraMaster\Owner-Control\server
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## Rodar Flutter

### Worktree path
```
C:\Project\ObraMaster\Owner-Control\.claude\worktrees\brave-lovelace
```

### Com backend de PRODUÇÃO (padrão)

```bash
cd C:\Project\ObraMaster\Owner-Control\.claude\worktrees\brave-lovelace
flutter run -d chrome --web-port=59026 \
  --dart-define=API_BASE_URL=https://mestreobra-backend-530484413221.us-central1.run.app
```

### Com backend LOCAL

```bash
cd C:\Project\ObraMaster\Owner-Control\.claude\worktrees\brave-lovelace
flutter run -d chrome --web-port=59026 \
  --dart-define=API_BASE_URL=http://localhost:8000
```

### Android emulador (backend local)

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

> **Nota**: No emulador Android, `10.0.2.2` aponta para o localhost do host.

## Sequência de reinicialização completa

1. Matar processos Flutter existentes:
```bash
netstat -ano | grep ":59026 .*LISTENING"
# Anotar PID e:
taskkill //PID <PID> //T //F
```

2. (Opcional) Matar backend local:
```bash
netstat -ano | grep ":8000 .*LISTENING"
taskkill //PID <PID> //T //F
```

3. Iniciar backend (produção ou local — veja acima)

4. Iniciar Flutter (veja acima)

## API_BASE_URL — como funciona

Definido em `lib/api/api.dart`:
```dart
const apiBaseUrl = String.fromEnvironment(
  "API_BASE_URL",
  defaultValue: "http://localhost:8000",
);
```

- Se não passar `--dart-define`, usa `http://localhost:8000`
- Para produção: `--dart-define=API_BASE_URL=https://mestreobra-backend-530484413221.us-central1.run.app`

## Variáveis de ambiente (.env do servidor local)

```
DATABASE_URL=postgresql://obramaster:obramaster@localhost:5444/obramaster
S3_ENDPOINT_URL=http://localhost:9000
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin
S3_BUCKET=evidencias
S3_PUBLIC_URL=http://localhost:9000
```

## Comandos úteis

| Comando | Descrição |
|---------|-----------|
| `docker-compose down` | Parar todos os serviços locais |
| `docker-compose logs api` | Ver logs da API local |
| `flutter devices` | Listar dispositivos disponíveis |
| `flutter run -d chrome` | Rodar no Chrome (web) |
| `flutter analyze` | Verificar erros estáticos |
| `gcloud.cmd run services list --project=mestreobra` | Listar serviços Cloud Run |
