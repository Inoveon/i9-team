---
title: Agent Memory — team-dev-service (2026-04-22)
tags:
  - agent-memory
  - team-dev-service
  - service
  - infra
  - i9-team
agent: team-dev-service
project: i9-team
date: '2026-04-22'
---
# Agent Memory — team-dev-service (2026-04-22)

> Snapshot consolidado da memória persistente do agente **team-dev-service**
> do projeto **i9-team Portal**. Espelha `.claude/agent-memory/team-dev-service/MEMORY.md`.

## Identidade

- **Função**: process manager dos serviços de **dev** do i9-team Portal no servidor Linux (Ubuntu).
- **Escopo**: subir, supervisionar, reiniciar e diagnosticar `postgres`, `backend`, `frontend`.
- **Não faço**: código, deploy, commits, delegação para outros agentes.
- **Comunicação**: `mcp__i9-team__team_send`/`team_note_write` com o orquestrador.

## Serviços supervisionados

| Serviço  | Porta | Como sobe                                                        |
|----------|-------|------------------------------------------------------------------|
| postgres | 5438  | `docker compose up -d postgres` em `backend/` (já roda como `backend-postgres-1`) |
| backend  | 4020  | `make dev` em `backend/` → `npx tsx src/index.ts`                |
| frontend | 4021  | `make dev` em `frontend/` → `npx next dev -p 4021`               |
| redis    | 6379  | externo (`i9team-redis`) — só consumido pelo backend             |

`DATABASE_URL` correto: `postgresql://i9team:i9team@localhost:5438/i9team`.
O `.env.example` está desatualizado (aponta para 5432) — sempre conferir antes de subir backend.

## Convenção de sessões tmux

Prefixo INVIOLÁVEL: `i9team-svc-<servico>` — separa as minhas sessões das do team de agentes (`i9-team-dev-*`).

```bash
tmux new-session -d -s i9team-svc-backend -c /home/ubuntu/projects/i9-team/backend 'make dev'
tmux capture-pane -t i9team-svc-backend -p | tail -50
tmux kill-session -t i9team-svc-backend
```

## Health checks padrão

```bash
pg_isready -h localhost -p 5438                 # postgres
curl -sf http://localhost:4020/health           # backend
curl -sf http://localhost:4021 -o /dev/null     # frontend
ss -tlnp | grep -E ':(4020|4021|5438) '         # quem ocupa porta
```

Sempre rodar **após** subir e **antes** de reportar OK.

## Bootstrap (ordem)

1. `npm install` em `backend/` e `frontend/` (se faltar `node_modules`).
2. Conferir `backend/.env` (`DATABASE_URL` para `:5438`).
3. `docker compose up -d postgres` em `backend/` (idempotente).
4. `until pg_isready -h localhost -p 5438; do sleep 2; done`.
5. `cd backend && npx prisma migrate deploy` (ou `db push` em dev).
6. tmux backend (porta 4020) → aguardar `/health`.
7. tmux frontend (porta 4021) → validar.
8. Reportar URLs e status via `team_note_write`.

## Decisões arquiteturais

- **tmux detached como único process manager** — descartado pm2/systemd. Vantagem: logs vivos via `capture-pane` sem rotation.
- **Postgres compartilhado em container já existente** (`backend-postgres-1`, porta 5438) — não criar containers novos, reutilizar.
- **Redis idem** (`i9team-redis`, porta 6379).
- **Convenção `i9team-svc-*`** isola minhas sessões das dos agentes do team.
- **Tech-debt anotado**: Makefile do backend roda `tsx` sem `watch`. Para hot-reload real, manualmente usar `npx tsx watch src/index.ts`.

## Diagnóstico rápido

| Sintoma                              | Ação                                                    |
|--------------------------------------|---------------------------------------------------------|
| 502 no `/health`                     | `tmux has-session` → recriar                            |
| `ECONNREFUSED 127.0.0.1:5438`        | `pg_isready` + revisar `.env`                           |
| `PrismaClientInitializationError`    | `npx prisma migrate deploy`                             |
| `EADDRINUSE :::4021`                 | `ss -tlnp \| grep 4021` → matar processo invasor        |
| `tsx: command not found`             | `npm install` no dir certo                              |
| Build Next travado                   | `rm -rf frontend/.next` e cache do `node_modules`       |
| Sessão viva mas sem logs novos       | `tmux send-keys -t ... C-c` + reiniciar                 |

## Estado do servidor em 2026-04-22

- `backend-postgres-1` UP há 2 dias na porta 5438.
- `i9team-redis` UP na 6379.
- **Nenhuma sessão `i9team-svc-*` ativa** — backend/frontend não estão sob supervisão neste momento.
- Há várias sessões `i9-team-dev-*`, `i9-issues-*`, `i9-service-*`, `i9-smart-pdv-*` — são teams de agentes, **não tocar**.

## Regras inquebráveis

- ✅ `tmux -d` sempre (detached).
- ✅ Health check antes de reportar OK.
- ✅ Notas SEMPRE via MCP (`team_note_write` / `note_write`) — nunca `Write` em `.md`.
- ❌ Nunca matar sessões fora do prefixo `i9team-svc-*`.
- ❌ Nunca `nohup`, `disown`, `pm2`, `systemd`.
- ❌ Nunca delegar, nunca commitar (git é do orquestrador).

## Recovery snippet (idempotente)

```bash
BE=/home/ubuntu/projects/i9-team/backend
FE=/home/ubuntu/projects/i9-team/frontend
pg_isready -h localhost -p 5438
tmux has-session -t i9team-svc-backend 2>/dev/null \
  || tmux new-session -d -s i9team-svc-backend -c "$BE" 'make dev'
tmux has-session -t i9team-svc-frontend 2>/dev/null \
  || tmux new-session -d -s i9team-svc-frontend -c "$FE" 'make dev'
sleep 8
curl -sf http://localhost:4020/health && echo BE-OK
curl -sf http://localhost:4021 -o /dev/null && echo FE-OK
```
