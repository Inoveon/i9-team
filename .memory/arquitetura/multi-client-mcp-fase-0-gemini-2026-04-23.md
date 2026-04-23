---
title: 'Multi-Client MCP — Fase 0: Gemini CLI instalado'
tags:
  - arquitetura
  - multi-client
  - gemini
  - mcp
  - oauth
  - fase-0
date: '2026-04-23'
status: em-progresso
projeto: i9-team
autor: team-orchestrator
---
# Multi-Client MCP — Fase 0: Gemini CLI instalado e conectado

**Data**: 2026-04-23
**Fase**: 0 (Discovery)
**Documento principal**: [`i9-team/docs/MULTI-CLIENT-MCP.md`](file:///home/ubuntu/projects/i9-team/docs/MULTI-CLIENT-MCP.md)

## Resumo

Primeira ponta do plano multi-cliente entregue: Gemini CLI v0.39.0 instalado no servidor, autenticado via OAuth, e com as 3 MCPs da frota configuradas (`i9-team`, `i9-agent-memory`, `evolution-api`). Config espelha o `.mcp.json` do Claude, permitindo consumo paralelo do mesmo stdio server.

## Decisão estratégica do usuário

**OAuth sempre** — nenhum CLI usará API key. Todos via OAuth Google / Claude login / Codex OAuth (a descobrir). Motivo: uniformidade de gestão de identidade, sem chaves espalhadas.

## Estrutura técnica do Gemini CLI

- Binary: `/home/ubuntu/.nvm/versions/node/v24.15.0/bin/gemini`
- Config: `~/.gemini/settings.json`
- Credenciais: `~/.gemini/oauth_creds.json` (chmod 600 automático)
- Conta ativa: `~/.gemini/google_accounts.json`
- Sub-comandos nativos: `gemini mcp`, `gemini skills`, `gemini hooks`, `gemini extensions` — arquitetura **simétrica** ao Claude Code

## Fluxo de autenticação OAuth em servidor headless

Registrado pra reprodução em outros servidores ou na skill `/auth-cli`:

1. Criar sessão tmux temp: `tmux new-session -d -s gemini-auth`
2. Disparar `gemini`
3. Responder modais:
   - "Trust folder" → Enter (opção 1: Trust folder)
   - "Auth method" → Enter (opção 1: Sign in with Google)
4. CLI imprime URL OAuth com `client_id=681255809395-oo8ft2oprdrnp9e3aqf6av3hmdib135j.apps.googleusercontent.com`
5. Usuário abre URL no browser da máquina dele, autoriza scopes (cloud-platform + userinfo)
6. Browser redireciona pra `codeassist.google.com/authcode?code=4/0...`
7. Colar o `code=...` no prompt "Enter the authorization code:"
8. CLI troca por token → salva `oauth_creds.json`
9. Validar: `gemini -p "ping"` retorna resposta

## Configuração de MCP pro Gemini

Comando padrão:

```bash
gemini mcp add --scope user --transport stdio \
  -e KEY1=value1 \
  -e KEY2=value2 \
  <nome> <comando> <arg1> <arg2>
```

Aplicado pras 3 MCPs da frota. O resultado em `~/.gemini/settings.json`:

```json
{
  "security": { "auth": { "selectedType": "oauth-personal" } },
  "mcpServers": {
    "i9-team": { "command": "...", "args": [...] },
    "i9-agent-memory": { "command": "...", "args": [...], "env": {...} },
    "evolution-api": { "command": "...", "args": [...], "env": {...} }
  }
}
```

A estrutura `mcpServers.*` é **idêntica** ao `.mcp.json` do Claude — o que simplifica um futuro script de sync.

## Quirks descobertos (catalogados)

| ID | Descrição | Severidade |
|---|---|---|
| Q1 | `gemini mcp list` retorna exit 0 mas stdout vazio — dificulta inspeção | Baixa (workaround: `jq` no settings) |
| Q2 | Gemini pede "Trust folder" na primeira execução por dir — exige TTY inicial | Média (automatizar via tmux) |

## Próximo passo natural

Instalar Codex CLI pra mapear seu fluxo de auth próprio antes de projetar a skill `/auth-cli` unificada. Com os 3 fluxos documentados (Claude, Gemini, Codex), a skill pode nascer cobrindo todos desde v1.

## Pendências desta fase

- [ ] Invocar tool real da MCP via Gemini headless (`team_list_agents` — validação funcional)
- [ ] Instalar Codex CLI + auth + configurar MCPs
- [ ] Documentar quirks do Codex
- [ ] Atualizar tabela de compatibilidade no doc principal
