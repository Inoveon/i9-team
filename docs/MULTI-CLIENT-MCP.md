# Multi-Client MCP — Arquitetura

> Documento **vivo**. Cada descoberta, decisão ou mudança entra no **Changelog** no fim e atualiza a seção relevante. Não reescrever — acrescentar.

**Status atual**: Fase 0 — Discovery (Gemini ✅ funcional; Codex ⚠️ MCP conecta mas detecção de contexto falha)
**Versão do doc**: 0.3
**Última atualização**: 2026-04-23

---

## Visão

Rodar **o mesmo conjunto de MCPs** (i9-team, i9-agent-memory, evolution-api, etc) em **múltiplos clientes de IA** (Claude Code, Gemini CLI, OpenAI Codex) simultaneamente, permitindo que cada agente de um team seja operado pelo cliente/modelo mais adequado à sua função — mantendo Claude como orquestrador invariável.

## Motivação

### Custo

Hoje **~60-70% dos tokens queimados** em uma sessão típica vão pra agentes fazendo:
- Leitura ampla de código (análise, reindexação mental do projeto)
- Edits repetitivos (refactor, migration, rename)
- Escrita de testes unitários
- Geração de seed data
- Análise de log/stack traces

Essas tarefas **não precisam do modelo mais premium** — um modelo de custo médio (Gemini 2.5 Pro, GPT-5 Codex, Claude Sonnet) entrega qualidade suficiente por **3-5× menos tokens**.

### Especialização

Cada cliente/modelo tem **pontos fortes reais**:

| Força | Cliente recomendado |
|---|---|
| Orquestração multi-agente, decisões, sínteses | Claude (Opus) |
| Contexto imenso (1M+ tokens), análise de codebase inteira | Gemini CLI (Gemini 2.5/3 Pro) |
| Refactors de código, testes, aderência rígida a convenções | OpenAI Codex |
| Geração de mídia (imagens, vídeo, 3D) | APIs diretas (Nano Banana, Imagen, Veo) — sem MCP |

### Disponibilidade

Gemini CLI tem tier gratuito generoso (1000 req/dia em 2026). Codex entra no plano ChatGPT Plus. Pode-se rodar agentes "descartáveis" em tier gratuito enquanto reserva Claude pra decisões críticas.

---

## Princípios invioláveis

Estes não mudam sem revisão formal (ADR):

1. **Claude é SEMPRE a fonte da verdade** — em qualquer conflito de estado, interpretação, decisão ou informação divergente entre clientes, o **orquestrador Claude é a autoridade canônica**. Notas, memórias, bridge, decisões arquiteturais, resultados consolidados: tudo passa pelo Claude como camada de validação/consolidação final. Gemini/Codex podem produzir, mas o Claude valida e versiona.
2. **Claude SEMPRE orquestra** — todos os 7 orquestradores da frota continuam sendo Claude Code. Ninguém mais faz `team_send` / `team_bridge_send`. Agentes apenas respondem localmente.
3. **Uma MCP única e compartilhada** — o mesmo stdio server do MCP i9-team (e demais) serve todos os clientes. Não forkar nem duplicar.
4. **Um CLI por pane tmux** — cada sessão tmux de agente roda **exclusivamente** um CLI (Claude OU Gemini OU Codex). Não alternar dentro do mesmo pane — vira caos de histórico e contexto.
5. **Identidade via env vars, não parent process** — quando o MCP precisa saber "quem me chamou", lê de `MCP_CLIENT_ID`, `MCP_AGENT_NAME`, etc. Injetar via config do cliente. Heurísticas (parent process, CWD) ficam só como fallback.
6. **Bridge Protocol permanece Claude-to-Claude** — a borda cross-team é sempre entre orquestradores. Agentes Gemini/Codex não atravessam bridge.
7. **Migração gradual** — 1 agente cobaia por vez. Medir ROI antes de escalar.

### Consequências práticas do princípio #1

