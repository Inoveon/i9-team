---
title: 'Multi-Client MCP — Fase 3 início: team.sh oficial integrado + validação ROI'
tags:
  - arquitetura
  - multi-client
  - fase-3
  - team-sh
  - validacao-roi
date: '2026-04-23'
status: em-progresso
---
# Multi-Client MCP — Fase 3 início: team.sh oficial + validação ROI

**Data**: 2026-04-23

## Mudança principal

`~/.claude/scripts/team.sh` agora respeita o campo `client` de `teams.json`. Hardcoded Claude → lançamento dinâmico do CLI apropriado.

### Backup preservado

- `team.sh.bak.20260420-041209` — versão antes de qualquer mudança
- `team.sh.bak.pre-multi-client.20260423-121526` — versão pós-Fase 1 / pré-Fase 3

### Diff funcional (resumo)

1. **3 vars de binário em vez de 1**:
   ```bash
   CLAUDE_BIN / GEMINI_BIN / CODEX_BIN
   ```

2. **Injeção de env MCP_*** no `tmux new-session`: `MCP_PROJECT`, `MCP_TEAM`, `MCP_AGENT_NAME`, `MCP_CLIENT_ID` — além das legadas `I9_*`.

3. **Comando do CLI é dinâmico** baseado no `client`:
   - `claude-code` → `claude --agent <aname>` (comportamento original)
   - `gemini-cli` → `gemini --yolo` (herda env)
   - `codex-cli` → `codex --yolo -c mcp_servers.*.env.MCP_*=...` (bypass sandbox)
   - Outros: pula com warning

4. **`/team-protocol` e `/remote-control` só pra Claude** — features nativas do Claude Code, não aplicam nos outros CLIs.

5. **`team.sh list` agora mostra `[client]`** ao lado de cada agente.

## Validação prática — i9-service/dev

Sequência:
```bash
~/.claude/scripts/team.sh stop i9-service dev
~/.claude/scripts/team.sh start i9-service dev
```

Resultado no log do team.sh:
```
→ Criando sessão: i9-service-dev-orquestrador (client: claude-code)
→ Criando sessão: i9-service-dev-team-dev-backend (client: gemini-cli)
→ Criando sessão: i9-service-dev-team-dev-web (client: gemini-cli)
→ Criando sessão: i9-service-dev-team-dev-mobile (client: gemini-cli)
→ Criando sessão: i9-service-dev-team-dev-service (client: claude-code)
```

Após ~40s:
- Orquestrador: Claude ✅ (+ /team-protocol + /remote-control aplicados automaticamente)
- Backend/Web/Mobile: Gemini 3 Auto ✅ (prompt limpo com 4 MCP servers)
- Service: Claude ✅ (+ /team-protocol aplicado)

**Feedback positivo**: workflow oficial (`team.sh`) agora produz team multi-cliente **sem requerer ação manual do usuário**. Campo `client` em `teams.json` é a fonte única.

## Validação ROI (aguardando)

Bridge enviado ao orquestrador i9-service pra delegar tarefa simples aos 4 agentes e comparar qualidade.

Correlation: `243cde06-112d-4b9c-aa43-03307bd54024`

Atualizarei esta nota quando a resposta chegar.

## Arquivos tocados

| Arquivo | Mudança |
|---|---|
| `~/.claude/scripts/team.sh` | +40 linhas (suporte multi-client) |
| `~/.claude/scripts/team.sh.bak.pre-multi-client.20260423-121526` | Backup automático |
| `i9-team/docs/multi-client-assets/team.sh.multi-client` | Cópia arquivada no repo pra versionamento |
| `i9-team/docs/multi-client-assets/team-agent-boot.sh` | Script paralelo (Fase 1) arquivado junto |

## Arquitetura operacional

```
~/.claude/teams.json  ← fonte única (campo client por agente)
        │
        ▼
~/.claude/scripts/team.sh start <proj> <team>
        │
        ▼ (por agente)
┌──────────────────────────┐
│ tmux new-session + env   │  (I9_* + MCP_* injetadas)
└──────────────────────────┘
        │
        ▼ (case client)
┌────────────────────────────────────┐
│ claude-code → claude --agent X      │
│ gemini-cli  → gemini --yolo         │
│ codex-cli   → codex --yolo -c ...   │
└────────────────────────────────────┘
        │
        ▼ (se claude-code)
/team-protocol + /remote-control aplicados
```
