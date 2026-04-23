---
title: 'Multi-Client MCP — Fase 0: Codex CLI + validação funcional'
tags:
  - arquitetura
  - multi-client
  - codex
  - gemini
  - mcp
  - fase-0
date: '2026-04-23'
status: em-progresso
projeto: i9-team
autor: team-orchestrator
---
# Multi-Client MCP — Fase 0: Codex CLI instalado + validação funcional

**Data**: 2026-04-23
**Fase**: 0 (Discovery)
**Documento principal**: [`i9-team/docs/MULTI-CLIENT-MCP.md`](file:///home/ubuntu/projects/i9-team/docs/MULTI-CLIENT-MCP.md)
**Complementa**: `arquitetura/multi-client-mcp-fase-0-gemini-2026-04-23.md`

## Resumo

Codex CLI v0.123.0 instalado e autenticado via OAuth device flow (ChatGPT). 3 MCPs da frota configuradas em `~/.codex/config.toml`. Gemini validado end-to-end (invocou tool real da MCP i9-team). Codex invoca MCP mas esbarra em isolamento de env vars do sandbox — exatamente o cenário previsto no item técnico #2 do doc.

## Codex CLI

### Instalação
- Pacote npm: `@openai/codex` → v0.123.0 (research preview)
- Binary: `/home/ubuntu/.nvm/versions/node/v24.15.0/bin/codex`
- Config em TOML: `~/.codex/config.toml`
- Credenciais: `~/.codex/auth.json` (chmod 600)

### Auth OAuth via ChatGPT

Comando: `codex login --device-auth`

Fluxo:
1. CLI imprime `https://auth.openai.com/codex/device` + código 8 chars (ex: `XQ4G-ZT2V5`)
2. Usuário abre URL, loga ChatGPT, cola código, autoriza
3. CLI (polling) detecta sozinho e salva token
4. `codex login status` → `Logged in using ChatGPT`
- Código expira em 15 min

### MCPs configuradas

Sintaxe:
```bash
codex mcp add <name> --env KEY=VALUE -- <comando> <arg1> <arg2>
```

Resultado em `config.toml`:
```toml
[mcp_servers.i9-team]
command = "/home/ubuntu/.nvm/versions/node/v24.15.0/bin/node"
args = ["/home/ubuntu/mcp-servers/i9-team/dist/index.js"]

[mcp_servers.i9-agent-memory]
command = "..."
args = [...]
[mcp_servers.i9-agent-memory.env]
VAULT_NAME = "i9-smart-pdv"
# ...
```

`codex mcp list` **funciona** (diferente do Gemini) — tabela rica com mascaramento de secrets.

## Validação funcional — teste da tool `mcp__i9-team__team_list_agents`

### ✅ Gemini — funcional end-to-end

Comando: `gemini --yolo -p "Invoke a tool..."` rodando em `/tmp`.

Retornou:
```
Team: dev | Projeto: i9-team
Orquestrador: team-orchestrator
Agentes:
  ✓ team-orchestrator [ORQUESTRADOR] → sessão: i9-team-dev-orquestrador
  ✓ team-dev-backend → sessão: i9-team-dev-team-dev-backend
  ✓ team-dev-frontend → sessão: i9-team-dev-team-dev-frontend
  ✓ team-dev-mobile → sessão: i9-team-dev-team-dev-mobile
  ✓ team-dev-service → sessão: i9-team-dev-team-dev-service
```

Motivo do sucesso: Gemini **herda `$TMUX`** do processo pai (bash dentro do Claude Code dentro da sessão tmux do orquestrador) → MCP detecta contexto corretamente.

### ⚠️ Codex — MCP conecta mas tool falha

Comando: `codex exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox "..."`.

Log do Codex:
```
mcp: i9-team/team_list_agents started
mcp: i9-team/team_list_agents (completed)
codex
Erro: não foi possível detectar a sessão tmux atual.
```

Ou seja: o stdio handshake com a MCP funciona (inicia e completa). O problema é que a MCP i9-team retornou erro porque **não consegue detectar a sessão tmux** — o sandbox do Codex isola env vars do processo filho.

Mesmo passando `I9_TEAM_SESSION`, `I9_PROJECT`, `I9_TEAM`, `I9_AGENT` na shell env, o sandbox remove antes do MCP enxergar.

### Significado arquitetural

Isso **valida empiricamente** o item técnico #2 do doc principal: a MCP precisa aceitar identidade do chamador via env vars **explícitas injetadas pela config do cliente** (via `--env` do `codex mcp add` ou `-e` do `gemini mcp add`), não via herança de shell.

Implementação futura na MCP:
```typescript
function resolveCallerIdentity() {
  // 1ª prioridade: env vars explícitas injetadas pelo cliente
  if (process.env.MCP_AGENT_NAME && process.env.MCP_PROJECT) {
    return { /* ... */ };
  }
  // 2ª prioridade: heurísticas de tmux (como hoje)
  // 3ª prioridade: CWD, parent process, etc
}
```

E no `codex mcp add`:
```bash
codex mcp add i9-team \
  --env MCP_CLIENT_ID=codex \
  --env MCP_AGENT_NAME=team-dev-service \
  --env MCP_PROJECT=i9-team \
  --env MCP_TEAM=dev \
  -- /path/to/node /path/to/mcp/dist/index.js
```

## Tabela de compatibilidade atualizada

| Cliente | Auth | MCP config | MCP list | Invoke tool | Detecta tmux |
|---|---|---|---|---|---|
| Claude Code | ✅ | ✅ | ✅ | ✅ | ✅ (nativo) |
| Gemini CLI | ✅ OAuth Google | ✅ | ❌ Q1 | ✅ | ✅ (herda `$TMUX`) |
| Codex CLI | ✅ OAuth ChatGPT | ✅ | ✅ | ⚠️ MCP inicia, tool falha | ❌ Q5 (sandbox) |

## Quirks completos catalogados

| ID | Descrição | Cliente | Severidade |
|---|---|---|---|
| Q1 | `gemini mcp list` retorna exit 0 com stdout vazio | Gemini | Baixa |
| Q2 | Gemini pede "Trust folder" na 1ª exec do dir (TTY obrigatório) | Gemini | Média |
| Q3 | Config Codex em TOML (diferente dos outros em JSON) | Codex | Baixa |
| Q4 | Codex exige git repo por default (flag pra bypass) | Codex | Baixa |
| Q5 | Codex sandbox **isola env vars** mesmo com bypass | Codex | **Alta** |
| Q6 | `codex mcp list` mascara env com `*****` (feature, não bug) | Codex | (positivo) |
| Q7 | Codex tem `mcp-server` — pode expor Codex como MCP pra outros clientes | Codex | Interessante |
| R11 | Gemini polui output com `[WARN]` de dirs sem permissão | Gemini | Baixa |

## Conclusões e próximos passos

### Gemini já está pronto pra Fase 1
- **Funciona sem alterar a MCP**
- Pode virar cobaia em um agente cobaia (ex: `team-dev-service`)
- Economia imediata: agentes técnicos migram pra Gemini, Claude continua só nos orquestradores

### Codex precisa da adaptação da MCP antes
- Cobaia perfeita do **item técnico #2** (env vars de identidade)
- Depois dessa adaptação, entra Fase 1 também

### Skill `/auth-cli` — design pronto pra implementar
Os 3 fluxos OAuth estão mapeados:

| CLI | Comando | Arquivo de credencial | Mecanismo |
|---|---|---|---|
| Claude | `claude /login` (TUI) | `~/.claude/.credentials.json` | Browser redirect |
| Gemini | `gemini` + TUI | `~/.gemini/oauth_creds.json` | URL OAuth manual → cola code |
| Codex | `codex login --device-auth` | `~/.codex/auth.json` | Device flow (URL + código) |

Todos seguem "OAuth sempre" (decisão do usuário). Skill pode ser implementada com 3 scripts bash + SKILL.md orquestrador.

## Decisões

- ✅ Gemini validado → pode avançar pra Fase 1
- ⏳ Codex depende de adaptação MCP (item #2) → entra Fase 1 depois
- ✅ Skill `/auth-cli` — design completo, aguardando decisão de implementação
