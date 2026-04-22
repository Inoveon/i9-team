---
title: team-dev-backend — snapshot de memória 2026-04-22
tags:
  - backend
  - i9-team
  - fastify
  - agent-memory
  - snapshot
agent: team-dev-backend
project: i9-team
date: '2026-04-22'
---
# team-dev-backend — snapshot de memória (2026-04-22)

Snapshot persistente da memória do agente `team-dev-backend` do projeto i9-team Portal.
Cópia consolidada de `.claude/agent-memory/team-dev-backend/MEMORY.md` + contexto extra.

## Meu domínio

Backend do i9-team Portal.

- **Root:** `/home/ubuntu/projects/i9-team/backend`
- **Porta:** 4020
- **Stack:** Fastify 5.2 + @fastify/websocket 11 + node-pty 1.1 (em deps, ainda não usado) + Prisma 7 (client custom em `src/generated/prisma`) + BullMQ 5 + Zod 3 + TypeScript strict + ESM puro (NodeNext)
- **Scripts:** `npm run dev` (tsx), `npm run build` (tsc), `npm test` (Vitest 4.1), `db:generate|migrate|push`

## Estrutura de módulos

```
src/
├── index.ts                # Fastify + plugins + hook JWT global + bootstrap
├── config.ts               # env vars com defaults
├── lib/prisma.ts           # PrismaClient singleton
├── generated/prisma/       # client gerado (output custom no schema.prisma)
└── modules/
    ├── auth/      POST /auth/login (JWT 24h via @fastify/jwt)
    ├── tmux/      list/create/destroy/sendKeys/capture via execSync
    ├── teams/     legacy (teams.json) + prisma-routes + sync.ts (teams.json → Postgres)
    ├── ws/        /ws + /ws/:session (deprecated) + sessionState (ring buffer/dedup)
    ├── notes/     vault .memory/teams/<project>/<team>/ CRUD
    ├── uploads/   @fastify/multipart + BullMQ cleanup-worker
    └── chat/      Prisma ChatMessage CRUD + ws
```

## Endpoints ativos

**Públicos:** `GET /health`, `POST /auth/login`

**Protegidos (JWT via hook onRequest global):**

- **tmux**: `GET/POST /tmux/sessions`, `DELETE /tmux/sessions/:name`, `POST /tmux/sessions/:name/keys`, `GET /tmux/capture/:session?lines=N`
- **teams legacy**: `GET /legacy/teams`, `POST /legacy/teams/:project/:team/{start,stop}`
- **teams Prisma**: `GET/PUT /teams/config`, `POST /teams/sync`, CRUD `/teams[/:id]` + `/teams/:id/agents[/:agentId]`, `POST /teams/:id/{start,stop}`, `GET /teams/:project/:team/*`
- **notes**: `GET/POST /notes/:id`, `GET/PUT/DELETE /notes/:id/:name`
- **uploads**: `POST /uploads` (multipart) + estáticos em `/uploads/*`
- **chat**: `POST /chat/messages`, `GET /chat/messages`
- **ws**: `GET /ws` (canônico) + `GET /ws/:session` (DEPRECATED) + `GET /debug/parse-stream?agent=<session>`

## Banco (Prisma 7, Postgres)

Modelos: `Team`, `Agent`, `ChatMessage`, `TeamSession`. Generator custom com output `../src/generated/prisma`. Adapter `@prisma/adapter-pg` em deps.

## Protocolo WebSocket

**Cliente → Servidor:**
- `{type:"subscribe", session, resumeFromSeq?}`
- `{type:"input", keys}`
- `{type:"select_option", session, value, currentIndex?}`

**Servidor → Cliente:**
- `{type:"subscribed", session, reset, headSeq, events}`
- `{type:"output", session, data, hasMenu}`
- `{type:"interactive_menu", session, menuType, options, currentIndex}`
- `{type:"message_stream", session, events, headSeq}`
- `{type:"error", message}`

Arquitetura: 1 `setInterval` por sessão (2s), N sockets fan-out. Ring buffer FIFO(500). Dedup SHA1 sobre conteúdo semântico (exclui `thinking.duration`/`tool_call.id`), TTL 120s. Replay incremental por `resumeFromSeq`; `reset:true` quando cliente novo ou gap > capacidade do ring. Keep-alive = WS ping nativo a cada 30s.

## Decisões arquiteturais recentes

