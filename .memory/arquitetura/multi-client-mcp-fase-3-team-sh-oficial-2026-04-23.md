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


---

## Validação ROI — RESULTADO

**Veredito**: ✅ **ROI-VALIDADO**

**Orquestrador i9-service::dev** coordenou a validação e respondeu via bridge (`corr_id f7405a54...`).

### Setup do teste

Tarefa idêntica delegada aos 4 agentes do i9-service/dev em paralelo via `team_send`:
> "Leia o primeiro arquivo .md do projeto (README preferencialmente). Responda em PT-BR com EXATAMENTE 2 linhas: (1) o que é o projeto, (2) principal tech stack."

### Resultados

| Agente | CLI | 2 linhas | Precisão técnica | Tool calls |
|---|---|---|---|---|
| team-dev-backend | Gemini | ✅ | ✅ NestJS+TypeORM+Postgres+React+Tailwind+Expo | 4 reads |
| team-dev-web | Gemini | ✅ | ✅ Completo (stack inteiro) | 1 folder + 2 reads (mais conciso) |
| team-dev-mobile | Gemini | ✅ | ⚠️ Omitiu PostgreSQL e Redis | 1 glob + 3 reads |
| team-dev-service | Claude | ✅ | ✅✅ Mais completa: versões PG15, Redis7, Docker Compose, submódulos | 2 files + 2 dirs + 1 search |

### Tempos

- Todos os 4 completaram em <50s
- Latência Gemini comparável a Claude pra essa classe de tarefa
- Tool calls mínimas nos Gemini (2-4) vs 5 no Claude (mas com mais riqueza)

### Análise

**Pontos fortes dos Gemini (3/3)**:
- Formato respeitado (2 linhas, marcadores)
- Tecnicamente corretos
- Mais ágeis em convergir resposta

**Ponto de atenção**:
- `team-dev-mobile` omitiu componentes de dados (PG, Redis) — gap de ~10% na completude
- Esperado: Gemini é ágil mas pode pular detalhes que Claude capturaria

**Ponto forte do Claude**:
- Entregou versões específicas (PG15, Redis7), identificou Docker Compose e arquitetura de submódulos
- Confirma princípio #1 — Claude pra análise arquitetural/profundidade

### Conclusão

> Migração dos 3 devs pra Gemini é **economicamente justificada** sem perda funcional relevante nessa classe de tarefa (leitura + resumo simples). Claude mantém vantagem em completude/profundidade — adequado pro service e orchestrator (que permanecem Claude).

### Mensagem para o backlog

- **Mobile agent em Gemini** pode se beneficiar de instrução explícita "liste TODOS os componentes do stack, incluindo dados e caches" no prompt-padrão — contorna o gap de completude observado
- **Fase 4 (futura)**: delegar tarefas mais complexas aos Gemini pra ver se a qualidade degrada ou mantém

### Fontes

- Bridge response `f7405a54-7471-4400-92a8-75eba1e58e0e` → `in_reply_to=a511bfee-8288-4b2f-bd14-b47630b186b3`
- Nota do próprio i9-service: `roi-validation-multiclient-2026-04-23`
