# MEMORY — team-dev-service

> Memória persistente do agente administrador de serviços do **i9-team Portal**.
> Atualizada em 2026-04-22.

## 1. Identidade e escopo

- **Domínio**: process management dos serviços de **dev** do i9-team Portal no servidor Linux (Ubuntu).
- **Não faço código** — só subo, supervisiono, reinicio e diagnostico processos.
- **Não delego** — execução direta com `Bash` + `tmux` + `docker`.
- **Comunicação** com orquestrador via `mcp__i9-team__team_send`/`team_note_write`.
- **Notas técnicas** persistentes via `mcp__i9-agent-memory__note_write` (NUNCA via `Write` em `.md`).

## 2. Inventário dos serviços

| Serviço      | Porta | Tecnologia                         | Como sobe                                            |
|--------------|-------|------------------------------------|------------------------------------------------------|
| **postgres** | 5438  | Docker (`postgres:16-alpine`)      | `docker compose up -d postgres` em `backend/`        |
| **redis**    | 6379  | Docker (`i9team-redis` já rodando) | externo — não gerenciado por mim diretamente         |
| **backend**  | 4020  | Fastify 5 + tsx watch              | `make dev` em `backend/` (= `npx tsx src/index.ts`)  |
| **frontend** | 4021  | Next.js 15 dev                     | `make dev` em `frontend/` (= `npx next dev -p 4021`) |

> **Observação**: o Makefile do backend roda `npx tsx src/index.ts` — sem `--watch` explícito. Auto-reload depende do que o `src/index.ts` faz internamente. Para garantir watch real, eu posso rodar `npx tsx watch src/index.ts` ao subir manualmente.

### DATABASE_URL real (compose vs .env.example)

- `docker-compose.yml` usa `i9team:i9team@postgres:5432/i9team` exposto em **host:5438**.
- `.env.example` mostra `postgres:postgres@localhost:5432/i9_team_db` — DESATUALIZADO.
- O `.env` real do projeto deve apontar para `postgresql://i9team:i9team@localhost:5438/i9team`.
- **Antes de subir backend, sempre conferir `DATABASE_URL`** com `grep '^DATABASE_URL' backend/.env`.

## 3. Padrão de sessões tmux

### Convenção de nomes (INVIOLÁVEL)

```
i9team-svc-postgres
i9team-svc-backend
i9team-svc-frontend
```

> Prefixo `i9team-svc-` é meu domínio. Sessões `i9-team-dev-*` são do team de agentes — **NUNCA mexer**.

### Comandos canônicos

```bash
# subir
tmux new-session -d -s i9team-svc-backend -c /home/ubuntu/projects/i9-team/backend 'make dev'

# checar viva
tmux has-session -t i9team-svc-backend 2>/dev/null && echo UP || echo DOWN

# logs (últimas N linhas)
tmux capture-pane -t i9team-svc-backend -p | tail -50

# reiniciar
tmux kill-session -t i9team-svc-backend
tmux new-session -d -s i9team-svc-backend -c /home/ubuntu/projects/i9-team/backend 'make dev'

# matar todas as minhas sessões (cuidado!)
tmux ls 2>/dev/null | awk -F: '/^i9team-svc-/{print $1}' | xargs -I{} tmux kill-session -t {}
```

### Por que tmux e não systemd/pm2

- Logs ao vivo via `capture-pane` sem precisar configurar log rotation.
- Posso anexar (`tmux attach -t ...`) para debug interativo sem perder estado.
- Independente de root/serviços do SO — fica todo no usuário `ubuntu`.
- Reinício rápido por `kill-session` + `new-session`, sem PID files.

## 4. Health checks (sempre antes de reportar OK)

```bash
# postgres
pg_isready -h localhost -p 5438                 # exit 0 = pronto
docker exec backend-postgres-1 pg_isready -U i9team

# backend
curl -sf http://localhost:4020/health           # 200 OK obrigatório

# frontend
curl -sf http://localhost:4021 -o /dev/null     # qualquer 2xx serve

# porta ocupada
ss -tlnp | grep -E ':(4020|4021|5438) '
```

### Loop de espera padrão

```bash
# espera postgres ficar pronto
until pg_isready -h localhost -p 5438; do sleep 2; done

# espera backend health
until curl -sf http://localhost:4020/health >/dev/null; do sleep 2; done
```

## 5. Bootstrap do zero (ordem importa)

1. `cd backend && [ -d node_modules ] || npm install`
2. `cd frontend && [ -d node_modules ] || npm install`
3. Verificar `backend/.env` — comparar com `.env.example` e ajustar `DATABASE_URL` para `postgresql://i9team:i9team@localhost:5438/i9team`.
4. `cd backend && docker compose up -d postgres` (já está rodando como `backend-postgres-1` no servidor — reutilizar).
5. Aguardar `pg_isready -h localhost -p 5438`.
6. `cd backend && npx prisma migrate deploy` (produção) **ou** `npx prisma db push` (dev rápido).
7. Subir backend: `tmux new-session -d -s i9team-svc-backend -c <backend> 'make dev'`.
8. Aguardar `curl /health`.
9. Subir frontend: `tmux new-session -d -s i9team-svc-frontend -c <frontend> 'make dev'`.
10. Validar tudo + reportar URLs (`http://<host>:4020`, `http://<host>:4021`).

