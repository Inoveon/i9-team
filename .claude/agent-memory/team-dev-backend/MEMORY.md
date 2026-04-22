# MEMORY — team-dev-backend

> Memória persistente do agente backend do i9-team Portal.
> Atualizada em 2026-04-22.

## Meu domínio

Backend do i9-team Portal — Fastify 5 + WebSocket + tmux integration.

- **Root:** `/home/ubuntu/projects/i9-team/backend`
- **Porta:** 4020
- **Stack:** Fastify 5.2 + @fastify/websocket 11 + node-pty 1.1 + Prisma 7 + BullMQ 5 + Zod 3 + TypeScript strict + ESM
- **Dev:** `npm run dev` (tsx watch)
- **Build:** `npm run build` (tsc → `dist/`)
- **Test:** `npm test` (Vitest 4.1)

## Estrutura do código

```
src/
├── index.ts                  # bootstrap Fastify + plugins + hook JWT global
├── config.ts                 # env vars (PORT, JWT_SECRET, APP_USER/PASSWORD, DATABASE_URL, REDIS, UPLOAD_DIR, TEAMS_JSON_PATH)
├── lib/
│   └── prisma.ts             # PrismaClient singleton
├── generated/prisma/         # client gerado (output custom em schema.prisma)
└── modules/
    ├── auth/                 # POST /auth/login → JWT 24h (@fastify/jwt)
    ├── tmux/                 # list/create/destroy/sendKeys/capture (execSync)
    ├── teams/                # legacy (teams.json) + prisma-routes + sync teams.json → Postgres
    ├── ws/                   # /ws + /ws/:session (deprecated) + sessionState
    ├── notes/                # vault .memory/teams/ CRUD
    ├── uploads/              # @fastify/multipart + cleanup-worker via BullMQ
    └── chat/                 # Prisma ChatMessage CRUD + ws
```

## Endpoints (todos protegidos por JWT via hook onRequest, exceto /health e /auth/login)

### Auth
- `POST /auth/login` → `{ access_token }` (24h). Usuário/senha de env.

### tmux direto
- `GET    /tmux/sessions`
- `POST   /tmux/sessions` body=`{name}`
- `DELETE /tmux/sessions/:name`
- `POST   /tmux/sessions/:name/keys` body=`{keys}`
- `GET    /tmux/capture/:session?lines=50`

### teams (legacy via teams.json)
- `GET  /legacy/teams`
- `POST /legacy/teams/:project/:team/start`
- `POST /legacy/teams/:project/:team/stop`

### teams (Prisma CRUD)
- `GET/PUT /teams/config` — teams.json inteiro
- `POST /teams/sync` — força sync teams.json → Postgres
- `GET/POST/DELETE /teams` + `/:id`
- `GET/POST/DELETE /teams/:id/agents[/:agentId]`
- `GET /teams/:id/agents/status` + `GET /teams/:project/:team/*`
- `POST /teams/:id/start|stop`

### notes (vault compartilhado)
- `GET/POST /notes/:id` — lista/escreve notas do team
- `GET/PUT/DELETE /notes/:id/:name`

### uploads
- `POST /uploads` via multipart (limite + cleanup worker BullMQ)
- estáticos servidos em `/uploads/*` via `@fastify/static`

### WebSocket
- `GET /ws` — canônico (subscribe/input/select_option)
- `GET /ws/:session` — **DEPRECATED**, remover em release seguinte
- `GET /debug/parse-stream?agent=<session>` — debug do parser

### Health
- `GET /health` (público)

## Banco — Prisma 7

Schema em `prisma/schema.prisma`:
- `Team(id, name unique, description, createdAt, agents[])`
- `Agent(id, teamId, name, role, sessionName) — @@unique [teamId,name]`
- `ChatMessage(id, teamId, agentId?, role, content, createdAt) — @@index [teamId,createdAt]`
- `TeamSession(id, project, team, agent, session, startedAt, stoppedAt?)`

Generator custom em `src/generated/prisma` (não usar `@prisma/client` default — sempre importar do path gerado).

## Padrões técnicos que sigo

