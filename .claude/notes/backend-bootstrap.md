# Bootstrap do ambiente Docker + auto-reload — i9-team Portal

**Agente:** team-dev-backend
**Data:** 2026-04-19
**Status:** ✅ concluído — 3 containers healthy

## Arquivos criados

### Raiz
- `docker-compose.dev.yml` — orquestração dos 3 serviços + network `i9team` + volumes nomeados

### backend/
- `package.json` — Fastify 5.2, @fastify/cors, @fastify/jwt, @fastify/websocket, zod, tsx, TypeScript
- `tsconfig.json` — strict, ESM, target ES2022, `noUncheckedIndexedAccess`
- `src/index.ts` — Fastify básico com `/health` e `/`
- `Dockerfile.dev` — node:22-alpine + wget + toolchain (python3/make/g++ para node-pty futuro)
- `.dockerignore`, `.gitignore`

### frontend/
- `package.json` — Next.js 15.1.3, React 19, Tailwind 3.4
- `tsconfig.json` — strict, path alias `@/*`
- `next.config.mjs` — standalone output, reactStrictMode
- `tailwind.config.ts` — dark mode class, paleta futurista (primary #7c3aed, accent #22d3ee, bg #0a0a0f)
- `postcss.config.mjs`, `app/globals.css`
- `app/layout.tsx` — html lang pt-BR + class dark
- `app/page.tsx` — landing futurista com 3 cards (backend/frontend/postgres)
- `Dockerfile.dev`, `.dockerignore`, `.gitignore`

## Portas

| Serviço           | Host → Container | Observação                       |
|-------------------|------------------|----------------------------------|
| i9team-postgres   | 5433 → 5432      | **5432 livre** p/ pgvector existente |
| i9team-backend    | 4020 → 4020      | Fastify /health                  |
| i9team-frontend   | 4021 → 4021      | Next.js dev server               |

## Auto-reload

- **Backend**: volume `./backend:/app` + `npx tsx watch src/index.ts` (rebota ao salvar)
- **Frontend**: volume `./frontend:/app` + `next dev -H 0.0.0.0` + `WATCHPACK_POLLING=true` (polling obrigatório dentro de volume Docker no Linux)
- **node_modules** e `.next` em volumes nomeados — não poluem o host, não sobrescrevem o volume de código

## DATABASE_URL interna (service-name)

```
postgresql://i9team:i9team_dev@postgres:5432/i9team?schema=public
```

Na rede Docker a porta é 5432. No host, use 5433.

## Comandos úteis

```bash
# logs em tempo real
docker compose -f docker-compose.dev.yml logs -f

# logs de um serviço específico
docker compose -f docker-compose.dev.yml logs -f backend

# restart de um serviço
docker compose -f docker-compose.dev.yml restart backend

# derrubar tudo (preserva volumes)
docker compose -f docker-compose.dev.yml down

# derrubar + limpar volumes
docker compose -f docker-compose.dev.yml down -v

# shell em um container
docker exec -it i9team-backend sh
```

## Validação executada

```
$ curl http://localhost:4020/health
{"status":"ok","service":"i9team-backend","uptime":25.78,"timestamp":"2026-04-19T11:04:29.538Z"}

$ curl -I http://localhost:4021
HTTP 200

$ docker exec i9team-postgres pg_isready
/var/run/postgresql:5432 - accepting connections
```

## Próximos passos sugeridos ao orquestrador

1. Delegar ao backend: adicionar Prisma 7 (`npx prisma init`) + schema inicial
2. Delegar ao frontend: instalar ShadCN + xterm.js + Framer Motion
3. Definir rota `POST /auth/login` (Fastify + JWT) — stub já tem `@fastify/jwt` nas deps
4. Criar módulo `src/modules/tmux` no backend (list/send/capture via execSync)
