# team-dev-frontend — Memória persistente

> **Última atualização:** 2026-04-22
> **Domínio:** `frontend/` — dashboard Next.js 15 para o i9-team Portal.
> **Porta:** 4021 (dev/start). Backend em 4020 (mesmo host, resolvido via `window.location.hostname`).

---

## 1. Stack real (verificada em `package.json` — não confiar no briefing)

| Peça | Versão | Observação |
|------|--------|------------|
| Next.js | ^15.3.1 | App Router, `reactStrictMode: false` (next.config.ts) |
| React | ^19.0.0 | Server Components por default; todas as páginas ativas são `"use client"` |
| TypeScript | ^5.8.3 | `strict: true`, alias `@/* → src/*` |
| Tailwind CSS | ^4.1.4 | v4 via `@tailwindcss/postcss` — SEM `tailwind.config.*`, só `@import "tailwindcss"` em globals.css |
| @xterm/xterm | ^5.5.0 | Dynamic import (`await import("@xterm/xterm")`) pra não quebrar SSR |
| @xterm/addon-fit | ^0.10.0 | FitAddon + ResizeObserver |
| framer-motion | ^11.18 | Transições de cards/tabs |
| zustand | ^5.0.3 | Store global (`src/lib/store.ts`) |
| sonner | ^2.0.7 | Toasts (Toaster em layout.tsx, theme="dark") |
| @uiw/react-codemirror + lang-markdown + theme-one-dark | CodeMirror no editor de Notas |
| react-markdown + remark-gfm + rehype-highlight | Render Markdown (CSS `.notes-markdown` em globals.css) |
| react-textarea-autosize | ChatInput |

> ⚠️ **ShadCN NÃO está instalado.** O briefing do agente mente — não há `components/ui/`, nem `tailwind.config`, nem `cn()`. O projeto usa **inline styles + CSS variables** (`var(--neon-blue)` etc). Não inventar import ShadCN; se for pedido, instalar explicitamente.

---

## 2. Convenção de estilização

- **CSS variables em `src/app/globals.css`** são a fonte de verdade de cores/tokens:
  ```
  --bg: #080b14        --surface: #0d1117       --surface-2: #161b25
  --border: #1e2a3a    --text: #e2e8f0          --text-muted: #64748b
  --neon-blue: #00d4ff --neon-green: #00ff88    --neon-purple: #7c3aed
  --neon-red: #ff3864  --neon-yellow: #ffd700
  ```
- **Classe `.card`** (globals.css) = surface + border + `backdrop-filter: blur(12px)` + hover glow azul.
- **Classes `.glow-blue`, `.glow-green`, `.glow-purple`** = utilitários de box-shadow.
- **Fonte mono:** `"JetBrains Mono", "Fira Code", monospace` (terminal, timestamps, badges).
- **Fonte UI:** `Inter, ui-sans-serif, system-ui`.
- **Dark only** — `<html className="dark" lang="pt-BR" suppressHydrationWarning>` em layout.tsx.
- **Markdown das Notas** é estilizado pela classe `.notes-markdown` (headings em neon-blue/green/purple, code verde, blockquote purple).
- **Inline style em vez de className** é o padrão do projeto. Tailwind é usado basicamente para reset, custom scrollbar e `dark` trigger — NÃO para layout.

---

## 3. Estrutura de pastas (src/)

