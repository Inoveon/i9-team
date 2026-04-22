---
agent: team-dev-frontend
project: i9-team
tags:
  - frontend
  - i9-team
  - nextjs-15
  - xterm
  - agent-memory
  - snapshot
date: '2026-04-22'
---
# team-dev-frontend — Snapshot 2026-04-22

Snapshot consolidado do domínio frontend do projeto i9-team Portal (porta 4021). Reflete o estado REAL do código em `/home/ubuntu/projects/i9-team/frontend/` nesta data, não o briefing inicial do agente (que cita ShadCN incorretamente).

## Stack verificada em `package.json`

- Next.js ^15.3.1 (App Router, `reactStrictMode: false` intencional por causa do xterm/WS)
- React ^19.0.0 — páginas ativas são todas `"use client"`; apenas `layout.tsx` é Server Component
- TypeScript ^5.8.3 strict, alias `@/* → src/*`
- Tailwind CSS ^4.1.4 via `@tailwindcss/postcss` — **sem** `tailwind.config.*`, apenas `@import "tailwindcss"` no `globals.css`
- @xterm/xterm ^5.5 + @xterm/addon-fit ^0.10 — dynamic import dentro do useEffect pra não quebrar SSR
- framer-motion ^11.18, zustand ^5.0.3, sonner ^2.0.7
- @uiw/react-codemirror + lang-markdown + theme-one-dark (editor Notas)
- react-markdown + remark-gfm + rehype-highlight + highlight.js (viewer Notas, classe `.notes-markdown`)
- react-textarea-autosize (ChatInput)

⚠️ **ShadCN NÃO está instalado.** O briefing do agente está incorreto. Não existe `components/ui/`, nem `cn()`, nem `tailwind.config.ts`. Projeto usa **inline styles + CSS variables** (`var(--neon-blue)` etc). Se for pedido ShadCN explicitamente, instalar com cuidado.

## Tokens visuais (CSS vars em `src/app/globals.css`)

```
--bg #080b14       --surface #0d1117     --surface-2 #161b25
--border #1e2a3a   --text #e2e8f0        --text-muted #64748b
--neon-blue #00d4ff --neon-green #00ff88 --neon-purple #7c3aed
--neon-red #ff3864  --neon-yellow #ffd700
```

Utilitários: `.card` (surface + blur + hover glow), `.glow-blue/green/purple`, `.notes-markdown` (headings neon-blue/green/purple, code verde, blockquote purple).

Fontes: `"JetBrains Mono", "Fira Code"` para terminal/monospace, `Inter` para UI.

## Estrutura de pastas (src/)

```
app/
  layout.tsx                    Server Component — html.dark + Toaster sonner
  globals.css                   CSS vars + .card + .notes-markdown + @import xterm/highlight
  page.tsx                      Dashboard — polling 5s de teams
  config/page.tsx               Editor JSON de /teams/config
  team/[project]/[team]/page.tsx  Split orchestrator/workers + tab ?tab=notes

components/
  Terminal.tsx                  xterm passivo — recebe lines[] (legado, via AgentPanel)
  TerminalWS.tsx                xterm + WS próprio + overlay de menu interativo (CAMINHO ATUAL)
  AgentView.tsx                 Tab Terminal|Chat; Terminal sempre montado (display:none)
  AgentPanel.tsx                Card fallback sem sessionId
  TeamCard.tsx                  Card dashboard com Start/Stop
  StatusBadge.tsx               Dot animado (running tem pulse)
  chat/ ChatTimeline, ChatInput, UserBubble, ClaudeBubble, ToolCallCollapsible,
        ThinkingIndicator, SystemBadge, InteractiveMenu, AttachmentChip, NewMessagesPill
  notes/ NotesPanel, NotesList, NoteEditor, NoteViewer, NewNoteDialog, NotesToast

hooks/
  useMessageStream.ts           WS → store.chatBySession (dedup + reconcile otimista)
  useNotes.ts                   CRUD com ETag; 409 → NoteConflictError; 404 → NoteNotFoundError
  useToasts.ts

lib/
  api.ts                        fetch + token cache 23h + normalizer RawTeam → Team
  ws.ts                         createWebSocket legado (só AgentPanel)
  runtime-config.ts             getApiBase/getWsBase resolvem em runtime no browser
  store.ts                      zustand (teams, activeTeam, agentOutputs, chatBySession)
  chat-types.ts chat-reducer.ts chat-attachments.ts

types/index.ts                  Team, Agent, Session, AgentStatus, TeamConfig
```

## Padrão xterm.js

**Terminal.tsx** (passivo):
- Props: `lines: string[]`, `height?: number` (undefined = modo flex herdado do pai)
- Dynamic import no useEffect; escreve `last` em effect de `[lines]`
- Tema: bg #080b14, fg #00d4ff (azul), disableStdin, scrollback 5000

**TerminalWS.tsx** (atual):
- WS em `${WS_BASE}/ws?token=${encodeURIComponent(token)}` (token em query — browser não aceita header WS)
- Envia `{type:"subscribe", session}` ao abrir
- Recebe:
  - `{type:"output", data, hasMenu}` → `term.write("\x1b[2J\x1b[H" + data.replace(/\r?\n/g,"\r\n"))`
  - `{type:"interactive_menu", options, currentIndex}` → overlay absoluto zIndex 9999
