# Fix — unwrap envelope { team } + alerta de inconsistência — 2026-04-19

## Arquivo editado

`src/app/team/[project]/[team]/page.tsx` linhas 20-23:
```diff
- const data = await api.get<Team>(
-   `/teams/${params.project}/${params.team}`
- );
- setActiveTeam(data);
+ const data = await api.get<{ team: Team }>(
+   `/teams/${params.project}/${params.team}`
+ );
+ setActiveTeam(data.team);
```

Único `setActiveTeam` do projeto — resolve o TypeError `undefined is not an object (evaluating 'activeTeam.agents.find')`.

## Compile

```
✓ Compiled in 1079ms (1887 modules)
GET /team/i9-team/dev 200 in 413ms
GET /team/proxmox-infrastructure/infra 200 in 69ms
GET /team/i9-smart-pdv/dev 200 in 56ms
```

Sem erros, sem warnings.

## ⚠️ PROBLEMA ADICIONAL DETECTADO — shape do payload vs tipo Agent

Ao validar o endpoint `/teams/:project/:team` via curl:

```json
{
  "team": {
    "id": "...",
    "agents": [
      { "id": "...", "name": "team-orchestrator", "role": "orchestrator", "sessionName": "..." },
      { "id": "...", "name": "team-dev-backend", "role": "agent", "sessionName": "..." },
      { "id": "...", "name": "team-dev-service", "role": "agent", "sessionName": "..." }
    ]
  }
}
```

O tipo `Agent` em `src/types/index.ts` espera:
- `role: "orchestrator" | "worker"` — backend retorna `"agent"` (não `"worker"`)
- `sessionId?: string` — backend retorna `sessionName`
- `status: AgentStatus` — backend **não retorna** `status`

### Consequência imediata
Em `src/app/team/[project]/[team]/page.tsx:36`:
```ts
const workers = activeTeam?.agents.filter((a) => a.role === "worker") ?? [];
```
→ `workers` fica **vazio** para todos os teams, pois todos os não-orchestrator vêm com `role: "agent"`.

Resultado visual: o painel da direita (workers, abas, aba Chat) fica vazio mesmo após o unwrap.

### Como o endpoint antigo `/teams` (lista) resolveu isso
`src/lib/api.ts:73` em `getTeams()`:
```ts
role: a.role === "orchestrator" ? "orchestrator" : "worker",
```
+ mapeia `sessionName` → `sessionId`.

### Correção recomendada (2 opções)
- **A (frontend)**: adicionar o mesmo mapeamento dentro do `fetchTeam` do TeamPage, OU criar helper `mapTeam(raw)` em `src/lib/api.ts` e reusar em `getTeams()` + `getTeam()` novo.
- **B (backend)**: padronizar `GET /teams/:project/:team` para já retornar `role: "worker"` e `sessionId` como faz o envelope do `/teams` já projetado no frontend.

Recomendo **A** (menos acoplamento + backend pode ficar fiel ao schema Prisma). Aguardando decisão do orquestrador — este fix NÃO foi aplicado agora, escopo era só o unwrap.

## Resumo

- ✅ TypeError resolvido com `data.team`
- ✅ Compile limpo, rota 200
- ⚠️ Próximo bug conhecido: `workers = []` porque `role` vem como `"agent"` e filtro espera `"worker"`. Aba Chat dos workers não aparecerá até aplicar correção adicional.
