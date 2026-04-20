# Inspeção do frontend — 2026-04-19

## 1. Git — frontend local vs origin/main

- **HEAD local == origin/main** (commit `7e8edbd`)
- **Nenhum commit divergente** (ahead=0, behind=0)
- Último commit: `feat(frontend): adicionar aba Chat nos painéis de workers`

## 2. Working tree sujo — 5 arquivos modificados + 1 untracked

Mudanças não-commitadas (refatoração para resolver URLs em runtime):

- `src/lib/runtime-config.ts` (NOVO, untracked) — cria `getApiBase()` / `getWsBase()` que usam `window.location.hostname` em runtime em vez de `localhost` hardcoded no bundle
- `src/lib/api.ts`, `src/lib/ws.ts`, `src/hooks/useMessageStream.ts`, `src/components/ImageUpload.tsx`, `src/components/TerminalWS.tsx` — todos passam a usar `getApiBase()`/`getWsBase()` em vez das constantes top-level

Essa mudança permite acessar o portal de qualquer host (ex.: `http://10.0.10.17:4021`) e o bundle aponta para `10.0.10.17:4020`, não `localhost:4020`. É uma melhoria de deploy/remoto, não relacionada ao sumiço do `team-dev-service`.

## 3. Backend ESTÁ retornando team-dev-service

`GET /teams` responde corretamente:
```
TEAM: i9-team/dev
  - team-orchestrator / i9-team-dev-orquestrador
  - team-dev-backend / i9-team-dev-team-dev-backend
  - team-dev-frontend / i9-team-dev-team-dev-frontend
  - team-dev-mobile / i9-team-dev-team-dev-mobile
  - team-dev-service / i9-team-dev-team-dev-service    ← PRESENTE
```

Então **NÃO é bug de backend nem filtro frontend**. A sessão tmux `i9-team-dev-team-dev-service` está ativa.

Se o usuário só vê 3 workers no card do dashboard:
- Pode ser cache do navegador (bundle antigo sem `runtime-config`, apontando para localhost e pegando outro backend)
- Pode ser que o card mostra 3 porque não foi atualizado desde que o service foi adicionado — mas o código do `TeamCard.tsx` faz `team.agents.map` sem filtro, então com polling de 5s deveria aparecer

## 4. ACHADO CRÍTICO — feature implementada mas invisível

**Existem DUAS rotas de TeamPage no frontend, e o dashboard linka para a rota ERRADA (velha):**

### Rota antiga (sem features novas)
- Arquivo: `src/app/teams/[id]/page.tsx`
- Usa `<Terminal>` direto (linha 231)
- NÃO tem aba Chat, NÃO tem tabs de workers, NÃO tem ChatTimeline
- **TeamCard.tsx linha 28 aponta para cá**: `<Link href={"/teams/${team.id}"}>`

### Rota nova (com features novas)
- Arquivo: `src/app/team/[project]/[team]/page.tsx`
- Importa `AgentView` + `AgentPanel`
- `AgentView` tem tabs Terminal/Chat com contador de mensagens (`Chat (N)`)
- `AgentView` renderiza `ChatTimeline` (events tipados com UserBubble, ClaudeBubble, ToolCallCollapsible, SystemBadge, ThinkingIndicator)
- Workers têm tabs de seleção + split layout orchestrator/worker

**Conclusão**: os commits `b7ecfc6` (timeline tipada), `c9ebce0` (tabs workers), `7e8edbd` (aba Chat nos workers) implementaram a feature em `/team/[project]/[team]` — mas o `TeamCard` do dashboard ainda aponta para `/teams/[id]` (rota legada do scaffold inicial `c9ced84`).

**Essa é provavelmente a "melhoria que não está aparecendo"**: o usuário implementou as abas de Chat/Workers, mas clicando num card do dashboard ele cai na rota antiga sem nenhuma dessas features.

## 5. Estado do next dev

Processo `i9team-svc-frontend` saudável:
- Compilação OK, 602 modules
- `GET / 200` — dashboard funciona
- `GET /teams/cmo5orcto000a41lxf2dsrf33 200` — rota antiga sendo acessada
- **Nenhum erro/warning recente**

## 6. Onde o TeamCard aponta

`src/components/TeamCard.tsx:28`:
```tsx
<Link href={`/teams/${team.id}`} style={{...}} />
```

Precisaria ser:
```tsx
<Link href={`/team/${team.project}/${team.name}`} />
```

Ou o `id` ser trocado pela composição `project/team` — depende de qual rota o time quer manter. Há duplicação: `/teams/[id]` (por CUID) e `/team/[project]/[team]` (por slug).

## Resumo objetivo

- Frontend sincronizado com origin/main. Não há commits pendentes.
- Working tree tem refactor de runtime-config (sem commit ainda) — resolve hostname dinâmico
- Backend retorna `team-dev-service` corretamente
- **Feature "aba Chat" existe mas a navegação do dashboard não leva a ela** — `TeamCard` linka para rota legada `/teams/[id]` que usa `<Terminal>` direto, ignorando `AgentView` + `ChatTimeline`
- next dev sem erros