```
src/
├── app/
│   ├── layout.tsx                  # html.dark + Toaster sonner
│   ├── globals.css                 # CSS vars + .card + .notes-markdown + @import xterm/highlight.js
│   ├── page.tsx                    # Dashboard: lista teams (polling 5s)
│   ├── config/page.tsx             # Editor JSON de teams (GET/PUT /teams/config)
│   └── team/[project]/[team]/
│       └── page.tsx                # View do team — split orchestrator/workers + tab Notas
├── components/
│   ├── Terminal.tsx                # xterm wrapper passivo (recebe `lines: string[]`) — usado pelo AgentPanel
│   ├── TerminalWS.tsx              # xterm + WebSocket próprio + overlay de menu interativo
│   ├── AgentView.tsx               # Tab Terminal|Chat com useMessageStream; terminal sempre montado (display:none)
│   ├── AgentPanel.tsx              # Card legado: Terminal passivo + ChatInput (usado como fallback sem sessionId)
│   ├── TeamCard.tsx                # Card do dashboard com Start/Stop
│   ├── StatusBadge.tsx             # Dot animado + label (idle/running/error/stopped)
│   ├── ImageUpload.tsx             # (utilitário antigo)
│   ├── chat/
│   │   ├── ChatTimeline.tsx        # Scroll + IntersectionObserver sentinel pra "atBottom"
│   │   ├── ChatInput.tsx           # Textarea autosize + upload de anexos + paste handler
│   │   ├── UserBubble.tsx          ├── ClaudeBubble.tsx      ├── SystemBadge.tsx
│   │   ├── ThinkingIndicator.tsx   ├── ToolCallCollapsible   ├── InteractiveMenu.tsx
│   │   ├── AttachmentChip.tsx      └── NewMessagesPill.tsx
│   └── notes/
│       ├── NotesPanel.tsx   NotesList.tsx   NoteEditor.tsx   NoteViewer.tsx
│       ├── NewNoteDialog.tsx   NotesToast.tsx
├── hooks/
│   ├── useMessageStream.ts         # WS → store.chatBySession (dedup + reconcile otimista)
│   ├── useNotes.ts                 # CRUD de notas com ETag (409 → NoteConflictError)
│   └── useToasts.ts
├── lib/
│   ├── api.ts                      # fetch wrapper + token cache (23h) + getTeams normalizer
│   ├── ws.ts                       # createWebSocket legado (só usado por AgentPanel)
│   ├── runtime-config.ts           # getApiBase / getWsBase — resolve em runtime no browser
│   ├── store.ts                    # zustand: teams, activeTeam, agentOutputs, chatBySession
│   ├── chat-types.ts               # StreamEvent, ChatState, EMPTY_CHAT_STATE
│   ├── chat-reducer.ts             # reduceEvents pure + tryReconcileOptimistic (FIFO)
│   └── chat-attachments.ts         # Attachment types + uploadAttachment + validação client-side
└── types/index.ts                  # Team, Agent, Session, AgentStatus, TeamConfig
```

---

## 4. App Router — Server vs Client components

- **Todas as páginas** (`app/page.tsx`, `app/config/page.tsx`, `app/team/[project]/[team]/page.tsx`) são **`"use client"`** por precisarem de polling/store/WS.
- **`app/layout.tsx` é Server Component** (único sem `"use client"`) — carrega `<Toaster>` do sonner (que é client por dentro).
- **Metadata API** usada apenas no `layout.tsx`.
- Polling padrão de 5s para dashboard/team page; 30s para notas.
- **Params dinâmicos**: `useParams<{ project: string; team: string }>()` + `useSearchParams` + `router.replace(url, { scroll: false })` para tabs sem scroll jump.
- **`suppressHydrationWarning`** no `<html>` evita flash de tema.

---

## 5. xterm.js — padrão de wiring

### Terminal.tsx (legado, passivo)
- Recebe `lines: string[]` via props → escreve via `term.writeln(last)` no effect de `[lines]`.
- Dynamic import dentro do useEffect (`await import("@xterm/xterm")`) para evitar erro de SSR (`ReferenceError: self is not defined`).
- Tema: `background #080b14`, `foreground #00d4ff`, `cursor #00d4ff`, `disableStdin: true`, `scrollback: 5000`.
- ResizeObserver + FitAddon fazem re-fit em mudança de layout.

### TerminalWS.tsx (atual, fonte única de verdade)
- Abre WebSocket próprio em `${WS_BASE}/ws?token=${encodeURIComponent(token)}`.
- Envia `{ type: "subscribe", session }` ao conectar.
- Recebe 2 tipos de mensagens:
  - `{ type: "output", data, hasMenu }` — aplica `\x1b[2J\x1b[H` (clear + home) + normaliza `\n → \r\n`.
  - `{ type: "interactive_menu", options, currentIndex }` — renderiza overlay absoluto com zIndex 9999 sobre o canvas.
