---
title: Bridge Protocol v2 — Rollout 2026-04-22
tags:
  - arquitetura
  - bridge-protocol
  - i9-team
  - mcp
  - rollout
date: '2026-04-22'
status: concluído
projeto: i9-team
autor: team-orchestrator
---
# Bridge Protocol v2 — Rollout 2026-04-22

## Resumo executivo

Rollout v2 do Bridge Protocol concluído em **2026-04-22**. Sete sessões foram reiniciadas com a versão nova do MCP `i9-team`, consolidando a API cross-team em torno das três tools canônicas e removendo a tool legada `team_bridge_inbox`.

## Escopo do rollout

- **Sessões reiniciadas**: 7 sessões ativas (orquestradores e agentes) receberam o MCP atualizado
- **Data de execução**: 2026-04-22
- **Resultado**: Sucesso — todas as sessões operacionais com o novo contrato de tools

## Mudança de contrato — API Bridge

### Removido
- ❌ `team_bridge_inbox` — tool legada descontinuada
  - Motivo: duplicava função de `team_bridge_check` e introduzia estado paralelo à captura tmux
  - Impacto: qualquer agente/skill que dependia dessa tool precisa migrar para `team_bridge_check`

### Tools canônicas v2 (mantidas e recomendadas)

| Tool | Função |
|------|--------|
| `team_bridge_discover` | Lista projetos/teams/agentes registrados em `~/.claude/teams.json` e marca sessões ativas. Obrigatório antes de qualquer envio. |
| `team_bridge_send` | Envia mensagem cross-team com header canônico `[BRIDGE ...]` injetado automaticamente. Gera `corr_id` se omitido. Infere `kind=request|response` via presença de `in_reply_to`. |
| `team_bridge_check` | Captura output atual (cross-team `capture-pane`) de orquestrador/agente remoto. Usado para observar processamento sem bloquear. |

## Protocolo v2 — fluxos

### Originando uma request
1. `team_bridge_discover` — confirma destino ativo
2. `team_bridge_send(target_project, target_team, target_agent, message)` — guarda o `corr_id` retornado
3. (opcional) `team_bridge_check` — observa o destino processando
4. Resposta chega no chat via system-reminder com `in_reply_to=<corr_id>` original
5. Consolidar resultado, reportar ao usuário

### Respondendo a uma request recebida
1. Processar demanda como tarefa do próprio team (`team_send` aos agentes locais)
2. Ao concluir, `team_bridge_send` de volta pro `from` original com `in_reply_to=<corr_id da request>`
3. Sempre responder — inclusive negativa justificada — para evitar deadlock

## Header canônico

Primeira linha de toda mensagem bridge:

```
[BRIDGE from=<proj>::<team>::<agent> to=<proj>::<team>::<agent> corr=<uuid> kind=<request|response> in_reply_to=<uuid-opcional>]
<body>
```

- `from` detectado via sessão atual (override opcional com `reply_to`)
- Alias `team-orchestrator` e `orquestrador` resolvem pro orchestrator real do team destino
- `corr_id` é UUID gerado pela tool se não informado

## Regras pós-rollout

- ✅ **SEMPRE** `team_bridge_discover` antes de enviar pra projeto externo
- ✅ **SEMPRE** guardar `corr_id` pra correlacionar a resposta
- ✅ **SEMPRE** responder um request recebido
- ❌ **NUNCA** usar `tmux send-keys` manual pra cross-team
- ❌ **NUNCA** deixar request sem resposta (deadlock)
- ❌ **NUNCA** invocar `team_bridge_inbox` (removida)

## Arquivos/configs atualizados

- `.claude/agents/team-orchestrator.md` — bloco `BRIDGE-PROTOCOL:BEGIN v2` já reflete o contrato novo
- Todos os agentes team (backend, frontend, mobile, service) receberam a regra de notas via MCP

## Próximos passos

1. Monitorar primeiros ciclos cross-team reais pra validar comportamento em produção
2. Atualizar skills que ainda referenciem `team_bridge_inbox` (auditoria pendente)
3. Documentar padrão de correlação de `corr_id` em notas de projeto quando usado em fluxos complexos

## Referências

- Skill de protocolo: `/team-protocol orchestrator` / `/team-protocol agent`
- Frontmatter canônico do orquestrador: `.claude/agents/team-orchestrator.md` (bloco Bridge v2)
- Vault de memória compartilhada: `i9-agent-memory`


---

## Validação E2E — 2026-04-22 (pós-rollout)

### Auditoria de referências legadas

Auditoria completa rodada em `~/.claude/skills/`, `~/.claude/agents/`, `~/mcp-servers/`, `/home/ubuntu/projects/**` (excluído `node_modules`, `.git`, `dist`, caches e histórico):

- ✅ **Zero referências vivas** a `team_bridge_inbox` em código ou definição de agente
- ✅ **Zero referências vivas** em skills
- 📝 Únicas menções restantes: documentação histórica (rollout v1 e changelog do template) — legítimas e mantidas como trilha

### Teste E2E entre orquestradores

**Origem**: `i9-team::dev::orquestrador`
**Destino**: `i9-smart-pdv::dev::orquestrador`
**corr_id da request**: `7a25d97f-119c-44df-b71c-c475e2582178`
**corr_id da response**: `d965e648-7389-4192-9fc7-75df1206dd33`
**in_reply_to**: `7a25d97f-119c-44df-b71c-c475e2582178` ✅ correlação exata

**Conteúdo da resposta:**
1. ✅ Request recebida com header canônico completo (`from/to/corr/kind=request`)
2. ✅ `team_bridge_inbox` confirmadamente **ausente** da lista de tools do MCP `i9-team` no destino
3. 🔐 Selo `ok-v2` entregue

**Tools visíveis no destino após rollout** (`mcp__i9-team__*`):
`team_bridge_check`, `team_bridge_discover`, `team_bridge_send`, `team_check`, `team_detect_menu`, `team_list_agents`, `team_note_list`, `team_note_read`, `team_note_write`, `team_select_option`, `team_send`

**Observações técnicas confirmadas pelo destino:**
- Schema de `team_bridge_send` exposto apenas após `ToolSearch` (padrão deferred tool)
- Campos `in_reply_to` e `kind=response` injetados automaticamente pelo servidor MCP
- Roteamento funcional **sem** `tmux send-keys` manual

### Conclusão

Bridge Protocol v2 **operacional** em produção nos dois lados testados. Rollout fechado com validação E2E completa.
