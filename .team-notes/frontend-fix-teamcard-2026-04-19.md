# Fix — TeamCard linkando rota nova — 2026-04-19

## Mudanças aplicadas

### 1. `src/components/TeamCard.tsx:28`
```diff
- <Link href={`/teams/${team.id}`} style={...} aria-label={team.name} />
+ <Link href={`/team/${team.project}/${team.name}`} style={...} aria-label={team.name} />
```

### 2. Rota antiga removida
- `rm -rf src/app/teams/` (continha apenas `[id]/page.tsx`, a rota legada só com `<Terminal>`)

## Análise das outras referências `/teams/`

Todas as outras referências encontradas são **chamadas REST ao backend** (prefixo de API), não links de rota Next — portanto **mantidas sem mudança**:

| Arquivo:linha | Uso | Tipo |
|---|---|---|
| `src/app/team/[project]/[team]/page.tsx:21` | `api.get("/teams/${project}/${team}")` | API |
| `src/app/team/[project]/[team]/page.tsx:43` | `api.post("/teams/${id}/message")` | API |
| `src/app/config/page.tsx:18,34` | `/teams/config` | API |
| `src/app/page.tsx:30,39` | `/teams/${id}/start\|stop` | API |
| `src/lib/api.ts:83` | `getTeam(id)` → `/teams/${id}` | API |
| `src/lib/api.ts:86` | `getAgents(teamId)` → `/teams/${id}/agents/status` | API |

Nenhum outro `<Link>` ou `router.push` apontava para a rota antiga.

## Validação do next dev

```
✓ Compiled /team/[project]/[team] in 3.4s (1873 modules)
GET /team/i9-team/dev 200 in 5033ms     ← rota nova: OK
GET /teams/cmo5orcrf... 404 in 899ms    ← rota antiga: 404 esperado
GET /team/i9-team/dev 200 in 413ms      ← segundo hit: 413ms (cache quente)
```

Sem erros, sem warnings. Compile limpo.

## Teste manual

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:4021/team/i9-team/dev
# 200

curl -s -o /dev/null -w "%{http_code}\n" http://localhost:4021/teams/cmo5orcrf000041lxg0gtbfq8
# 404 (esperado — rota deletada)

curl -s http://localhost:4021/team/i9-team/dev | grep -oE "i9-team|dev|Carregando|Dashboard"
# Dashboard / i9-team / dev / Carregando
```

## Resumo

- ✅ TeamCard agora linka para a rota com abas TERMINAL/CHAT
- ✅ Rota legada `/teams/[id]` removida
- ✅ Nenhuma outra referência a link de rota antiga
- ✅ Next dev compile sem erros, rota nova responde 200
- ⚠️ Mudanças não-commitadas — inclui também a refatoração runtime-config pendente
