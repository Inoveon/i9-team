# Investigação — streaming/processo de agentes

**Agente:** team-dev-backend
**Data:** 2026-04-19
**Modo:** apenas diagnóstico, não implementado

## 1. Últimos commits

### Backend (10 últimos)
```
a049c4f feat(ws): implementar parseMessageStream — parser de eventos do output tmux
1477433 chore(config): adicionar CLAUDE.md e package-lock.json
a7adfc5 feat(ws): refatorar detecção de menus interativos (bottom-up + MCP)
9260cb9 feat(upload): image upload paste/drag-drop + BullMQ cleanup 30min
8a9144c feat(ws): fix select_option com navegação relativa
7a3c238 feat(ws): emitir interactive_menu ao detectar menus Claude Code
a384b9b feat(backend): módulos auth, tmux, teams, ws + sync teams.json→PostgreSQL
047e7ad feat(backend): JWT via query param + input tmux no WebSocket
1805b90 chore: scaffold backend Fastify 5 + node-pty + WebSocket
27a78c3 chore: initial commit
```

### Frontend (referências)
```
b7ecfc6 feat(frontend): timeline de mensagens tipadas com aba Chat
a01dd39 fix(frontend): mapeamento content→text no useMessageStream
7e8edbd feat(frontend): aba Chat nos painéis de workers
```

## 2. SIM — a separação de streaming ESTÁ no código

`backend/src/modules/ws/handler.ts` emite **três tipos distintos** de mensagem no mesmo WS:

| type server→client        | Propósito                     | Source                                 |
|---------------------------|-------------------------------|----------------------------------------|
| `output`                  | Terminal raw p/ xterm         | `captureSession(session, 50)`          |
| `interactive_menu`        | Menus interativos (setas/Enter)| `parseInteractiveMenu(output)`         |
| `message_stream`          | **Eventos tipados p/ chat**    | `parseMessageStream(output)`           |

### `parseMessageStream.ts` — tipos de evento

```ts
type MessageEvent =
  | { type: 'user_input';       content }
  | { type: 'claude_text';      content }
  | { type: 'tool_call';        name, args, id }
  | { type: 'tool_result';      id, content }
  | { type: 'thinking';         label, duration? }
  | { type: 'system';           content }
  | { type: 'interactive_menu'; options, title? }
```

Parseia output tmux extraindo glifos `⏺`, `⎿`, `❯`, spinners de thinking e blocos de menu. Emite a cada 2s (tick do setInterval do handler) ou a cada 10s se output inalterado.

Frontend consome via `useMessageStream(session)` → `ChatTimeline` (commit b7ecfc6).

## 3. Endpoints/WS envolvidos em agentes

### HTTP (backend)
| Rota                              | Handler                                   | Existe? |
|-----------------------------------|-------------------------------------------|---------|
| `GET /teams`                      | `prisma-routes.ts:19`                     | ✅      |
| `GET /teams/:id`                  | `prisma-routes.ts:37`                     | ✅      |
| `GET /teams/:project/:team`       | `prisma-routes.ts:56` (criada hoje)       | ✅      |
| `DELETE /teams/:id`               | `prisma-routes.ts:71`                     | ✅      |
| `GET /teams/:id/agents`           | `prisma-routes.ts:81`                     | ✅      |
| `POST /teams/:id/agents`          | `prisma-routes.ts:90`                     | ✅      |
| `DELETE /teams/:id/agents/:agentId`| `prisma-routes.ts:105`                   | ✅      |
| `GET /teams/:id/agents/status`    | `prisma-routes.ts:117` — **chave p/ status**| ✅   |
| `POST /legacy/teams/:p/:t/start`  | `routes.ts:13`                            | ✅      |
| `POST /legacy/teams/:p/:t/stop`   | `routes.ts:22`                            | ✅      |
| `GET /tmux/sessions`              | `tmux/routes.ts:7`                        | ✅      |
| `GET /debug/parse-stream?agent=`  | `ws/handler.ts:293`                       | ✅      |

### WebSocket
| Rota                | Handler                    | Protocolo                                    |
|---------------------|----------------------------|----------------------------------------------|
| `GET /ws` (upgrade) | `handler.ts:159`           | `{subscribe}` / `{input}` / `{select_option}`|
| `GET /ws/:session`  | `handler.ts:231`           | auto-subscribe pelo path                     |

## 4. Sync teams.json → DB

**Onde roda:** só no startup do backend (`src/index.ts:64` — `syncTeamsFromConfig()` após `app.listen`).

**Não há endpoint para forçar resync.**

**Comportamento:** upsert — cria ou atualiza, **nunca apaga** agentes órfãos (se um agente for removido do teams.json, fica no DB).

**Estado atual (após restart de hoje):**
```
[sync] teams.json sincronizado: 3 teams, 11 agentes
```

Query em `GET /teams/i9-team/dev` agora retorna **5 agentes** ✓:
```
- team-orchestrator     role=orchestrator  session=i9-team-dev-orquestrador
- team-dev-backend      role=agent         session=i9-team-dev-team-dev-backend
- team-dev-frontend     role=agent         session=i9-team-dev-team-dev-frontend
- team-dev-mobile       role=agent         session=i9-team-dev-team-dev-mobile
- team-dev-service      role=agent         session=i9-team-dev-team-dev-service
```

