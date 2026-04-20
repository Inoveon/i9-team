# Débito técnico — `loadTeamsConfig` / `startTeam` / `stopTeam`

**Agente:** team-dev-backend
**Data:** 2026-04-19
**Status:** 🟡 PAUSADO — usuário pediu stand-by. Dashboard principal já funciona; fix do legacy fica para depois.

## Quem usa e por que está quebrado

`backend/src/modules/teams/service.ts` (linhas 23-53) implementa `loadTeamsConfig`, `startTeam`, `stopTeam`.

O bug é no parser: `loadTeamsConfig` espera teams.json no formato antigo
```ts
{ [project]: { [team]: { name, agents, startScript?, stopScript? } } }
```
mas o arquivo real em `~/.claude/teams.json` é
```ts
{ version, projects: [ { name, root, teams: [ { name, orchestrator, agents: [{name, dir}] } ] } ] }
```

→ `teams[project]?.[team]` sempre `undefined` → `startTeam`/`stopTeam` retornam
`{ok:false, message:'Team project/team not found'}`.

**Endpoints afetados (retornam 500 hoje):**
- `POST /teams/:id/start` (prisma-routes.ts:296-313)
- `POST /teams/:id/stop`  (prisma-routes.ts:315-332)
- `POST /legacy/teams/:p/:t/start` (routes.ts:13)
- `POST /legacy/teams/:p/:t/stop`  (routes.ts:22)

## Solução já desenhada (não aplicada)

### 1) Reescrever `loadTeamsConfig`
```ts
import { readFileSync, existsSync } from 'node:fs'
import { config } from '../../config.js'

interface TeamsFileAgent   { name: string; dir: string }
interface TeamsFileTeam    { name: string; orchestrator: string; agents: TeamsFileAgent[] }
interface TeamsFileProject { name: string; root: string; teams: TeamsFileTeam[] }
export interface TeamsFile { version: string; projects: TeamsFileProject[] }

export function loadTeamsConfig(): TeamsFile {
  if (!existsSync(config.teamsJsonPath)) return { version: '0', projects: [] }
  const raw = readFileSync(config.teamsJsonPath, 'utf8')
  return JSON.parse(raw) as TeamsFile
}

export function findTeam(project: string, teamName: string): TeamsFileTeam | null {
  const file = loadTeamsConfig()
  const p = file.projects.find((pr) => pr.name === project)
  return p?.teams.find((t) => t.name === teamName) ?? null
}
```

### 2) `startTeam`/`stopTeam` via `team.sh`
Script já existe: `/home/ubuntu/.claude/scripts/team.sh`
- `start <project> <team>` — exit 1 se não acha team; exit 0 no sucesso
- `stop  <project> <team>` — sempre exit 0 (mesmo sem sessão, só imprime "Nenhuma sessão ativa encontrada")

```ts
import { execFileSync } from 'node:child_process'

const TEAM_SH = process.env.TEAM_SH_PATH ?? `${process.env.HOME}/.claude/scripts/team.sh`

export interface TeamOpResult { ok: boolean; output: string; exitCode?: number }

function runTeamSh(cmd: 'start' | 'stop', project: string, team: string, timeoutMs = 60_000): TeamOpResult {
  if (!findTeam(project, team)) {
    return { ok: false, output: `Team ${project}/${team} não encontrado no teams.json` }
  }
  try {
    const output = execFileSync('bash', [TEAM_SH, cmd, project, team], {
      encoding: 'utf8',
      timeout: timeoutMs,
      stdio: ['ignore', 'pipe', 'pipe'],
    })
    return { ok: true, output: output.trim() }
  } catch (err) {
    const e = err as { status?: number; stdout?: Buffer | string; stderr?: Buffer | string; message?: string }
    const out = [e.stdout?.toString(), e.stderr?.toString(), e.message].filter(Boolean).join('\n').trim()
    return { ok: false, output: out || String(err), exitCode: e.status }
  }
}

export const startTeam = (project: string, team: string) => runTeamSh('start', project, team)
export const stopTeam  = (project: string, team: string) => runTeamSh('stop',  project, team)
```

**Compatibilidade de callers:** o shape muda de `{ok, message}` para `{ok, output, exitCode?}`.
- `prisma-routes.ts` (linhas 296-332) faz `return result` / `reply.status(500).send(result)` — compatível.
- `routes.ts` legacy (linhas 13-27) faz `return startTeam(...)` — compatível.

Nenhum código espera o campo `message` especificamente; o shape novo é só mais rico.

## Como testar SEM derrubar sessões ativas

**Perigo confirmado:** em 2026-04-19 os 3 teams (`i9-team/dev`, `i9-smart-pdv/dev`, `proxmox-infrastructure/infra`) **todos** têm sessões tmux ativas. `team.sh stop` em qualquer um mata as sessões reais, incluindo o próprio orquestrador.

Plano seguro (para quem retomar):
1. Criar team fake só no DB via `POST /teams { "name": "ghost/test" }`
   - Não aparece no teams.json → `team.sh start ghost test` termina com exit 1 "projeto 'ghost' não encontrado"
   - `team.sh stop ghost test` procura prefixo `ghost-test-` em `tmux ls` → não acha → imprime "Nenhuma sessão ativa encontrada", exit 0
2. `POST /teams/<id>/start` → 500 com `{ok:false, output:"Erro: projeto 'ghost' ..."}` ✓ valida captura de erro do exec
3. `POST /teams/<id>/stop`  → 200 com `{ok:true,  output:"Nenhuma sessão ativa encontrada."}` ✓ valida happy-path
4. `DELETE /teams/<id>` para limpar

Alternativa: expor `POST /teams/:id/status` (chama `team.sh status`) que é 100% read-only — útil como smoke-test.

## Arquivos a editar (ninguém editou ainda)

- `backend/src/modules/teams/service.ts` — reescrita completa (loadTeamsConfig + startTeam + stopTeam + novo export `findTeam` + interface `TeamsFile` compartilhada)

Opcional / não obrigatório:
- `backend/src/modules/teams/sync.ts` tem a MESMA tipagem interna (linhas 5-26) → poderia importar de `service.ts` em vez de duplicar. Refactor secundário.

## Restart necessário após o fix

`backend/Makefile:2` é `npx tsx src/index.ts` (sem watch). Ao retomar, pedir ao team-dev-service:
```bash
tmux send-keys -t i9team-svc-backend C-c
sleep 1
tmux send-keys -t i9team-svc-backend 'make dev' Enter
```
Ou trocar o Makefile para `npx tsx watch src/index.ts` de uma vez.

## Estado atual do stand-by

- `service.ts` **intacto** (commit a049c4f ainda é a versão vigente, como sempre foi)
- `prisma-routes.ts` já tem os endpoints `POST /teams/:id/start|stop` registrados, mas retornam 500 porque delegam para o `service.ts` quebrado — conforme documentado em `.claude/notes/backend-shape-endpoints-fix.md`
- Dashboard principal (listar agents, chat timeline, envio de mensagem via `/teams/:id/message`) funciona