- **Notas consolidadas no vault** `i9-agent-memory` (notas com path `arquitetura/`, `decisoes/`, etc) são escritas/revisadas exclusivamente pelo orquestrador Claude. Agentes Gemini/Codex podem salvar notas de domínio próprio (`agent-memory/<agente>-*`), mas **a síntese cross-agente é do Claude**.
- **Relatórios finais ao usuário** passam sempre pelo orquestrador Claude — mesmo quando o trabalho foi feito por agente de outro CLI.
- **Decisões de arquitetura / ADRs** são registradas apenas pelo Claude. Gemini/Codex podem propor, o Claude decide e documenta.
- **Em disputa de versão de fato** (ex: "Prisma é 6 ou 7?"), a fonte da verdade é a nota escrita ou validada pelo Claude, não a memória do agente técnico.

---

## Tabela de compatibilidade dos clientes

> Reavaliar a cada 3 meses — mercado MCP evolui rápido.

| Cliente | MCP | Transport | Config file | Status (2026-04) |
|---|---|---|---|---|
| Claude Code (CLI) | ✅ Nativo, maduro | stdio + SSE + HTTP | `~/.mcp.json` + `.mcp.json` do projeto | Produção desde 2024 |
| Claude Desktop | ✅ Nativo | stdio | `~/Library/Application Support/Claude/claude_desktop_config.json` | Produção |
| Anthropic SDK (lib) | ✅ via `MCPClient` | stdio + SSE | Programático | Produção |
| Gemini CLI (oficial) | ⚠️ Suporta com quirks | stdio | `~/.gemini/settings.json` | GA — alguns bugs conhecidos com servidores TS/Node |
| OpenAI Codex CLI | ⚠️ Experimental | stdio | `~/.codex/config.toml` (`[mcp_servers]`) | Beta |
| GitHub Copilot CLI | ❌ Não suporta | — | — | Protocolo próprio; usar via API pra multimídia |
| Cursor (IDE) | ✅ Nativo | stdio | `~/.cursor/mcp.json` + projeto | Produção |
| Windsurf (IDE) | ✅ Nativo | stdio | `~/.codeium/windsurf/mcp_config.json` | Produção |
| Cline (VS Code ext) | ✅ Nativo | stdio | Settings UI do VS Code | Produção |

---

## Arquitetura target

```
┌───────────────────────────────────────────────────────────────────┐
│                      FROTA — 7 ORQUESTRADORES                      │
│                      TODOS Claude Code (Opus)                      │
│                                                                     │
│  cs-i9-team-dev-team-orchestrator                                  │
│  cs-i9-smart-pdv-dev-team-orchestrator                             │
│  cs-i9-service-dev-team-orchestrator                               │
│  cs-i9-issues-dev-team-orchestrator                                │
│  cs-i9-issues-ops-team-ops-orchestrator                            │
│  cs-mcp-servers-dev-team-orchestrator                              │
│  cs-proxmox-infrastructure-infra-team-orchestrator                 │
│                                                                     │
│  Responsabilidade: alto nível, bridge, sínteses, decisão           │
│  Bridge Protocol v2 entre eles                                     │
└───────────┬───────────────────────────────────────────────────────┘
            │ team_send (tmux send-keys, cliente-agnóstico)
            ▼
┌───────────────────────────────────────────────────────────────────┐
│                  AGENTES — MIX DE CLIENTES                         │
│                                                                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐│
│  │  Claude Sonnet   │  │   Gemini CLI     │  │   Codex CLI      ││
│  │  (ou Opus p/     │  │   (2.5/3 Pro)    │  │   (GPT-5 Codex)  ││
│  │   raciocínio     │  │                  │  │                  ││
│  │   cirúrgico)     │  │  Leitura ampla,  │  │  Refactors,      ││
│  │                  │  │  análise de      │  │  testes, adesão  ││
│  │  UI crítica,     │  │  codebase,       │  │  a convenções    ││
│  │  arquitetura,    │  │  scripts de bash │  │  estritas        ││
│  │  debugging fino  │  │  pesados, seeds  │  │                  ││
│  └──────────────────┘  └──────────────────┘  └──────────────────┘│
│                                                                     │
│  Todos consomem a MESMA MCP i9-team via stdio                      │
└───────────────────────────────────────────────────────────────────┘
            │
            ▼
┌───────────────────────────────────────────────────────────────────┐
│        MCP SERVERS (únicos, compartilhados entre clientes)         │
│                                                                     │
│   i9-team    i9-agent-memory    evolution-api    outros...         │
│                                                                     │
│   Cada tool funciona idêntica independente do cliente chamador     │
│   Identidade do chamador via env MCP_CLIENT_ID / MCP_AGENT_NAME    │
└───────────────────────────────────────────────────────────────────┘
```

