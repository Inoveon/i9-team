---
title: Multi-Client MCP — Fase 0 concluída
tags:
  - arquitetura
  - multi-client
  - mcp
  - gemini
  - codex
  - fase-0
  - milestone
date: '2026-04-23'
status: concluído
projeto: i9-team
autor: team-orchestrator
---
# Multi-Client MCP — Fase 0 CONCLUÍDA

**Data**: 2026-04-23
**Doc principal**: [`i9-team/docs/MULTI-CLIENT-MCP.md`](file:///home/ubuntu/projects/i9-team/docs/MULTI-CLIENT-MCP.md) (v0.4)
**Commits**: a cadeia começou em `1671f7d` (v0.1) e chega em `<próximo>` (v0.4)

## Milestone

Primeiro agente operando em CLI **não-Claude** dentro da frota i9-team. Dois agentes cobaia no ar:
- **team-gemini** — Gemini 3 Auto via Gemini CLI
- **team-codex** — gpt-5.4 via OpenAI Codex CLI

Ambos reconhecidos pela MCP i9-team como agentes legítimos do team `i9-team/dev`, invocando tools corretamente e identificando sua própria identidade.

## O que foi implementado

### 1. MCP i9-team — identidade via env vars

`mcp-servers/i9-team/src/config.ts`:
- Novo tipo `ClientType = "claude-code" | "gemini-cli" | "codex-cli"`
- Campo `client?: ClientType` em `AgentConfig` (default `claude-code`)
- Nova função `resolveCurrentContext()`:
  1. Prioriza env vars `MCP_PROJECT`, `MCP_TEAM`, `MCP_AGENT_NAME`
  2. Fallback pra `getCurrentSession()` + `resolveContext()` (legado tmux)

Todas as 6 tools (send-agent, list-agents, check-agent, bridge-send, select-option, notes) migradas pra `resolveCurrentContext()`.

Build: `npm run build` OK. Dist refletindo em `/home/ubuntu/mcp-servers/i9-team/dist/`.

### 2. teams.json — 2 agentes cobaia

Adicionados em `i9-team/dev`:
```json
{"name": "team-gemini", "dir": ".", "client": "gemini-cli"},
{"name": "team-codex",  "dir": ".", "client": "codex-cli"}
```

### 3. team-agent-boot.sh

`~/.claude/scripts/team-agent-boot.sh <project> <team> <agent>`:
- Reusa `~/.claude/teams.json` como fonte da verdade
- Respeita campo `client` de cada agente
- Injeta env vars `I9_*` (legado) + `MCP_*` (multi-client)
- Lança o CLI correto:
  - `claude-code` → `claude`
  - `gemini-cli` → `gemini --yolo`
  - `codex-cli` → `codex --yolo -c mcp_servers.i9-team.env.MCP_* + mcp_servers.i9-agent-memory.env.MCP_*`

### 4. Validação funcional

#### Teste decisivo — env totalmente isolada
```bash
env -i HOME=/home/ubuntu PATH=... \
  MCP_PROJECT=i9-team MCP_TEAM=dev MCP_AGENT_NAME=team-gemini MCP_CLIENT_ID=gemini \
  gemini --yolo -p "Invoke team_list_agents"
```
Retornou lista real dos 5 agentes iniciais do team — **sem tmux, sem herança, só via env**. Prova que a MCP resolve identidade exclusivamente a partir das env vars injetadas.

#### Teste E2E — 2 sessões subidas

Ambos os agentes confirmaram auto-identidade via tool:

| Agente | `$MCP_AGENT_NAME` | `team_list_agents` |
|---|---|---|
| team-gemini | `team-gemini` ✅ | 7 agentes ✅ |
| team-codex | `team-codex` ✅ | 7 agentes ✅ |

## Arquitetura validada

```
┌─────────────────────────────────────────────────────┐
│ Sessão tmux com env MCP_PROJECT/MCP_TEAM/MCP_AGENT  │
│                                                      │
│  CLI (Claude/Gemini/Codex) roda aqui                │
│         │                                            │
│         │ invoca MCP via stdio, passa env vars       │
│         │                                            │
│         ▼                                            │
│  MCP i9-team process                                 │
│    └ resolveCurrentContext()                         │
│        ├ 1º: tenta MCP_PROJECT + MCP_TEAM +          │
│        │      MCP_AGENT_NAME (funciona p/ todos)     │
│        └ 2º: fallback tmux (legado)                  │
└─────────────────────────────────────────────────────┘
```

- **Claude**: herda env naturalmente, também funciona com fallback tmux
- **Gemini**: herda env naturalmente via `$TMUX` + shell
- **Codex**: sandbox isola env → usa `-c mcp_servers.*.env.*` pra injetar

## Quirks catalogados (cumulativo desde início)

| ID | Descrição | Cliente | Severidade |
|---|---|---|---|
| Q1 | `gemini mcp list` retorna stdout vazio | Gemini | Baixa |
| Q2 | Gemini pede "Trust folder" na 1ª exec (TTY obrigatório) | Gemini | Média |
| Q3 | Config Codex em TOML | Codex | Baixa |
| Q4 | Codex exige git repo (flag `--skip-git-repo-check` no `exec`) | Codex | Baixa |
| Q5 | Codex sandbox isola env — solução: `-c mcp_servers.*.env.*` | Codex | **Alta** (resolvido) |
| Q6 | `codex mcp list` mascara env com `*****` (feature) | Codex | (positivo) |
| Q7 | `codex mcp-server` — Codex pode servir como MCP | Codex | Interessante |
| Q8 | `--dangerously-bypass-approvals-and-sandbox` e `--skip-git-repo-check` são só do subcomando `exec`; modo interativo usa `--yolo` | Codex | Baixa |
| Q9 | Codex pede "Trust directory" na 1ª exec por CWD | Codex | Média |

## Backlog da Fase 1

- POC: team-gemini/team-codex recebendo task real via `team_send` do orquestrador
- Medição ROI: tokens/tarefa, tempo médio, taxa de sucesso
- Comparativo Gemini vs Codex vs Claude pra mesma tarefa
- Documentar padrão "agente cobaia → promoção a agente regular"

## Backlog da skill `/team-auth-cli`

Design congelado, pronto pra implementação. Estrutura:
```
~/.claude/skills/team-auth-cli/
├── SKILL.md
├── scripts/
│   ├── status.sh
│   ├── auth-claude.sh
│   ├── auth-gemini.sh
│   ├── auth-codex.sh
│   └── lib-oauth-tmux.sh
└── README.md
```

Fluxos mapeados nos docs de Gemini + Codex fases anteriores.

## Arquivos criados/alterados

**No repo mcp-servers**:
- `i9-team/src/config.ts` (modificado)
- `i9-team/src/tools/{send-agent,list-agents,check-agent,bridge-send,select-option,notes}.ts` (modificados)
- `i9-team/dist/**` (rebuild)

**No repo i9-team**:
- `docs/MULTI-CLIENT-MCP.md` (v0.3 → v0.4)

**Fora dos repos** (precisam ser versionados em breve):
- `~/.claude/scripts/team-agent-boot.sh` (novo — 90 linhas)
- `~/.claude/teams.json` (+2 agentes)
- `~/.gemini/settings.json` (3 MCPs registradas)
- `~/.codex/config.toml` (3 MCPs registradas)

## Conclusão

Multi-Client MCP não é mais uma ideia — **é realidade operacional**. Qualquer agente da frota pode, a partir de agora, ser rodado em Claude, Gemini ou Codex **sem alteração na MCP**. A economia prometida (rodar "trabalho braçal" em CLIs mais baratos) pode começar na Fase 1 com os cobaia.

Princípio #1 (Claude é fonte da verdade) permanece intacto: os 7 orquestradores continuam Claude Code; Gemini e Codex entram só como agentes.
