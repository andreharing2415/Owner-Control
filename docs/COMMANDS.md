# COMMANDS.md

## Workspace
- Repo principal: `C:\Project\ObraMaster\Owner-Control\Owner-Control`

## Dev
- `npm run dev` (API/server)
- `npm run dev:client` (Vite client)

## Build
- `npm run build`
- `npm run start`

## Types
- `npm run check`

## Database
- `npm run db:init` (Docker up + wait + migrate)
- `npm run db:push` (migrate only)
- `npm run db:up`
- `npm run db:down`

## Docker (Postgres)
- `docker compose -f C:\Project\ObraMaster\Owner-Control\docker-compose.yml up -d`
- Set `DATABASE_URL=postgres://obramaster:obramaster@localhost:5444/obramaster`