## 6. Estado atual do servidor (snapshot 2026-04-22)

- `backend-postgres-1` rodando há 2 dias na porta **5438** (compose já subido fora do meu controle).
- `i9team-redis` rodando na porta **6379**.
- **Nenhuma sessão tmux `i9team-svc-*` ativa** no momento — backend e frontend NÃO estão sob minha supervisão agora.
- Existem várias sessões `i9-team-dev-*`, `i9-issues-*`, `i9-service-*`, `i9-smart-pdv-*` — são teams de agentes, **não tocar**.

## 7. Diagnóstico — playbook por sintoma

| Sintoma                                 | Causa provável                       | Ação                                                                 |
|-----------------------------------------|--------------------------------------|----------------------------------------------------------------------|
| `health` retorna 502/conexão recusada   | Sessão tmux morta                    | `tmux has-session` → recriar                                         |
| Backend log: `ECONNREFUSED 127.0.0.1:5438` | postgres caiu ou DATABASE_URL errada | `pg_isready` + conferir `.env`                                       |
| Backend log: `PrismaClientInitializationError` | migrations não aplicadas         | `npx prisma migrate deploy`                                          |
| Frontend log: `EADDRINUSE :::4021`      | outro processo ocupando a porta      | `ss -tlnp \| grep 4021` → identificar e parar                        |
| `tsx: command not found`                | `node_modules` faltando              | `npm install`                                                        |
| Build do Next trava                     | cache corrompido                     | `rm -rf frontend/.next && rm -rf frontend/node_modules/.cache`       |
| Postgres `database "i9team" does not exist` | volume novo sem init                | recriar container ou `createdb` manualmente                          |
| Logs param de aparecer mas sessão viva  | processo travado mas tmux ok         | `tmux send-keys -t i9team-svc-X C-c` + reiniciar                     |

## 8. Comandos de coleta de logs para reportar

```bash
# snapshot completo de todas as minhas sessões
for s in postgres backend frontend; do
  echo "=== i9team-svc-$s ==="
  tmux has-session -t "i9team-svc-$s" 2>/dev/null \
    && tmux capture-pane -t "i9team-svc-$s" -p | tail -30 \
    || echo "(sessão não existe)"
done

# health unificado
{
  pg_isready -h localhost -p 5438 && echo "pg: OK" || echo "pg: DOWN"
  curl -sf http://localhost:4020/health >/dev/null && echo "be: OK" || echo "be: DOWN"
  curl -sf http://localhost:4021 -o /dev/null && echo "fe: OK" || echo "fe: DOWN"
}
```

## 9. Decisões arquiteturais recentes

- **2026-04**: adotado `tmux detached` como único process manager (descartado pm2/systemd) — logs vivos + zero config.
- **2026-04**: postgres do projeto roda em **container compartilhado** (`backend-postgres-1`) na porta 5438; redis idem (`i9team-redis` na 6379) — não dedicar containers novos.
- **2026-04**: backend roda `npx tsx src/index.ts` (sem `watch` no Makefile). Para hot-reload real, usar `npx tsx watch src/index.ts` ao subir manualmente — anotar como tech-debt do Makefile.
- **2026-04**: convenção `i9team-svc-<servico>` para sessões — separa do team de agentes (`i9-team-dev-*`).

## 10. Regras inquebráveis

- ✅ Sempre `tmux -d` (detached) — nunca foreground.
- ✅ Sempre validar com health check antes de reportar OK.
- ✅ Sempre salvar nota via MCP (`team_note_write` ou `note_write`) — nunca `Write` em `.md`.
- ❌ Nunca matar sessões fora do prefixo `i9team-svc-*`.
- ❌ Nunca usar `nohup`/`disown`/`pm2`/`systemd`.
- ❌ Nunca delegar para outros agentes.
- ❌ Nunca commitar — git é responsabilidade do orquestrador via skill `/commit`.

## 11. Atalhos de auto-recuperação

```bash
# subir tudo do zero (idempotente)
BE=/home/ubuntu/projects/i9-team/backend
FE=/home/ubuntu/projects/i9-team/frontend

# postgres já está rodando como backend-postgres-1 — só validar
pg_isready -h localhost -p 5438

# backend
tmux has-session -t i9team-svc-backend 2>/dev/null \
  || tmux new-session -d -s i9team-svc-backend -c "$BE" 'make dev'

# frontend
tmux has-session -t i9team-svc-frontend 2>/dev/null \
  || tmux new-session -d -s i9team-svc-frontend -c "$FE" 'make dev'

# health
sleep 8
curl -sf http://localhost:4020/health && echo BE-OK
curl -sf http://localhost:4021 -o /dev/null && echo FE-OK
```

## 12. Onde achar mais contexto

- Definição do agente: `.claude/agents/team-dev-service.md`
- Compose do postgres: `backend/docker-compose.yml`
- Makefile backend: `backend/Makefile`
- Makefile frontend: `frontend/Makefile`
- Vault de notas técnicas: `mcp__i9-agent-memory__search` com tags `service`, `infra`, `i9-team`.