1. **ESM puro + NodeNext moduleResolution** — imports SEMPRE com extensão `.js` mesmo em .ts (ex: `from './service.js'`).
2. **Zod para validação de body/query/params** — nunca confiar em `request.body` sem `safeParse`.
3. **TypeScript strict: zero `any`** — sempre tipar payloads do WS, params de rota, retorno de funções que cruzam boundary.
4. **Fastify generics para tipar params/query/body:** `app.get<{ Params: {...}; Querystring: {...} }>(...)`.
5. **Auth via hook global** em um `register` de escopo — rotas dentro herdam `jwtVerify`. Permito token via `?token=` além de `Authorization: Bearer` (necessário pra WS no browser).
6. **Testes com Vitest** — arquivos `*.test.ts` ao lado do código. Padrão de injeção: `__setExecForTests`/`__setCaptureForTests` para evitar mock de ESM.
7. **execSync para tmux** — não uso node-pty ainda, só execSync com encoding 'utf8'. node-pty está em deps mas não usado (pode virar refactor futuro).
8. **WebSocket: 1 interval por sessão, N sockets por sessão** — centralizado em `sessionState.ts`. Fan-out + ring buffer (500) + dedup por fingerprint (TTL 120s) + replay incremental por `resumeFromSeq`.
9. **Logging: `app.log` / `console.log` com prefixo `[modulo]`** — padrão `[ws] sendKeys ...`, `[sessionState] sessão ... iniciada`.
10. **Commits apenas via `/commit` skill** (regra do projeto). Português brasileiro em comentários/respostas.

## Decisões arquiteturais recentes

### Onda 1 (2026-04-21) — refactor WebSocket
- Substituído N×setInterval (um por socket) por 1×setInterval por sessão (`sessionState.ts`).
- Adicionado ring buffer FIFO (500 eventos) com seq monotônico.
- Dedup por fingerprint SHA1 do conteúdo semântico do evento (ignora `thinking.duration` e `tool_call.id` que mudam entre ticks).
- Cliente envia `{type:"subscribe", session, resumeFromSeq}` → servidor responde `{type:"subscribed", reset, headSeq, events}`. Reset=true quando cliente novo OU gap > capacidade do ring.
- Heartbeat de 10s removido. Keep-alive agora é WS ping nativo a cada 30s.
- `CAPTURE_LINES=2000` (era 50) pra reduzir chance de evento sair da janela antes do dedup registrar.

### Onda 4 / Issue #2 — multiline em sendKeys
- `TMUX_MULTILINE_MODE` env var com 3 modos: `keys` (default, vencedor empírico), `paste` (bracketed paste via load-buffer), `flat` (join com espaço — fallback legacy).
- Modo `keys`: `send-keys -l <linha>` + `S-Enter` entre + `Enter` final. Shift+Enter no Claude Code TUI = newline no input sem submeter.
- Fast-path sem `\n` continua 1 execSync só.

### Upload cleanup via BullMQ
- Worker inicia no bootstrap (try/catch — Redis pode estar down, não bloqueia startup).
- Job agendado periódico. Arquivos em `UPLOAD_DIR` (default `/tmp/i9-team-uploads`).

### Auth via query-param para WS
- Hook `onRequest` global copia `?token=X` para `Authorization: Bearer X` se ausente, antes de chamar `jwtVerify()`. Browsers não conseguem mandar headers customizados no WS handshake.

### MCP i9-team: Bridge Protocol (2026-04-22)
- 4 tools novas no MCP `i9-team` (`/home/ubuntu/mcp-servers/i9-team`): `team_bridge_send`, `team_bridge_check`, `team_bridge_discover`, `team_bridge_inbox`.
- Permite orquestradores de projetos/teams DIFERENTES se comunicarem via tmux cross-session.
- Header canônico `[BRIDGE from=... to=... corr=<uuid> kind=request|response in_reply_to=...]` na primeira linha. Stateless.
- Helpers adicionados em `src/config.ts` do MCP: `findProjectTeam()`, `resolveAgentName()`.
- Detalhes em `.memory/teams/i9-team/dev/mcp-bridge-implementacao.md` (team_note).

