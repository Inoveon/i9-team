# Fix — adaptação de shape + endpoints faltantes

**Agente:** team-dev-backend
**Data:** 2026-04-19
**Status:** ✅ 6 endpoints criados + shape adaptado + testado

## Arquivos alterados

### `backend/src/modules/teams/sync.ts`
- **linhas 28-38**: assinatura `syncTeamsFromConfig(): Promise<SyncResult>` (antes `Promise<void>`)
- **linhas 27-30**: tipo exportado `SyncResult = { teams: number; agents: number }`
- **linha 101**: `return { teams: teamsUpserted, agents: agentsUpserted }`

`src/index.ts:64-66` continua compatível (ignora o retorno).

### `backend/src/modules/teams/prisma-routes.ts` — reescrito
- **imports (L1-8)**: adiciona `readFileSync/writeFileSync/renameSync/existsSync`, `config`, `sendKeys`, `startTeam/stopTeam`, `syncTeamsFromConfig`
- **schemas Zod (L24-45)**: `messageSchema` (aceita `content` **ou** `message` p/ compat frontend), `teamsConfigSchema` com `passthrough`
- **adaptAgent (L61-82)**: centraliza a regra de shape que `frontend/src/lib/api.ts:58-79` aplica em `getTeams()` (role→worker/orchestrator, sessionId alias de sessionName, status default `'running'`)

## Endpoints — tabela resumo

| # | Método  | Path                          | Linhas       | Teste |
|---|---------|-------------------------------|--------------|-------|
| 1 | `GET`   | `/teams/config`               | 96-107       | 200 ✓ |
| 2 | `PUT`   | `/teams/config`               | 109-135      | 200 ✓ (400 em body inválido ✓) |
| 3 | `POST`  | `/teams/sync`                 | 137-141      | 200 `{teams:3, agents:11}` ✓ |
| 4 | `POST`  | `/teams/:id/message`          | 253-288      | 200 ✓ (400 vazio ✓, aceita `content`/`message`) |
| 5 | `POST`  | `/teams/:id/start`            | 296-313      | 500 (*vide limitação*) |
| 6 | `POST`  | `/teams/:id/stop`             | 315-332      | 500 (*vide limitação*) |
| — | `GET`   | `/teams/:project/:team`       | 183-197 (adapt) | 200 ✓ shape novo |

## Shape novo do `/teams/:project/:team`

```json
{
  "team": {
    "id": "cmo5orcto000a41lxf2dsrf33",
    "name": "i9-team/dev",
    "description": "Projeto: i9-team | Root: …",
    "createdAt": "…",
    "agents": [
      {
        "id": "cmo5orcsz000241lxdeifohdu",
        "teamId": "cmo5orcto000a41lxf2dsrf33",
        "name": "team-dev-backend",
        "role": "worker",                              /* antes: 'agent' */
        "sessionName": "i9-team-dev-team-dev-backend", /* mantido */
        "sessionId":   "i9-team-dev-team-dev-backend", /* alias novo */
        "status": "running"                             /* novo */
      }
    ]
  }
}
```

Contagem real validada:
```
agent count: 5
orchestrator: team-orchestrator session= i9-team-dev-orquestrador
workers: 4  [team-dev-backend, team-dev-frontend, team-dev-mobile, team-dev-service]
```

## Teste — bateria completa (script: `/tmp/test_all_endpoints.py`)

```
login: 200

[1] GET /teams/i9-team/dev: 200
    agent count: 5 · shape novo ✓
[2] GET /teams/config: 200 · version=1 · 3 projects
[3] POST /teams/sync: 200 → {teams:3, agents:11}
[4] POST /teams/{id}/message: 200 → {ok:true, session:i9-team-dev-orquestrador, agent:team-orchestrator}
    alias body={message}: 200 ✓
    validação body={}: 400 ✓
[5] POST /teams/{id}/start: 500 → {ok:false, message:'Team i9-team/dev not found'}
[6] POST /teams/{id}/stop:  500 → idem
[R1] GET /teams: 200 count=3
[R2] GET /teams/{id}: 200 name=i9-team/dev
[R3] GET /teams/{id}/agents/status: 200 agents=5
[8]  PUT /teams/config round-trip: 200 → {ok:true, synced:{teams:3, agents:11}}
     validação sem projects: 400 ✓
```

## Limitações conhecidas

### `POST /teams/:id/start|stop` retorna 500

Conforme pedido, delegam para `startTeam(project, name)` / `stopTeam(project, name)` em `modules/teams/service.ts`. Porém **esse service está desalinhado com o teams.json real**:

- `service.ts:23-29` `loadTeamsConfig()` retorna `{[project]: {[team]: {…}}}`
- `teams.json` real é `{version, projects:[{name, root, teams:[…]}]}`

→ `teams[project]?.[team]` sempre `undefined` → `startTeam` retorna `{ok:false, message:'Team not found'}` → os novos endpoints devolvem 500 com esse payload.

Mesma quebra afeta `/legacy/teams/:project/:team/start|stop` (pré-existente).

**Fix verdadeiro (fora do escopo):** reescrever `service.ts` para iterar `file.projects[].teams[]` em vez de indexar como dicionário, e (opcional) definir/executar um `startScript` real — o schema TeamsFile em `sync.ts:7-26` está correto e pode servir de referência.

### Sync não apaga agentes órfãos

`syncTeamsFromConfig()` só faz `upsert`. Se o usuário remover um agente via `PUT /teams/config`, o agente continua no DB. Tratado apenas em documentação neste fix.

### JWT / proteção

Todas as rotas novas estão dentro do bloco `protected` (`src/index.ts:37-55`) — `onRequest` com `jwtVerify` é aplicado automaticamente, igual aos endpoints existentes.

## Restart

Backend reiniciado uma única vez (pid 79443) via tmux `send-keys` (`C-c` + `make dev`). Sync rodou e logou `teams.json sincronizado: 3 teams, 11 agentes`.
