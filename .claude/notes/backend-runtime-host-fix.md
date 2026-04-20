# Fix — frontend servindo em localhost E IP remoto (mesmo bundle)

**Agente:** team-dev-backend
**Data:** 2026-04-19
**Contexto:** dashboard em `http://10.0.10.17:4021` não carregava teams porque o bundle estava hardcoded em `http://localhost:4020`.

## Causa raiz

5 arquivos tinham const top-level com `process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:4020"`. Em SSR ou quando a env não está setada no build, o fallback `localhost:4020` vira hardcoded no bundle → client remoto (10.0.10.17) tenta falar com o `localhost` dele mesmo e falha.

## Solução aplicada

Helper dinâmico **baseado em `window.location.hostname`**, chamado em **runtime dentro das funções** (não const top-level, senão SSR cacheia).

## Arquivos

### CRIADO
- `frontend/src/lib/runtime-config.ts` — exporta `getApiBase()` e `getWsBase()`

### EDITADOS (const top-level removido → chamada runtime)
- `frontend/src/lib/api.ts` — `getApiBase()` dentro de `getToken()` e `request()`
- `frontend/src/lib/ws.ts` — `getWsBase()` dentro de `createWebSocket()`
- `frontend/src/hooks/useMessageStream.ts` — `getWsBase()` dentro de `connect()`
- `frontend/src/components/TerminalWS.tsx` — `getWsBase()` dentro de `init()`
- `frontend/src/components/ImageUpload.tsx` — `getApiBase()` dentro de `uploadFile()` e `sendToAgent()`

## Comportamento

| Onde o browser abre          | hostname resolvido | Chama backend em           |
|------------------------------|--------------------|----------------------------|
| `http://localhost:4021`      | `localhost`        | `http://localhost:4020`    |
| `http://10.0.10.17:4021`     | `10.0.10.17`       | `http://10.0.10.17:4020`   |
| `https://portal.example`     | `portal.example`   | `https://portal.example:4020` (porta fixa — ajuste se usar domínio real com TLS) |

`NEXT_PUBLIC_API_URL`/`NEXT_PUBLIC_WS_URL` continuam sendo overrides explícitos.

## Backend — checagens

- `src/index.ts:60` → `app.listen({ port: config.port, host: '0.0.0.0' })` ✓ aceita conexões externas
- `src/index.ts:24` → `cors, { origin: true }` ✓ aceita qualquer origem
- **Nada a mudar no backend.**

## Endpoint que o dashboard consome

`src/lib/api.ts:58` — `GET /teams` → retorna `{ teams: RawTeam[] }`.

## Pendências (orquestrador delegar)

1. **team-dev-service / team-dev-frontend** — reiniciar o frontend para pegar o novo bundle:
   ```bash
   tmux kill-session -t i9team-svc-frontend
   tmux new-session -d -s i9team-svc-frontend -c /home/ubuntu/projects/i9-team/frontend 'make dev'
   ```
   Aguardar ~30s para o Next compilar.

2. **Validação externa** (precisa ser feita sem context-mode):
   - `curl -sI http://10.0.10.17:4020/` → deve responder (ou `/health` → `{"status":"ok"}`)
   - abrir `http://10.0.10.17:4021` no browser → dashboard deve listar os teams
   - console do browser: `fetch('/auth/login', ...)` resolve para `10.0.10.17:4020`

## Por que não usar rewrites do next.config

O frontend usa WebSocket pesado (streaming de output tmux via `/ws`). `rewrites` do Next faz proxy HTTP bem, mas **não faz upgrade de WebSocket** sem middleware customizado (http-proxy-middleware). Helper dinâmico é mais simples e 100% client-side — mesmo bundle serve qualquer hostname.
