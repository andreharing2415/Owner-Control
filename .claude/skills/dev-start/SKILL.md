---
name: dev-start
description: Inicia o ambiente de desenvolvimento do Mestre da Obra (Docker + API + Flutter). Use quando quiser subir o ambiente local.
disable-model-invocation: true
allowed-tools: Bash
---

# Iniciar ambiente de desenvolvimento — Mestre da Obra

## Status atual do ambiente
- Docker: !`docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | head -10`
- Git branch: !`git -C C:\Project\ObraMaster\Owner-Control branch --show-current 2>/dev/null`

## Sequência de inicialização

Execute na ordem:

### 1. Subir infraestrutura (PostgreSQL + MinIO + API Python)
```bash
cd C:\Project\ObraMaster\Owner-Control
docker-compose up -d
```

### 2. Aguardar API estar pronta
```bash
curl -s http://localhost:8000/health
# Deve retornar: {"status":"ok"}
```

### 3. Rodar migrações (se necessário)
```bash
cd C:\Project\ObraMaster\Owner-Control\server
alembic upgrade head
```

### 4. Verificar API Swagger
Acesse: http://localhost:8000/docs

### 5. Rodar app Flutter
```bash
cd C:\Project\ObraMaster\Owner-Control\mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

> **Nota**: No emulador Android, `10.0.2.2` aponta para o localhost da máquina host.
> No iOS Simulator, use `http://localhost:8000`.

## Variáveis de ambiente necessárias (.env)
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
| `docker-compose down` | Parar todos os serviços |
| `docker-compose logs api` | Ver logs da API Python |
| `flutter devices` | Listar dispositivos disponíveis |
| `flutter run -d emulator-5554` | Rodar em emulador específico |
| `flutter run --release` | Build de release para teste |
