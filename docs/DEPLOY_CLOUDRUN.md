# Deploy da API no Cloud Run (projeto obramaster)

## Pré-requisitos

- [gcloud CLI](https://cloud.google.com/sdk/docs/install) instalado e logado: `gcloud auth login`
- Projeto GCP **obramaster** criado e billing habilitado

## Definir projeto

```bash
gcloud config set project obramaster
```

## Deploy rápido (script)

Na raiz do repositório ou em `server/`:

```bash
bash server/deploy-cloudrun.sh
```

Região padrão: `us-central1`. Para outra região:

```bash
bash server/deploy-cloudrun.sh southamerica-east1
```

## Deploy manual (comandos gcloud)

### 1. Build da imagem e push (Cloud Build)

```bash
cd C:\Project\ObraMaster\Owner-Control

gcloud builds submit --tag gcr.io/obramaster/obramaster-api -f server/Dockerfile server/
```

### 2. Deploy no Cloud Run

```bash
gcloud run deploy obramaster-api ^
  --image gcr.io/obramaster/obramaster-api ^
  --platform managed ^
  --region us-central1 ^
  --allow-unauthenticated ^
  --port 8080
```

No PowerShell (escapar quebra de linha com `` ` ``):

```powershell
gcloud run deploy obramaster-api `
  --image gcr.io/obramaster/obramaster-api `
  --platform managed `
  --region us-central1 `
  --allow-unauthenticated `
  --port 8080
```

### 3. Variáveis de ambiente (produção)

Para usar banco Supabase e demais segredos, defina as env vars no Cloud Run após o primeiro deploy:

- **Console:** Cloud Run → obramaster-api → Edit & deploy new revision → Variables & Secrets
- **Ou via gcloud:** use `--set-env-vars "DATABASE_URL=...,S3_BUCKET=..."` (ou `--env-vars-file` com um arquivo sem valores sensíveis no repo).

Exemplo (substitua os valores reais):

```bash
gcloud run services update obramaster-api \
  --region us-central1 \
  --set-env-vars "DATABASE_URL=postgresql://...,S3_BUCKET=obramaster,JWT_SECRET_KEY=..."
```

### 4. Obter a URL do serviço

```bash
gcloud run services describe obramaster-api --region us-central1 --format="value(status.url)"
```

Use essa URL como `API_BASE_URL` no app Flutter (skills e `--dart-define=API_BASE_URL=URL`).

## Resumo

| Item        | Valor                          |
|------------|---------------------------------|
| Projeto    | `obramaster`                    |
| Serviço    | `obramaster-api`                |
| Imagem     | `gcr.io/obramaster/obramaster-api` |
| Porta       | 8080                            |

Depois do deploy, atualize a URL nas skills (flutter-build, dev-start) e no `vite.config.ts` se usar o cliente web apontando para essa API.