### Geração de mídia (fora do MCP)

Imagens, vídeos, assets 3D: **não** via MCP. Chamada direta:
- Gemini 3 Pro / Nano Banana — imagens
- Imagen 4 — imagens fotorealistas
- Veo 3 — vídeos
- Stable Video Diffusion — alternativa
- Copilot (API) — multimodal misto

Essas APIs têm SDKs HTTP simples. MCP seria overhead desnecessário.

---

## Plano em fases

### Fase 0 — Discovery (atual)

**Objetivo**: instalar os CLIs, descobrir como cada um consome MCP na prática, documentar surpresas.

**Entregas**:
- [x] Documento de arquitetura criado (este)
- [x] Gemini CLI instalado no servidor (v0.39.0)
- [x] Auth OAuth configurado (`selectedType: oauth-personal` em `~/.gemini/settings.json`)
- [x] Config do Gemini apontando pras 3 MCPs via stdio (i9-team, i9-agent-memory, evolution-api)
- [x] Teste: `mcp__i9-team__team_list_agents` funcionando via Gemini ✅ **retornou lista real dos 5 agentes**
- [x] Codex CLI instalado (v0.123.0) + auth ChatGPT via device flow + MCPs configurados
- [x] Teste Codex: MCP conecta (log mostra `mcp: i9-team/team_list_agents started/completed`) mas tool retorna erro de detecção de contexto
- [x] Catálogo de quirks encontrados (Q1 a Q7 no Changelog)
- [ ] Investigar detecção de sessão tmux sob sandbox do Codex (requer alteração na MCP → item técnico #2)
- [ ] Projetar skill `/auth-cli` unificada cobrindo os 3 CLIs

**Critério de saída**: ✅ parcialmente alcançado — Gemini totalmente funcional; Codex precisa da adaptação da MCP (env vars explícitas via config do cliente) pra fechar 100%.

### Fase 1 — POC com 1 agente cobaia

**Objetivo**: rodar 1 agente real (provavelmente `team-dev-service`) no cliente novo por alguns dias, comparar métricas.

**Entregas**:
- [ ] Agente cobaia configurado no CLI novo (ex: Gemini)
- [ ] `team.sh` / `team-boot.sh` passam a entender campo novo `client` em `teams.json`
- [ ] Operação em paralelo por 3-7 dias
- [ ] Métricas coletadas: tokens/tarefa, taxa de sucesso, tempo médio, retrabalho
- [ ] Go/no-go pra Fase 2

**Critério de saída**: cobaia entregou ≥10 tarefas reais, e métricas de custo/qualidade estão documentadas.

### Fase 2 — `teams.json` com campo `client`

**Objetivo**: oficializar a escolha de cliente por agente no schema.

**Mudança de schema** (proposta):

```json
{
  "name": "team-dev-backend",
  "dir": "backend",
  "client": "claude-code",
  "model": "opus"
}
```

Valores válidos de `client`:
- `claude-code` (default, retrocompatível se omitido)
- `gemini-cli`
- `codex-cli`

**Entregas**:
- [ ] `teams.json` schema versionado (ex: `"version": "2"`)
- [ ] `team.sh` / `team-boot.sh` lançam o CLI correto por agente
- [ ] `remote-control-monitor.sh` reconhece rodapé dos 3 CLIs (cada um tem texto próprio)
- [ ] MCP servers descobrem a identidade do agente via env vars corretamente
- [ ] Documento de migração pra orquestradores legados

### Fase 3 — Adaptações na MCP

**Objetivo**: fechar os gaps descobertos nas fases 0-2. **Só entra aqui depois que os problemas estão mapeados** — não especular.

**Possíveis itens** (concretizar com base no Discovery):
- [ ] Auditoria de schemas das tools pra compliance estrito (Draft-07 core)
- [ ] Leitura de `MCP_CLIENT_ID` / `MCP_AGENT_NAME` / `MCP_PROJECT` / `MCP_TEAM` na resolução de identidade
- [ ] Script `mcp-sync-configs.sh` gerando `~/.mcp.json` + `~/.gemini/settings.json` + `~/.codex/config.toml` a partir de fonte única (ex: `~/.claude/mcp-sources.yaml`)
- [ ] Logging estruturado com `client_id` pra facilitar debug cross-client
- [ ] Testes E2E rodando as ~20 tools em cada cliente (CI)

### Fase 4 — Homologação e rollout

**Objetivo**: estender o modelo pra toda frota.

**Entregas**:
- [ ] Matriz de compatibilidade Claude × Gemini × Codex versionada
- [ ] Agentes migrados conforme adequação (maioria dos "trabalho braçal" vai pra Gemini/Codex)
- [ ] ROI documentado (economia real mensurada)
- [ ] Processo de "adicionar novo CLI" documentado pra futuro

---

## Trabalho técnico identificado (inventário)

Lista do que provavelmente precisa ser feito. Cada item ganha status conforme as fases avançam.

| # | Item | Complexidade | Status | Fase |
|---|---|---|---|---|
| 1 | Auditoria de schemas das tools do MCP i9-team pra compliance estrito | Média (~1-2h) | 🔲 Pendente | 3 |
| 2 | Leitura de env vars `MCP_CLIENT_ID`/`MCP_AGENT_NAME` na MCP | Baixa (~30min) | 🔲 Pendente | 3 |
| 3 | Script `mcp-sync-configs.sh` multi-cliente | Média (~2h) | 🔲 Pendente | 3 |
| 4 | Documentação setup Gemini/Codex em máquina nova | Baixa (~1h) | 🟡 Parcial (este doc) | 0-1 |
| 5 | Teste E2E cross-cliente (Claude orquestra → Gemini agente) | Média (~1h) | 🔲 Pendente | 1 |
| 6 | Campo `client` em `teams.json` + `team.sh`/`team-boot.sh` reconhecem | Alta (~3-4h) | 🔲 Pendente | 2 |
| 7 | Rodapé multi-CLI no `remote-control-monitor.sh` | Média (~1h) | 🔲 Pendente | 2 |
| 8 | CI rodando test suite MCP em cada cliente | Alta (~4-6h) | 🔲 Pendente | 3-4 |

---

## Riscos conhecidos

| # | Risco | Probabilidade | Mitigação |
|---|---|---|---|
| R1 | Gemini CLI tem bugs com servidores MCP em TypeScript/Node | Alta | Fallback: SSE/HTTP transport; issue tracking upstream |
| R2 | Qualidade variável: Gemini pode degradar em raciocínio longo | Média | Começar com agentes de tarefa previsível; medir antes de escalar |
| R3 | Debug cross-client difícil (culpa do MCP? cliente? agente?) | Alta | Logging estruturado com `client_id`, `tool_name`, `correlation_id` em todas as tools |
| R4 | Modais dos CLIs têm UIs diferentes (Claude: "1/2/3", Gemini: pode ser texto, Codex: outro) | Média | Ampliar `team_bridge_key` com mapeamento por cliente; testar cada UI |
| R5 | `tmux capture-pane` do monitor busca "Remote Control active" (específico do Claude) — quebra em Gemini/Codex | Alta | Fase 2: reescrever `classify_state` com padrões por cliente |
| R6 | Conflito de sessão tmux se 2 CLIs tentarem iniciar no mesmo pane | Média | Princípio 3 (1 CLI por pane); validar no `team-boot.sh` |
| R7 | Env vars injetadas pelo config do cliente podem não chegar à MCP filha | Baixa | Testar em Fase 0; usar `Environment=` do systemd como backup |
| R8 | Bridge Protocol pode falhar se orquestrador destino receber texto de CLI diferente | Baixa | Princípio 5 (bridge é Claude-to-Claude) já elimina |
| R9 | `gemini mcp list` não retorna output (exit 0, stdout vazio) — dificulta inspeção de estado | Baixa | Inspeção direta via `jq '.mcpServers' ~/.gemini/settings.json`; reportar upstream |
| R10 | Codex sandbox isola env vars do processo filho — MCP i9-team não detecta sessão tmux | Alta | Item técnico #2 (env vars `MCP_CLIENT_ID`/`MCP_AGENT_NAME` injetadas via config do cliente) resolve |
| R11 | Gemini polui output com `[WARN]` de dirs sem permissão (barulho em CWDs com restrições) | Baixa | Rodar o CLI de dentro de um CWD limpo (ex: raiz do projeto), não de `/tmp` |

---

## Backlog e decisões em aberto

### Decisões pendentes

- **D1**: Gemini primeiro ou Codex primeiro? (→ decidido: Gemini — MCP mais maduro, contexto maior, tier grátis generoso)
- **D2**: Máquina alvo do POC: servidor ou máquina local do Lee? → Servidor primeiro (já tem teams em pé; menos setup)
- **D3**: Agente cobaia da Fase 1? → Candidato: `team-dev-service` (tarefas operacionais, menos risco de alucinar)
- **D4**: Quando deprecar campo `client` vazio em `teams.json` (forçar explicitamente)? → Nunca — `claude-code` permanece default
- **D5**: Auth OAuth pra todos os CLIs (→ decidido pelo usuário: **OAuth sempre**, sem API keys)
- **D6**: Onde mora a skill `/auth-cli` — global `~/.claude/skills/` ou versionada em `i9-team`? → Minha sugestão: global (utilitário de ambiente) com doc versionada no repo

### Backlog priorizado

1. **Skill `/auth-cli`** (PRIORIDADE) — unifica auth dos 3 CLIs (Claude + Gemini + Codex). Ações: `status | claude | gemini | codex | all | reauth <cli> | revoke <cli>`. Scripts bash fazem o trabalho real; SKILL.md orquestra. Esperando instalação do Codex pra mapear fluxo dele antes de implementar.
2. Skill `/multi-cli-status` pra inspecionar qual CLI está ativo em cada pane tmux
3. Dashboard consolidado de tokens/custo por CLI/agente/dia
4. Fallback automático: se agente Gemini travar, orquestrador relança em Claude

---

## Referências externas

- [MCP Spec](https://spec.modelcontextprotocol.io/) — fonte da verdade do protocolo
- [Anthropic MCP docs](https://docs.anthropic.com/en/docs/agents-and-tools/mcp) — guia Claude
- [Gemini CLI MCP guide](https://ai.google.dev/gemini-api/docs/cli/mcp) — guia Gemini
- [OpenAI Codex CLI + MCP](https://platform.openai.com/docs/codex/mcp) — guia Codex
- Docs internas relacionadas:
  - [`REMOTE-CONTROL.md`](./REMOTE-CONTROL.md)
  - [`REMOTE-CONTROL-MONITOR.md`](./REMOTE-CONTROL-MONITOR.md)
  - [`TEAMS-SETUP.md`](./TEAMS-SETUP.md)

---

## Changelog

> Append-only. Novas descobertas no fim. Não editar entradas antigas — corrigir com nova linha datada.

### 2026-04-23 — v0.1 — Criação do documento

- Documento inicial criado como parte da decisão estratégica de adotar multi-cliente
- Fase 0 aberta
- Princípios invioláveis definidos (7 itens — com #1 "Claude é a fonte da verdade" explícito a pedido do usuário)
- Tabela de compatibilidade com snapshot de 2026-04
- Arquitetura target desenhada
- 8 itens de trabalho técnico inventariados
- 8 riscos mapeados
- Próximo passo: instalar Gemini CLI no servidor e testar consumo da MCP i9-team

### 2026-04-23 — v0.2 — Fase 0: Gemini CLI instalado e conectado

**Instalação**
- `npm install -g @google/gemini-cli` → versão **0.39.0**
- Binary: `/home/ubuntu/.nvm/versions/node/v24.15.0/bin/gemini`

**Estrutura do CLI descoberta**
- Sub-comandos: `gemini mcp`, `gemini skills`, `gemini hooks`, `gemini extensions`
- Transports MCP: **stdio, sse, http** (todos suportados)
- Modos de aprovação: `default | auto_edit | yolo | plan` (equivalente ao permissions do Claude Code)
- Config de MCP persiste em `~/.gemini/settings.json` (scope user) ou `.gemini/settings.json` (scope project)
- Flags relevantes: `--allowed-mcp-server-names` (whitelist), `--include-tools`/`--exclude-tools` (filtro por tool), `--trust` (bypass confirmação)

**Autenticação — OAuth (decidido "OAuth sempre")**
- Opções disponíveis: "Sign in with Google" (OAuth), "Use Gemini API Key", "Vertex AI"
- Fluxo OAuth em servidor sem browser:
  1. Disparar `gemini` em sessão tmux temporária (abre TUI)
  2. Responder modais: "Trust folder" (Enter) → selecionar "Sign in with Google" (Enter)
  3. CLI imprime URL de OAuth com `code_challenge`, `state`, `client_id`
  4. Usuário abre URL no browser, autoriza
  5. Browser redireciona pra `codeassist.google.com/authcode` com `?code=4/0...` na URL
  6. Colar o `code=...` no prompt "Enter the authorization code:" do CLI
  7. CLI troca código por token e salva em `~/.gemini/oauth_creds.json` (chmod 600 automático)
- Config gerada em `~/.gemini/settings.json`:
  ```json
  { "security": { "auth": { "selectedType": "oauth-personal" } } }
  ```
- Validação: `gemini -p "responda com PONG"` → **PONG** ✅

**MCPs configurados (scope user)**
- Comando: `gemini mcp add --scope user --transport stdio -e KEY=value <name> <cmd> <args>`
- Adicionados idênticos ao `.mcp.json` do Claude:
  - `i9-team` — sem env vars
  - `i9-agent-memory` — com `VAULT_NAME`, `VAULT_PATH`, `DATABASE_URL`
  - `evolution-api` — com `EVOLUTION_API_URL`, `EVOLUTION_API_KEY`, `EVOLUTION_DEFAULT_INSTANCE`, etc
- Resultado em `~/.gemini/settings.json` (chaves `mcpServers.*`) — estrutura **idêntica** ao `.mcp.json` do Claude Code

**Quirks descobertos**
- **Q1**: `gemini mcp list` retorna exit 0 mas **stdout vazio** — inspeção só via `jq '.mcpServers' ~/.gemini/settings.json` (R9 adicionado aos riscos)
- **Q2**: Gemini pede "Trust folder" na primeira execução por diretório (prompt interativo) — precisa ser aceito em tmux antes de qualquer uso headless no dir

**Arquivos criados em `~/.gemini/`**
```
settings.json          # config (auth + MCPs)
oauth_creds.json       # token OAuth (600)
google_accounts.json   # conta Google ativa
installation_id        # UUID da instalação
trustedFolders.json    # folders marcados como trust
state.json             # estado de sessão
projects.json          # map de project folders
history/               # histórico de prompts
tmp/                   # dir temporário
```

**Decisões tomadas**
- D5: OAuth sempre (sem API keys) — pelo usuário
- D6 (em aberto): skill de auth unificada global vs versionada no repo

**Pendente pra fechar Fase 0**
- Teste real de invocação de tool MCP via Gemini headless (`team_list_agents`)
- Instalação do Codex CLI + auth OAuth + MCPs
- Decidir design da skill `/auth-cli` e implementar

**Próximo passo**: instalar Codex CLI pra mapear fluxo de auth antes de projetar skill `/auth-cli`.

### 2026-04-23 — v0.3 — Fase 0: Codex CLI + validação funcional

**Codex CLI instalado**
- `npm install -g @openai/codex` → versão **0.123.0** (research preview)
- Binary: `/home/ubuntu/.nvm/versions/node/v24.15.0/bin/codex`

**Estrutura descoberta**
- Config em **TOML** (diferente de Claude/Gemini que usam JSON): `~/.codex/config.toml`
- Sub-comandos: `codex login`, `codex mcp`, `codex exec`, `codex mcp-server` (Codex **pode ser** MCP server pra outros clientes 🤯), `codex apply`, `codex cloud`, `codex sandbox`
- Flags importantes:
  - `--skip-git-repo-check` — Codex exige git repo por default (proteção)
  - `-s/--sandbox` — modo sandbox (default: isolado)
  - `--dangerously-bypass-approvals-and-sandbox` — bypass total (usar com cuidado)
  - `--device-auth` — OAuth device flow (essencial pra servidor headless)
- `codex mcp add <NAME> -- <COMMAND>...` (sintaxe com `--` como separador)
- `--env KEY=VALUE` pra env vars

**Autenticação — OAuth device flow via ChatGPT**
- Comando: `codex login --device-auth`
- Fluxo:
  1. CLI imprime URL `https://auth.openai.com/codex/device` + código de 8 chars (ex: `XQ4G-ZT2V5`)
  2. Usuário abre URL no browser, loga com conta ChatGPT/OpenAI
  3. Cola o código na página, autoriza
  4. CLI (fazendo polling) detecta sozinho, salva token em `~/.codex/auth.json` (chmod 600)
  5. `codex login status` → `Logged in using ChatGPT`
- Tempo de expiração do código: **15 minutos**

**MCPs configurados**
- Comando: `codex mcp add <name> --env K=V -- <cmd> <arg>`
- Adicionadas as 3 MCPs idênticas ao Claude
- `codex mcp list` **FUNCIONA** (diferente do Gemini) — tabela com colunas Name, Command, Args, Env, Cwd, Status, Auth
- Env vars **mascaradas com `*****`** no list — melhor segurança que os outros
- Coluna **Auth** indica "Unsupported" pros nossos MCPs (mas Codex suporta `codex mcp login <server>` pra MCPs que expõem auth próprio — recurso novo!)
- Config gerada em `~/.codex/config.toml`:
  ```toml
  [mcp_servers.i9-team]
  command = "..."
  args = [...]
  
  [mcp_servers.i9-agent-memory]
  command = "..."
  [mcp_servers.i9-agent-memory.env]
  VAULT_NAME = "..."
  ```

**Validação funcional — invocação de tool MCP**

| Teste | Cliente | CWD | Resultado |
|---|---|---|---|
| 1 | Codex (`--dangerously-bypass-approvals-and-sandbox`) | `/tmp` | MCP inicia ✅, tool retorna erro "não foi possível detectar sessão tmux" ❌ |
| 2 | Codex + env vars I9_TEAM_SESSION/I9_PROJECT/I9_TEAM/I9_AGENT | `/tmp` | "tool não disponível" ⚠️ — possível cache de sessão |
| 3 | Gemini (`--yolo`) | `/tmp` | ✅ **Retornou lista real dos 5 agentes do team i9-team/dev** |

**Diagnóstico**:
- Gemini **herda `$TMUX`** do processo pai e a MCP consegue detectar a sessão tmux do Claude Code
- Codex **isola env** mesmo com bypass de sandbox → MCP não detecta contexto → tool rejeita
- Isso é exatamente o cenário que o **item técnico #2** previa: MCP precisa aceitar identidade via env vars explícitas do cliente, não só heurísticas de tmux

**Quirks descobertos (Q3–Q7)**
- **Q3**: Config Codex em **TOML** (exige parser diferente de JSON dos outros)
- **Q4**: Codex exige git repo por padrão — precisa `--skip-git-repo-check` em CWDs livres
- **Q5**: Codex sandbox **isola env vars** — MCP não vê `$TMUX`, `$I9_*`, etc mesmo com bypass
- **Q6**: `codex mcp list` mascaram env values com `*****` (feature boa, não bug)
- **Q7**: Codex CLI tem `codex mcp-server` — pode expor o próprio Codex como MCP server pra outros clientes (tema pra explorar)

**Tabela de compatibilidade atualizada**

| Cliente | Auth | MCP config | MCP list | Invoke tool | Detecta tmux |
|---|---|---|---|---|---|
| Claude Code | ✅ | ✅ | ✅ | ✅ | ✅ (nativo) |
| Gemini CLI | ✅ OAuth Google | ✅ | ❌ Q1 | ✅ | ✅ (herda $TMUX) |
| Codex CLI | ✅ OAuth ChatGPT | ✅ | ✅ | ⚠️ MCP inicia mas tool falha | ❌ Q5 (sandbox isola env) |

**Decisões tomadas**
- Gemini já pode ir pra Fase 1 (POC) **sem alterar MCP**
- Codex precisa da adaptação do item técnico #2 antes de virar agente útil — **essa é a cobaia perfeita do item #2**
- Skill `/auth-cli` tem os 3 fluxos mapeados agora — design pode ser finalizado

**Próximo passo**: atualizar a tabela de compatibilidade no topo do doc (seção "Compatibilidade") e projetar a skill `/auth-cli` com os 3 fluxos documentados.