- `noMenuCountRef` debounces 2 ticks antes de ocultar overlay (evita piscar)
- Envio: `{type:"input", keys}` livre, `{type:"select_option", session, value, currentIndex}` menu
- Tema: bg #0a0a0a, fg #00ff88 (verde), cursor #00d4ff, cursorBlink true, scrollback 10000
- Cleanup obrigatório: ws.close() + term.dispose() + observer.disconnect()

**Regra**: Terminal sempre montado (display:none quando tab chat) — não remontar xterm por troca de aba.

## Zustand — shape

```
teams: Team[]
activeTeam: Team | null
sessions: Record<string, Session>
agentOutputs: Record<string, string[]>    // legado (AgentPanel)
chatBySession: Record<string, ChatState>  // Onda 1 — chat com dedup
```

`ChatState = { events: StreamEvent[]; byKey: Map<string, number> }`

## Dedup / reconciliação (chat-reducer.ts)

- `eventKey` diferente por tipo:
  - user_input otimista: `user_input:opt:${clientTs}:${text}`
  - user_input eco: `user_input:${text}`
  - tool_call/result: `tool_*:${toolId}`
  - thinking: texto SEM sufixo `(Ns)` — regex `/\s*\(\d+s?\)$/` — senão duplica cada tick
  - claude_text/system: `${type}:${text}`
  - interactive_menu: `menu:${title}:${options.join("|")}`
- `tryReconcileOptimistic` FIFO com janela 30s — casa por `text`, preserva `id`/posição/anexos
- Sliding window MAX_EVENTS = 1000 (rebuild O(N) amortizado raro)
- `reduceEvents` retorna ref original se nada mudou → Zustand não re-renderiza

## Auth / runtime config

- `POST /auth/login {username, password}` (env `NEXT_PUBLIC_API_USER/PASS`, default admin/i9team)
- Token cacheado em memória `tokenExpiry = Date.now() + 23h`
- `Authorization: Bearer <token>` em todo request do `lib/api.ts`
- `getApiBase()/getWsBase()` resolvem em runtime usando `window.location.hostname` + porta 4020
- Override via `NEXT_PUBLIC_API_URL` / `NEXT_PUBLIC_WS_URL`
- Reconnect WS: setTimeout 2s no onclose, clearTimeout no cleanup (sem acumular zumbis)

## Upload de imagens (Onda 5)

- Endpoint: `POST /upload/image?teamId=<id>` com FormData `{file}`
- Limites client: MAX_FILE_SIZE 5MB (backend 15MB), MAX_ATTACHMENTS 6, mimes png/jpeg/webp/gif
- Paste: `extractFilesFromClipboard` cobre screenshot OS + copy image + file copy
- Revoke `URL.createObjectURL` no cleanup obrigatório
- `attachmentIds` vai em `POST /teams/:id/message` body (bate com `messageSchema.attachmentIds.max(6)` do backend)

## Endpoints consumidos

| Método | Path | Uso |
|--------|------|-----|
| POST | /auth/login | token |
| GET  | /teams | dashboard (normalizer RawTeam → Team) |
| GET  | /teams/:id/agents/status | polling 5s |
| GET  | /teams/:project/:team | team page |
| GET/PUT | /teams/config | editor |
| POST | /teams/:id/{start,stop} | botões |
| POST | /teams/:id/message | body `{agentId, message, attachmentIds?}` |
| GET/POST/PUT/DELETE | /teams/:id/notes[/:name] | CRUD com ETag |
| POST | /upload/image?teamId=<id> | FormData |

## Decisões arquiteturais relevantes

1. Dynamic import xterm no useEffect (SSR-safe)
2. Runtime config — mesmo bundle serve localhost e IP de rede
3. Chat state fora do hook (em zustand) — trocar tab Chat↔Terminal não perde timeline
4. FIFO reconcile por clientTs — 2x "ok" consecutivos casam na ordem correta
5. Polling pra status de teams + WS só pra output de sessions tmux
6. Overlay menu com zIndex 9999 + pointerEvents:auto (canvas xterm está em zIndex 0)
7. `reactStrictMode: false` **intencional** — double-mount quebra xterm dispose/WS close

## Pegadinhas

- Não reativar reactStrictMode
- `@xterm/xterm/css/xterm.css` e `highlight.js/styles/github-dark.css` só em `globals.css`
- Terminal.tsx (passivo) ≠ TerminalWS.tsx (WS próprio) — não confundir
- Seletores zustand granulares; evitar retornar objeto inline
- `router.replace(url, { scroll: false })` em mudança de tab
- Regex de remover `(Ns)` no `eventKey` do thinking
- `<Toaster />` só em layout.tsx
- Sem backend UP em :4020, dashboard fica silenciosamente vazio (catch {} em fetchTeams)

## Rotas

- `/` — dashboard
- `/config` — editor JSON
- `/team/[project]/[team]` — split com tab agentes
- `/team/[project]/[team]?tab=notes[&note=<name>]` — aba notas

## Comandos

```
cd frontend && npm run dev         # porta 4021
npm run dev:clean                  # apaga .next
npm run build && npm run start
npm run lint
```

## Protocolo do agente (auto-lembrete)

- Notas SEMPRE via MCP (`team_note_write` pra orquestrador, `i9-agent-memory__note_write` pra persistência)
- Nunca criar .md solto via Write
- Nunca delegar — frontend implementa e reporta
- Dark mode obrigatório; PT-BR em comentários/logs
- Ao concluir: "NOTES-OK" + lista + resumo
