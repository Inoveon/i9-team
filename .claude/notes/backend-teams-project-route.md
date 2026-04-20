# Endpoint `GET /teams/:project/:team`

**Agente:** team-dev-backend
**Data:** 2026-04-19
**Status:** ✅ implementado, testado e em produção

## Motivação

Frontend rota nova `/team/[project]/[team]` chama `api.get(\`/teams/\${project}/\${team}\`)`. Backend só tinha `/teams/:id` → 404 → tela "Carregando team..." trava.

## Schema — detalhe relevante

**A tabela `Team` NÃO tem coluna `project` separada.** O schema é:

```prisma
model Team {
  id          String @id @default(cuid())
  name        String @unique   // ← armazena "project/team" composto
  description String?
  createdAt   DateTime @default(now())
  agents      Agent[]
}
```

O campo `name` guarda a string composta `"project/team"` (feito por `sync.ts` que lê `teams.json`). Frontend faz `t.name.split("/")` em `src/lib/api.ts`.

Portanto a nova rota **não** pode filtrar por `{ project, name: team }` (não compila) — precisa compor `${project}/${team}` e buscar por `name`.

## Edição

Arquivo: `backend/src/modules/teams/prisma-routes.ts`, **linhas 46-68** (entre `GET /teams/:id` e `DELETE /teams/:id`).

```ts
app.get<{ Params: { project: string; team: string } }>(
  '/teams/:project/:team',
  async (request, reply) => {
    const { project, team: teamName } = request.params
    const fullName = `${project}/${teamName}`
    const team = await prisma.team.findUnique({
      where: { name: fullName },
      include: { agents: true },
    })
    if (!team) return reply.status(404).send({ error: 'Team não encontrado' })
    return { team }
  }
)
```

## Shape de retorno (idêntico ao `/teams/:id`)

```json
{
  "team": {
    "id": "cmo5orcto000a41lxf2dsrf33",
    "name": "proxmox-infrastructure/infra",
    "description": null,
    "createdAt": "…ISO…",
    "agents": [ { "id", "teamId", "name", "role", "sessionName" }, … ]
  }
}
```

## Auth

Rota registrada **dentro** do bloco protected do `src/index.ts` (linhas 37-55) — o guard `jwtVerify` é aplicado via `onRequest` hook automaticamente. Mesma política de `/teams/:id`.

## Ordem de registro (find-my-way)

Fastify prioriza **segmentos estáticos** sobre paramétricos. Rotas com 3 segmentos:

| Padrão                     | Match de `/teams/xyz/agents` |
|----------------------------|------------------------------|
| `/teams/:id/agents`        | ✅ (static `agents` vence)   |
| `/teams/:project/:team`    | só se 3º for não-literal     |

Sem conflito.

## Validação (smoke-test via `urllib.request`)

```
login: 200
GET /teams: 200 count=3
GET /teams/proxmox-infrastructure/infra: 200
  top keys: ['team']
  team keys: ['id', 'name', 'description', 'createdAt', 'agents']
  team.name: proxmox-infrastructure/infra
  agents: 3
GET /teams/cmo5orcto000a41lxf2dsrf33: 200    ← regressão /teams/:id OK
GET /teams/nao-existe/nada: 404 {"error":"Team não encontrado"}
```

## Nota operacional — `tsx watch` ausente

`backend/Makefile` chama `npx tsx src/index.ts` (sem `--watch`). Edições **não** recarregam sozinhas — é preciso reiniciar. Reiniciei a tmux session `i9team-svc-backend` (kill → new-session → send-keys `make dev`) para carregar a nova rota. Sugestão para o orquestrador: mudar `Makefile:2` para `npx tsx watch src/index.ts` se auto-reload for desejado em dev.

## Regressão

Nenhuma rota existente quebrou. `/teams`, `/teams/:id`, `/teams/:id/agents` e derivados continuam 200.
