# i9-team Portal

Portal web futurista + app mobile para gestão e monitoramento de teams de agentes Claude Code via tmux.

## Stack

- **Backend**: Fastify 5 + node-pty + WebSocket (porta 4020) — `backend/`
- **Frontend**: Next.js 15 + xterm.js + ShadCN dark futurista (porta 4021) — `frontend/`
- **Mobile**: Flutter + Riverpod + glass UI — `mobile/`

## Memória

Usar `mcp__i9-agent-memory__*` para persistência entre sessões.
Buscar contexto antes de qualquer ação: `mcp__i9-agent-memory__search(query: "tema")`.

## context-mode — MANDATORY routing rules

Bash com output >20 linhas → usar ctx_execute ou ctx_batch_execute.
curl/wget → bloqueado, usar ctx_fetch_and_index.

## Padrões

- Português brasileiro em todas as respostas e comentários
- Commits apenas via `/commit` skill
- TypeScript strict em backend e frontend
- Dart/Flutter com null safety em mobile
- Dark mode obrigatório no frontend e mobile

## Portas

| Serviço  | Porta |
|----------|-------|
| Backend  | 4020  |
| Frontend | 4021  |