- `noMenuCountRef` = 2 debounces antes de ocultar overlay (evita piscar).
- Envio de input:
  - texto livre: `{ type: "input", keys: text }`.
  - seleção de menu: `{ type: "select_option", session, value, currentIndex }`.
- Tema WS: `background #0a0a0a`, `foreground #00ff88` (verde), `cursor #00d4ff`, `cursorBlink: true`, `scrollback: 10000`.
- Token obtido via `getAuthToken()` antes de montar WS (browser não aceita header em WS).

### Regra de ouro
- Terminal **sempre montado** no AgentView mesmo quando tab ativa é "chat" (`display: none`) — evita refazer `new XTerm()` toda troca de aba.
- Cleanup obrigatório: `wsRef.current?.close()` + `termRef.current?.dispose()` + `observer.disconnect()`.

---

## 6. Store Zustand — shape oficial

```ts
{
  teams: Team[]
  activeTeam: Team | null
  sessions: Record<string, Session>
  agentOutputs: Record<string, string[]>        // legacy — usado só pelo AgentPanel
  chatBySession: Record<string, ChatState>      // Onda 1 — chat dedup
}
```

- **`chatBySession`** sobrevive ao unmount do hook (trocar tab Chat↔Terminal não perde timeline).
- **Dedup via `byKey: Map<string, index>`** no `ChatState`. A chave muda por tipo (ver `chat-reducer.ts:eventKey`):
  - `user_input` otimista: `user_input:opt:${clientTs}:${text}`
  - `tool_call/result`: `tool_{call|result}:${toolId}`
  - `thinking`: texto **sem sufixo `(Ns)`** (duração cresce entre ticks → mesma chave).
- **Reconciliação otimista FIFO** em `tryReconcileOptimistic`: janela de 30s, casa por `text`, preserva `id`/posição/anexos.
- **Sliding window**: `MAX_EVENTS = 1000` — ao exceder rebuilda `byKey` (O(N) amortizado raro).
- **`reduceEvents` retorna ref original** se nada mudou → Zustand não re-renderiza.

---

## 7. WebSocket + auth

- Auth por JWT em 2 etapas:
  1. `POST /auth/login` com `{username, password}` (env `NEXT_PUBLIC_API_USER/PASS`, default `admin/i9team`).
  2. Token cacheado em memória com `tokenExpiry = Date.now() + 23h`.
- Header `Authorization: Bearer <token>` em todo `request<T>()` do `lib/api.ts`.
- WS passa token via query param (`?token=...`) porque browser não permite headers em WS.
- **Reconnect**: `setTimeout` de 2s no `onclose`, com `clearTimeout` no cleanup para evitar reconexões zumbi.

---

## 8. Upload de imagens (Onda 5)

- Arquivo: `lib/chat-attachments.ts`.
- Endpoint: `POST /upload/image?teamId=<id>` com `FormData { file }`.
- Limites client: `MAX_FILE_SIZE = 5MB`, `MAX_ATTACHMENTS = 6`, mimes `png/jpeg/webp/gif`.
- Backend limita 15MB — cliente valida 5MB para dar feedback cedo.
- Paste handler (`extractFilesFromClipboard`) cobre screenshot OS + copy image + file copy.
- Status do chip: `uploading | uploaded | error`.
- `URL.createObjectURL(file)` **precisa** ser `revokeObjectURL` no cleanup.
- `attachmentIds` vai no body do `POST /teams/:id/message` (máx 6, bate com backend `messageSchema`).

---

## 9. API endpoints usados (via `lib/api.ts`)

| Método | Path | Uso |
|--------|------|-----|
| POST | /auth/login | token |
| GET  | /teams | dashboard (com normalizador RawTeam → Team) |
| GET  | /teams/:id/agents/status | polling status |
| GET  | /teams/:project/:team | team page |
| GET/PUT | /teams/config | editor JSON |
| POST | /teams/:id/start \| /teams/:id/stop | Start/Stop |
| POST | /teams/:id/message | envio (body: `{agentId, message, attachmentIds?}`) |
| GET  | /teams/:id/notes | lista (ordenada DESC por `updatedAt`) |
| GET/PUT/POST/DELETE | /teams/:id/notes/:name | CRUD com ETag |
| POST | /upload/image?teamId=<id> | FormData file |