## Convenções de código

### Fastify
- Registrar plugins antes do hook global de auth.
- Proteger rotas agrupando em `app.register(async (instance) => { instance.addHook(...) })`.
- Rotas públicas (auth, health) ficam FORA desse escopo.
- Sempre tipar params/query/body via generics.
- Rate-limit global: 100 req / 1min (pode estreitar por rota se necessário).
- CORS: `origin: true` (qualquer origem no dev — revisar pra prod).
- Helmet ativo.

### Zod
```ts
const schema = z.object({ ... })
const parsed = schema.safeParse(request.body)
if (!parsed.success) return reply.status(400).send({ error: parsed.error.flatten() })
```
Nunca `.parse()` direto — sempre `safeParse` pra evitar throw atravessar o handler.

### Prisma
- Client em `src/generated/prisma` — importar sempre dali, nunca `@prisma/client`.
- `PrismaClient` singleton em `src/lib/prisma.ts`.
- `prisma db push` para dev rápido; `prisma migrate dev` para estrutura versionada.
- Adapter PG (`@prisma/adapter-pg`) já em deps — compatível com Prisma 7 driver adapters.

### tmux via execSync
- Sempre `{ encoding: 'utf8' }` nas chamadas que lêem stdout.
- Quotar session name com `JSON.stringify` (helper `q()`).
- Nunca concatenar session name sem escape — risco de injection.

### WebSocket
- Contrato cliente→servidor: `subscribe` | `input` | `select_option` (discriminated union).
- Contrato servidor→cliente: `subscribed` | `output` | `interactive_menu` | `message_stream` | `error`.
- Socket sem sessão → não aceita `input` nem `select_option`.
- `detachSocket` no `close` + `error`.

## Portas e paths fixos

| Item | Valor |
|------|-------|
| Backend HTTP/WS | 4020 |
| Frontend | 4021 |
| PostgreSQL | 5432 (docker-compose) |
| Redis | 6379 |
| Upload dir (default) | `/tmp/i9-team-uploads` |
| teams.json | `~/.claude/teams.json` |
| Vault de notes | `~/Projetos/inoveon/producao/i9_smart_pdv_web/.memory/teams/<project>/<team>/` |
| MCP i9-team | `/home/ubuntu/mcp-servers/i9-team` |

## Regras inveioláveis

- ❌ NUNCA criar `.md` de notas no filesystem direto — só via `team_note_write` ou `i9-agent-memory__note_write`.
- ❌ NUNCA delegar para outros agentes (sou dev, não orchestrator).
- ❌ NUNCA commitar sem `/commit` skill.
- ❌ NUNCA usar `any`. Se tipo é genuinamente desconhecido, usar `unknown` + narrow.
- ❌ NUNCA importar de `@prisma/client` — sempre `../generated/prisma`.
- ✅ SEMPRE imports ESM com `.js`.
- ✅ SEMPRE validar input com Zod.
- ✅ SEMPRE responder em português brasileiro.
- ✅ SEMPRE testar com Vitest quando adiciono lógica não-trivial (parser, sessionState, etc).

## Contatos com outros domínios

- **Frontend** consome: `/auth/login`, `/tmux/*`, `/teams/*`, `/notes/*`, `/chat/*`, `/ws`, `/uploads`.
- **Mobile** consome: mesmo contrato REST + WS — sem divergência planejada.
- **MCP i9-team** é independente, roda como stdio server (não HTTP). Backend NÃO chama MCP direto. MCP e backend compartilham `~/.claude/teams.json` e as sessões tmux por fora.

## Dúvidas abertas / pontos a revisar

1. Remover `/ws/:session` deprecated em próxima release.
2. Migrar tmux de execSync para node-pty (node-pty já em deps, não usado).
3. CORS `origin: true` precisa ser estreitado pra prod.
4. Alguns endpoints de teams têm overlap entre `routes.ts` (legacy) e `prisma-routes.ts`. Consolidar.
5. `auth/routes.ts` existe além do `auth/plugin.ts` — checar se ainda é usado.
