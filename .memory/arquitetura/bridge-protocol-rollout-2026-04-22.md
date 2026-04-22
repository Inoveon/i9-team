---
title: Bridge Protocol — Rollout 2026-04-22
tags:
  - arquitetura
  - mcp
  - bridge-protocol
  - rollout
  - concluido
status: aplicado-aguardando-reinicio
---
# Bridge Protocol — Rollout concluído

**Data:** 2026-04-22  
**Status:** ✅ Aplicado em 7 orquestradores (6 projetos)  
**Versão do bloco:** v1

## Resumo

Implementação completa do Bridge Protocol para comunicação cross-team entre orquestradores:

1. **MCP i9-team**: 4 tools novas (`team_bridge_send`, `team_bridge_check`, `team_bridge_discover`, `team_bridge_inbox`) + helpers em `config.ts`. Build OK em `/home/ubuntu/mcp-servers/i9-team/dist/`.
2. **Orquestradores**: bloco canônico `<!-- BRIDGE-PROTOCOL:BEGIN v1 -->...:END v1 -->` adicionado em todos, com frontmatter `description` atualizado e 2 novas regras absolutas.

## Arquivos atualizados

| # | Projeto | Team | Arquivo | Linhas |
|---|---------|------|---------|--------|
| 1 | i9-team | dev | `/home/ubuntu/projects/i9-team/.claude/agents/team-orchestrator.md` | 125 |
| 2 | i9-smart-pdv | dev | `/home/ubuntu/projects/i9-smart-pdv/.claude/agents/team-orchestrator.md` | 142 |
| 3 | proxmox-infrastructure | infra | `/home/ubuntu/projects/proxmox-infrastructure/.claude/agents/team-orchestrator.md` | 198 |
| 4 | mcp-servers | dev | `/home/ubuntu/mcp-servers/.claude/agents/team-orchestrator.md` | 125 |
| 5 | i9-service | dev | `/home/ubuntu/projects/i9-service/.claude/agents/team-orchestrator.md` | 149 |
| 6 | i9-issues | dev | `/home/ubuntu/projects/i9-issues/.claude/agents/team-orchestrator.md` | 174 |
| 7 | i9-issues | ops | `/home/ubuntu/projects/i9-issues/.claude/agents/team-ops-orchestrator.md` | 210 |

Todos os 7 validados: 1 marcador BEGIN e 1 marcador END v1.

## O que foi adicionado em cada arquivo

### 1) Frontmatter
Description incrementada com: *"Usa Bridge Protocol (team_bridge_*) pra comunicação cross-team com outros projetos."*

### 2) Bloco `BRIDGE-PROTOCOL:BEGIN v1` → `END v1`
Inserido entre "Mapeamento de responsabilidades" (ou equivalente) e "Regras absolutas".

Conteúdo:
- Tools MCP (tabela de referência)
- Header canônico `[BRIDGE from=... to=... corr=... kind=...]`
- Protocolo de envio (7 passos)
- Protocolo de resposta (3 passos)
- Regras do bridge (5 bullets)

### 3) Regras absolutas
Adicionados 2 itens:
- ❌ NUNCA usar `tmux send-keys` manual pra cross-team — use `team_bridge_send`
- ✅ SEMPRE usar `team_bridge_discover` antes de mandar bridge pra projeto externo

## Template reutilizável

Nota persistente: `arquitetura/bridge-protocol-template.md` no vault i9-agent-memory. Pra adicionar o bloco em orquestradores futuros, copiar o trecho entre os marcadores e aplicar as adições de description + regras.

## Próximos passos de validação

### Passo 1 — Reiniciar a sessão orquestrador atual (i9-team)
Hoje eu ainda rodo o MCP antigo (stdio carregado no startup). Pra usar as 4 tools novas preciso ser relançado.

```bash
# Matar sessão orquestrador atual
tmux kill-session -t i9-team-dev-orquestrador

# Relançar via team.sh ou similar
```

### Passo 2 — Teste end-to-end
Na nova sessão:
1. `team_bridge_discover` → listar tudo
2. `team_bridge_send` → mandar request trivial pro orquestrador PDV (ex: "teste do bridge, responde só com 'ok'")
3. Capturar `corr_id` retornado
4. Esperar uns segundos
5. `team_bridge_inbox(corr_id=<x>, kind="response")` → conferir resposta chegou

### Passo 3 — Aposentar o hack `tmux send-keys`
Depois de validado end-to-end, passar a usar exclusivamente as tools bridge. O protocolo atualizado já proíbe `tmux send-keys` pra cross-team.

## Riscos e mitigação

- **Reinício não-coordenado**: se algum orquestrador rodar com prompt antigo mas MCP novo, ele não sabe das tools bridge — mas **as tools funcionam mesmo assim** (é o MCP que expõe). Só o know-how de "como usar" que fica desatualizado até o próximo restart. Mitigação: esse rollout + reinício gradual.
- **Inbox com scrollback limite**: default tmux é 2000 linhas. Com `history-limit` de 50k no `.tmux.conf` temos capacidade folgada.
- **Colisão de corr_id**: UUID v4 — probabilidade astronomicamente baixa.

## Commits

Não commitei nada. Os 7 arquivos ficaram **modificados mas não staged**, pra revisão humana antes do commit.

Quando aprovar, pode rodar `/commit` em cada repo afetado (são 6 repos git diferentes).
