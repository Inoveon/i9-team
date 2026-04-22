# Bridge Protocol — Template para Orquestradores

**Versão atual:** v2
**Histórico:** v1 (2026-04-22) → v2 (2026-04-22, mesmo dia) — removida tool `team_bridge_inbox` após teste E2E provar que não funciona quando destino é Claude Code ativo (texto consumido como input, não entra no scrollback do capture-pane).
**Uso:** bloco canônico pra inserir em todo arquivo `.claude/agents/team-orchestrator.md` de todo projeto no `~/.claude/teams.json`.

## Localização da inserção

Inserir **entre "Mapeamento de responsabilidades" e "Notas — Regra Inviolável"** de cada orquestrador.

Em "Regras absolutas", adicionar as duas novas linhas (ver fim do doc).

---

## BLOCO CANÔNICO v2 (copiar entre os marcadores)

<!-- BRIDGE-PROTOCOL:BEGIN v2 -->
## Bridge Protocol — Comunicação Cross-Team

Quando a demanda exige informação ou ação de **outro projeto/team** (registrado em `~/.claude/teams.json`), você **não tenta** resolver sozinho nem diz "não posso fazer". Use o Bridge Protocol.

### Tools MCP (`mcp__i9-team__team_bridge_*`)

| Tool | Uso |
|------|-----|
| `team_bridge_discover` | Lista todos os projetos/teams/agentes e marca quais sessões estão ativas. **Use sempre antes de enviar**. |
| `team_bridge_send(target_project, target_team, target_agent, message, corr_id?, in_reply_to?, reply_to?)` | Envia mensagem cross-team. Injeta header canônico `[BRIDGE ...]` na primeira linha automaticamente. |
| `team_bridge_check(target_project, target_team, target_agent, lines?)` | Captura output atual de outro orquestrador/agente (cross-team `capture-pane`). |

### Header canônico

Toda mensagem bridge começa com:

```
[BRIDGE from=<proj>::<team>::<agent> to=<proj>::<team>::<agent> corr=<uuid> kind=<request|response> in_reply_to=<uuid-opcional>]
<body da mensagem>
```

- `kind` é inferido automaticamente: tem `in_reply_to` → `response`; sem → `request`.
- `corr_id` é gerado pela tool se você não passar.
- `from` é detectado via sua sessão atual (pode sobrescrever com `reply_to`).
- Alias `team-orchestrator` e `orquestrador` resolvem pro orchestrator real do team destino.

### Protocolo de envio (você originando uma request)

```
1. team_bridge_discover                                       # confirma destino ativo
2. team_bridge_send(project, team, agent, message)            # envia request; GUARDE o corr_id retornado
3. (intervalo — aguardar o destino processar)
4. team_bridge_check(project, team, agent, 40)                # opcional — olhe o outro orquestrador trabalhando
5. A resposta chega no seu próprio chat via system-reminder, com header canônico e in_reply_to=<seu corr_id>
6. Consolidar o resultado, salvar em nota (team_note_write), reportar ao usuário
```

Se a resposta não chegar em tempo razoável, use `team_bridge_check` pra ver se o destino travou ou está processando — e decida se reenvia ou desiste.

### Protocolo de resposta (você recebeu uma request)

Quando chegar no seu terminal uma mensagem com header `[BRIDGE ... kind=request]`:

```
1. Processar a demanda como tarefa do seu team (team_send aos seus agentes)
2. Ao concluir, team_bridge_send de volta pro "from" com:
     - target_project/team/agent = valores do "from" recebido
     - in_reply_to = corr_id da request original
   A tool coloca kind=response automaticamente
3. Sempre responder — mesmo que seja "não posso atender porque X"
```

### Regras do Bridge

- ✅ **SEMPRE** `team_bridge_discover` antes de enviar pra projeto externo
- ✅ **SEMPRE** guardar o `corr_id` retornado pra correlacionar a resposta
- ✅ **SEMPRE** responder um request recebido (inclusive negativa justificada)
- ❌ **NUNCA** usar `tmux send-keys` manual pra cross-team — use `team_bridge_send`
- ❌ **NUNCA** deixar uma request sem resposta (gera deadlock esperando)
<!-- BRIDGE-PROTOCOL:END v2 -->

---

## ADIÇÕES em "Regras absolutas"

Adicionar ao final da lista:

```
- ❌ NUNCA usar tmux send-keys manual pra cross-team — use team_bridge_send
- ✅ SEMPRE usar team_bridge_discover antes de mandar bridge pra projeto externo
```

---

## Atualização no frontmatter `description`

Mencionar bridge protocol. Padrão sugerido (exemplo pro i9-team):

```yaml
description: Orquestrador do team i9-team Portal. Coordena backend, frontend e mobile via MCP i9-team (team_send/team_check). Usa Bridge Protocol (team_bridge_*) pra comunicação cross-team com outros projetos. NUNCA usa Agent tool.
```

---

## Projetos/Teams afetados (aplicar em todos)

| Projeto | Team | Arquivo do orquestrador |
|---------|------|-------------------------|
| i9-team | dev | `/home/ubuntu/projects/i9-team/.claude/agents/team-orchestrator.md` |
| i9-smart-pdv | dev | `/home/ubuntu/projects/i9-smart-pdv/.claude/agents/team-orchestrator.md` |
| proxmox-infrastructure | infra | `/home/ubuntu/projects/proxmox-infrastructure/.claude/agents/team-orchestrator.md` |
| mcp-servers | dev | `/home/ubuntu/mcp-servers/.claude/agents/team-orchestrator.md` |
| i9-service | dev | `/home/ubuntu/projects/i9-service/.claude/agents/team-orchestrator.md` |
| i9-issues | dev | `/home/ubuntu/projects/i9-issues/.claude/agents/team-orchestrator.md` |
| i9-issues | ops | `/home/ubuntu/projects/i9-issues/.claude/agents/team-ops-orchestrator.md` |

Total: **7 arquivos**.

---

## Changelog v1 → v2

**Removido:**
- Linha da tabela de tools: `team_bridge_inbox(lines?, corr_id?, kind?)`
- Passo 5 do protocolo de envio: `team_bridge_inbox(corr_id=<guardado>, kind="response")`
- Passo 6 "Se vazio, repetir 3-5 até receber ou decidir timeout"

**Adicionado:**
- Passo 5 novo: "A resposta chega no seu próprio chat via system-reminder, com header canônico e in_reply_to=<seu corr_id>"
- Nota de fallback: "Se a resposta não chegar em tempo razoável, use `team_bridge_check` pra ver se o destino travou ou está processando"

**Motivo:**
Teste E2E do Bridge v1 provou que `team_bridge_inbox` retorna `[]` mesmo com resposta presente quando o destino é Claude Code ativo. O texto injetado via `tmux send-keys` é consumido como input do usuário (aparece via `system-reminder` no chat) e não passa pelo scrollback que o `capture-pane` lê. No caso real (orquestrador-LLM ↔ orquestrador-LLM) o modelo vê a resposta no próprio chat com header completo e correlaciona pelo `corr_id` visualmente — polling programático não é necessário.