- Erros 409 em notes → `NoteConflictError` com `{currentEtag, currentContent}`.
- Erros 404 em notes → `NoteNotFoundError`, também remove da lista local.

---

## 10. Rotas (App Router)

| Rota | Arquivo |
|------|---------|
| `/` | `app/page.tsx` |
| `/config` | `app/config/page.tsx` |
| `/team/[project]/[team]` | `app/team/[project]/[team]/page.tsx` |
| `/team/[project]/[team]?tab=notes` | mesma página — aba notas |
| `/team/[project]/[team]?tab=notes&note=<name>` | abre nota específica |

---

## 11. Decisões arquiteturais importantes

1. **Dynamic import de xterm dentro do useEffect** — evita quebrar SSR. Se for componentizar mais, manter padrão.
2. **Runtime config em vez de build-time** (`getApiBase()/getWsBase()`) — o mesmo bundle serve `localhost:4021` e `10.0.10.17:4021` resolvendo pelo hostname do browser.
3. **Chat state fora do hook** (em zustand) — permite alternar tab Chat/Terminal sem perder timeline e permite futuros clearChatSession/append externos.
4. **FIFO reconciliation por `clientTs`** — dois "ok" enviados rápido casam com os ecos na ordem correta.
5. **Polling em vez de WS para status dos teams** — status de tmux sessions é barato; WS é usado só para o output dos agentes.
6. **Overlay de menu interativo com zIndex 9999** — canvas do xterm está em zIndex 0; `pointerEvents: auto` explícito nos botões.
7. **Token expiry fake (23h)** — não verifica decode real do JWT; suficiente enquanto backend emite com `expiresIn: "24h"`.

---

## 12. Pegadinhas que já me morderam

- `reactStrictMode: false` **intencional** — double-mount quebra xterm dispose/WS close. Não ativar.
- `globals.css` importa `@xterm/xterm/css/xterm.css` e `highlight.js/styles/github-dark.css` — **não importar per-component** (perde SSR + duplica CSS).
- `Terminal.tsx` (passivo) e `TerminalWS.tsx` são **diferentes** — cuidado ao editar; `TerminalWS` é o caminho atual.
- `useTeamStore` seletores: usar `(s) => s.x` granulares; não retornar objetos inline sem `shallow`.
- `router.replace` em useCallback de tab precisa `scroll: false` — senão dashboard scroll ao topo.
- `chat-reducer.eventKey` para `thinking` DEVE remover regex `/\s*\(\d+s?\)$/` — senão duplica cada segundo.
- Evitar `useEffect` com `events` como dep — usar `events.length`.
- Sonner `<Toaster />` SÓ em `layout.tsx`, não em páginas (duplica).

---

## 13. Comandos úteis

```bash
# dev hot-reload
cd /home/ubuntu/projects/i9-team/frontend && npm run dev   # porta 4021

# limpo (após upgrade major / hang .next)
npm run dev:clean

# build prod
npm run build && npm run start

# lint
npm run lint
```

- Porta 4021 é definida no `package.json`, não no `next.config`.
- Backend precisa estar UP em `<host>:4020` senão dashboard fica vazio silenciosamente (catch vazio em `fetchTeams`).

---

## 14. Protocolo do agente (auto-lembrete)

- **Notas SEMPRE via MCP** (`mcp__i9-team__team_note_write` ou `mcp__i9-agent-memory__note_write`) — nunca criar `.md` solto no fs.
- **Não delegar** — agente frontend implementa e reporta.
- **Dark mode obrigatório**, sem light mode sequer como fallback.
- **Português brasileiro** em comentários/mensagens/logs.
- Ao concluir: reportar "NOTES-OK" + lista de arquivos + resumo.
