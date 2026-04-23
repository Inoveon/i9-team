---
title: Multi-Client MCP — Fase 1 (migração de clients) + i9-tools + skill auth
tags:
  - arquitetura
  - multi-client
  - fase-1
  - migracao
  - i9-tools
date: '2026-04-23'
status: concluído
---
# Multi-Client MCP — Fase 1 (migração) + i9-tools + skill auth

**Data**: 2026-04-23
**Doc principal**: [`i9-team/docs/MULTI-CLIENT-MCP.md`](file:///home/ubuntu/projects/i9-team/docs/MULTI-CLIENT-MCP.md)

## Princípio #8 adicionado

> **Agentes cobaia ficam só no i9-team/dev**
> `team-claude`, `team-gemini`, `team-codex` existem exclusivamente no `i9-team/dev` como laboratório.
> Em outros projetos, multi-cliente é feito trocando o campo `client` dos agentes existentes — sem novos agentes.
> Rollback é trivial (remover o campo `client` → volta pra Claude).

## Migração executada (lazy)

Mudanças em `~/.claude/teams.json`, efetivas no próximo `team-agent-boot.sh` de cada agente.

| Projeto / Team | Mudanças | Total agentes | Multi-cliente |
|---|---|---|---|
| i9-service/dev | backend, web, mobile → gemini-cli | 5 | 3 |
| i9-issues/dev | backend, frontend, service → gemini-cli | 4 | 3 |
| mcp-servers/dev | dev-mcp, dev-service → codex-cli | 3 | 2 |
| proxmox-infrastructure/infra | mantido claude (raciocínio infra) | 3 | 0 |
| i9-issues/ops | mantido claude (analistas) | 4 | 0 |
| i9-smart-pdv/dev | NÃO ALTERADO (pedido do usuário) | 3 | 0 |
| i9-team/dev | cobaia exclusivo (team-claude, team-gemini, team-codex) | 8 | 3 |

**Total migrado: 8 agentes** (em 3 projetos).

## Lógica da escolha do CLI por agente

| Perfil do agente | CLI sugerido | Por quê |
|---|---|---|
| Orquestrador | **Claude** (sempre) | Princípio #1 — fonte da verdade |
| Analista (issues/ops) | **Claude** | Raciocínio crítico, classificação, triagem |
| Infra/Ops Proxmox | **Claude** | Complexidade de rede, firewall, VMs |
| Backend CRUD | **Gemini** | Trabalho braçal, tier grátis, contexto grande |
| Frontend CRUD | **Gemini** | Idem |
| Mobile CRUD | **Gemini** | Idem |
| Service (supervisor de processos) | **Claude** | Decisões de supervisão |
| MCP servers (dev TypeScript) | **Codex** | Edits cirúrgicos minimal-diff |

## Entregas da sessão 2 (2026-04-23 AM)

### 1. Rename team-media-studio → i9-tools v0.2
- Git rename preservando histórico (`git mv`)
- Package rebrand: `i9-tools-mcp` v0.2.0
- Todas as tools anteriores renomeadas: prefixo `media_*` → `i9_tools_*`
- **Novas tools**:
  - `i9_tools_diagram_mermaid` — Mermaid SVG/PNG via Puppeteer + mermaid.js CDN
  - `i9_tools_deck` — Reveal.js → HTML/PDF (12 temas)
  - `i9_tools_web_fetch` — scraping com JS render
  - `i9_tools_web_screenshot` — screenshot de elementos/páginas
- **Total**: 9 tools
- **Commit**: `3eb0fc6` (mcp-servers)

### 2. Skill /team-auth-cli (global)
- Criada em `~/.claude/skills/team-auth-cli/`
- Scripts: `status.sh`, `auth-claude.sh`, `auth-gemini.sh`, `auth-codex.sh`, `revoke.sh`
- Status atual (validado): Claude ✅, Gemini ✅ (oauth-personal), Codex ✅
- OAuth sempre, nunca API keys

### 3. Benchmark Browser (Fase 2)
Tarefa B1: fetch de https://example.com extraindo H1 e primeiro parágrafo, todos via `i9_tools_web_fetch`.

| Agente | Sucesso | Tempo LLM | Tempo tool (Puppeteer) |
|---|---|---|---|
| team-claude | ✅ | ~10s (estimado) | 1575ms |
| team-gemini | ✅ | **6s** | 1586ms |
| team-codex | ✅ | 16s | 1574ms |

**Insight**: com MCP padronizada pros 3 CLIs, a performance browser é dominada pelo custo da tool (Puppeteer + network), não pelo modelo. Gemini foi o mais ágil em orquestrar a tool call.

**Payload idêntico** nos 3 (title "Example Domain", mesmo parágrafo, diferença de ms no time_ms da tool).

## Commits da sessão 2

| Repo | Commit | Conteúdo |
|---|---|---|
| mcp-servers | `3eb0fc6` | Rename i9-tools v0.2 + diagram + deck |
| mcp-servers | *(pendente)* | Adição web_fetch + web_screenshot |
| i9-team | *(pendente)* | Doc MULTI-CLIENT v0.5 + notas + princípio #8 |

## Próximos passos

- Commit final consolidando tudo
- Relatório final PDF e envio WhatsApp
- Fase 3 (futuro): validar performance real com delegação de task verdadeira aos agentes migrados (ex: `i9-service/dev/team-dev-backend` rodando em Gemini recebe uma feature real)