**→ `team-dev-service` ESTÁ no DB agora.** O usuário viu 4 agents antes porque o backend estava rodando desde antes do teams.json ser atualizado (sync não tinha rodado após a adição do service).

## 5. Chat/timeline tipada

**Backend:** `parseMessageStream` + emissão `type: 'message_stream'` com `events[]` — pronto.

**Frontend:**
- `frontend/src/hooks/useMessageStream.ts` escuta `message_stream` e normaliza para `StreamEvent[]`
- `frontend/src/components/chat/ChatTimeline.tsx` consome
- `frontend/src/components/AgentView.tsx` combina Terminal + ChatTimeline em abas

## 6. CAUSAS PROVÁVEIS de "agentes off-line"

### ✅ (a) `team-dev-service` não estava no DB — **RESOLVIDO** pelo restart de hoje
O sync só corre no startup. Após meu restart para carregar `/teams/:project/:team`, o sync releu o teams.json e inseriu o service. Confirmado: `GET /teams/i9-team/dev` retorna 5 agentes agora.

### ❌ (b) WS não rodando — **DESCARTADO**
`/ws` e `/ws/:session` registrados, logs mostram conexões.

### ❌ (c) `/teams/:id/agents/status` vazio — **DESCARTADO**
Endpoint existe e funciona.

### 🔴 (d) **BUG REAL — descompasso de shape entre backend e TeamPage nova**

`frontend/src/app/team/[project]/[team]/page.tsx` consome **direto** o retorno Prisma de `/teams/:project/:team` sem camada de adaptação. Mas o frontend espera o shape "adaptado" que `getTeams()` produz em `src/lib/api.ts:58-79`.

Comparação:

| Campo no DB       | Valor real   | TeamPage espera | Consequência                                      |
|-------------------|--------------|-----------------|---------------------------------------------------|
| `agent.role`      | `'agent'`    | `'worker'`      | `filter(a.role==='worker')` → **array vazio**     |
| `agent.sessionName`| `'i9-team-...'` | `agent.sessionId` | `AgentView session={sessionId}` → undefined  |
| `agent.status`    | *não existe* | `'running'/'idle'` | `<StatusBadge status={status}>` → undefined     |

Resultado: TeamPage renderiza **"Nenhum agente worker"** (linha 137) ou painéis com session=undefined → sem WS conectado → "off-line".

Observe que em `src/lib/api.ts:58-79` o `getTeams()` faz esse mapeamento explicitamente:
```ts
role: a.role === "orchestrator" ? "orchestrator" : "worker",
sessionId: a.sessionName,
status: "running",
```
Mas a TeamPage nova chama `api.get('/teams/:project/:team')` diretamente — **sem passar por esse mapeador**.

### 🔴 (e) **Endpoints que o frontend chama mas backend NÃO tem**
Grep em `frontend/src` revelou:

| Chamada frontend                      | Onde                              | Backend tem?            |
|---------------------------------------|-----------------------------------|-------------------------|
| `POST /teams/:id/message`             | `team/[project]/[team]/page.tsx:43`| ❌ NÃO EXISTE          |
| `POST /teams/:id/start`               | `app/page.tsx:30`                 | ❌ (só `/legacy/...`)   |
| `POST /teams/:id/stop`                | `app/page.tsx:39`                 | ❌ (só `/legacy/...`)   |
| `GET /teams/config`                   | `app/config/page.tsx:18`          | ❌ NÃO EXISTE           |
| `PUT /teams/config`                   | `app/config/page.tsx:34`          | ❌ NÃO EXISTE           |

Isso gera 404 em funcionalidades do dashboard (enviar mensagem ao orquestrador, start/stop team, página /config).

## 7. Resumo executivo

- **Separação de streaming: SIM**, feita no commit `a049c4f` via `parseMessageStream` + 3 tipos de mensagem WS.
- **team-dev-service agora no DB** (após restart).
- **Causa real do "off-line":** TeamPage nova consome o retorno cru do Prisma onde `role='agent'` e sem `sessionId`, então o filter `a.role==='worker'` retorna vazio e `AgentView` nem chega a abrir WS.
- **Bugs colaterais:** `/teams/:id/message`, `/teams/:id/start|stop` e `/teams/config` são chamados pelo frontend mas não existem no backend.

## 8. Sugestões (para decisão do orquestrador — não apliquei)

Opção A — adaptar **no backend**: o `GET /teams/:project/:team` passa a retornar já no shape esperado (`role`→`worker`, `sessionName`→`sessionId`, `status`→`running`), igual ao que `getTeams()` faz no client hoje.

Opção B — adaptar **no frontend**: criar helper `adaptTeam(raw)` em `src/lib/api.ts` e fazer a TeamPage chamar `api.getTeamByPath(project, team)` que já retorna o shape adaptado.

Em paralelo: decidir se `/teams/:id/message` deve enviar `tmux send-keys` para a sessão do orquestrador (endpoint falta), e se `/teams/:id/start|stop` devem existir ou o frontend deve migrar para `/legacy/teams/:project/:team/start`.