### Onda 1 (2026-04-21) — refactor WebSocket
- N×setInterval → 1 por sessão em `sessionState.ts`
- Ring buffer 500 + seq monotônico + dedup por fingerprint
- Protocolo `subscribed` com `reset/headSeq/events`
- `CAPTURE_LINES` subido de 50 → 2000
- Removido heartbeat de 10s em favor de WS ping nativo

### Onda 4 / Issue #2 — multiline sendKeys
- `TMUX_MULTILINE_MODE` env: `keys` (default, `send-keys -l` + `S-Enter`), `paste` (bracketed paste via `load-buffer`/`paste-buffer -p`), `flat` (join com espaço)
- Fast-path single-line: 1 execSync só

### Upload cleanup via BullMQ
- Worker + job agendado no bootstrap; try/catch tolera Redis down

### Auth via query-param no WS
- Hook global copia `?token=X` → `Authorization: Bearer X` antes de `jwtVerify()`

### MCP i9-team Bridge Protocol (hoje, 2026-04-22)
- 4 tools novas em `/home/ubuntu/mcp-servers/i9-team`: `team_bridge_send/check/discover/inbox`
- Permite orquestradores CROSS-PROJECT se comunicarem via tmux
- Header canônico stateless: `[BRIDGE from=<p>::<t>::<a> to=<p>::<t>::<a> corr=<uuid> kind=request|response in_reply_to=<uuid?>]`
- Helpers `findProjectTeam()` + `resolveAgentName()` em `src/config.ts`
- Build passou limpo; detalhes em team_note `mcp-bridge-implementacao`

## Padrões que sigo

1. **ESM com `.js` nos imports** mesmo em `.ts` (NodeNext).
2. **Zod `safeParse`** sempre — nunca `.parse()` direto no handler.
3. **Zero `any`** — se desconhecido, `unknown` + narrow.
4. **Generics Fastify** pra tipar params/query/body: `app.get<{Params,Querystring,Body}>(...)`.
5. **Auth via scoped `register`** com hook `onRequest` global dentro. Rotas públicas ficam fora.
6. **Testes Vitest `*.test.ts`** ao lado do código; injeção via `__setExecForTests`/`__setCaptureForTests` (sem mock de ESM).
7. **execSync com quote JSON** (`JSON.stringify`) pra evitar injection em nomes de sessão.
8. **Logging com prefixo `[modulo]`**.
9. **Commits apenas via `/commit` skill**; português em comentários/respostas.
10. **Prisma client importado SEMPRE** de `../generated/prisma`, nunca `@prisma/client`.

## Portas, paths e recursos

| Item | Valor |
|------|-------|
| Backend HTTP/WS | 4020 |
| Frontend | 4021 |
| Postgres (docker-compose) | 5432 |
| Redis | 6379 |
| Upload dir default | `/tmp/i9-team-uploads` |
| teams.json | `~/.claude/teams.json` |
| Vault de notes | `~/Projetos/inoveon/producao/i9_smart_pdv_web/.memory/teams/<project>/<team>/` |
| MCP i9-team | `/home/ubuntu/mcp-servers/i9-team` |

## Regras inveioláveis

- ❌ Nunca criar `.md` direto no FS — só via `team_note_write` ou `mcp__i9-agent-memory__note_write`
- ❌ Nunca delegar pra outros agentes (sou dev, não orchestrator)
- ❌ Nunca commitar sem `/commit`
- ❌ Nunca usar `any`
- ❌ Nunca importar `@prisma/client` (usar `../generated/prisma`)
- ✅ Sempre responder em pt-BR
- ✅ Sempre validar input Zod
- ✅ Sempre `.js` nos imports ESM
- ✅ Sempre Vitest pra lógica não-trivial

## Pendências / pontos de atenção

1. Remover `/ws/:session` deprecated em próxima release
2. Migrar tmux service de `execSync` para `node-pty` (dep já instalada, não usada)
3. CORS `origin: true` precisa ser estreitado pra prod
4. Overlap entre `teams/routes.ts` (legacy) e `teams/prisma-routes.ts` — consolidar
5. Checar se `auth/routes.ts` ainda é usado além de `auth/plugin.ts`

## Arquivo-raiz do agente

Memória interna do agente está em:
`/home/ubuntu/projects/i9-team/.claude/agent-memory/team-dev-backend/MEMORY.md`

Este snapshot no vault (`agent-memory/team-dev-backend-2026-04-22.md`) serve pra recuperação cross-sessão caso o arquivo local seja perdido/rotacionado.
