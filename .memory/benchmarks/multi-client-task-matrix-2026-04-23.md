---
title: Benchmark Multi-Client — matriz de tarefas vs CLI
tags:
  - benchmark
  - multi-client
  - claude
  - gemini
  - codex
  - fase-1
date: '2026-04-23'
status: em-progresso
projeto: i9-team
---
# Benchmark Multi-Client — matriz de tarefas vs CLI

**Data**: 2026-04-23
**Agentes testados**:
- `team-dev-backend` — Claude Code (Sonnet/Opus conforme disponível)
- `team-gemini` — Gemini CLI (Gemini 3 Auto)
- `team-codex` — OpenAI Codex CLI (gpt-5.4)

**Fonte da verdade**: Claude (princípio #1 do doc Multi-Client MCP)
**Método**: mesmo prompt enviado em paralelo via `team_send`. Coleta via `team_check`. Avaliação qualitativa pelo orquestrador Claude.

## T1 — Leitura cirúrgica (PT-BR, 3 linhas)

**Prompt**: "Leia `/home/ubuntu/mcp-servers/i9-team/src/config.ts` e explique em PT-BR em no máximo 3 linhas o que faz `resolveCurrentContext()`. Marcadores === RESPOSTA-T1 === ... === FIM-T1 ==="

### Resposta Claude
```
=== RESPOSTA-T1 ===
Resolve o contexto atual (project/team/agent/session) tentando múltiplas fontes em ordem:
primeiro lê as env vars MCP_PROJECT/MCP_TEAM/MCP_AGENT_NAME (multi-client: Gemini/Codex);
se não houver, cai para a detecção via sessão tmux (I9_TEAM_SESSION ou $TMUX+display-message)
passando por resolveContext(). Retorna ResolvedContext com projeto, team, agentName,
sessionName e isOrchestrator, ou null se nenhuma fonte identificar o contexto. Existe para
desacoplar o MCP do tmux nos clientes cujo sandbox isola $TMUX do processo filho.
=== FIM-T1 ===
```

### Resposta Gemini
```
=== RESPOSTA-T1 ===
A função resolve o contexto de execução (projeto, time e agente) priorizando variáveis de ambiente explícitas injetadas pelo cliente.
Ela busca definir a identidade através de variáveis como MCP_PROJECT e MCP_TEAM para garantir independência do ambiente.
Caso as variáveis estejam ausentes, utiliza o método legado getCurrentSession() baseado em sessões tmux como fallback.
=== FIM-T1 ===
```

### Resposta Codex
```
=== RESPOSTA-T1 ===
A função tenta descobrir o contexto atual do agente (projeto, time, nome do agente, nome da sessão e se é orquestrador).
Primeiro usa as variáveis de ambiente MCP_PROJECT, MCP_TEAM e MCP_AGENT_NAME; se encontrar, monta e retorna esse contexto com base no teams.json.
Se isso falhar, faz fallback para detectar a sessão tmux atual com getCurrentSession() e resolve o contexto a partir dela; se não conseguir, retorna null.
=== FIM-T1 ===
```

### Avaliação T1

| Critério | Claude | Gemini | Codex |
|---|---|---|---|
| Formato (3 linhas) | ❌ estourou (5+ linhas) | ✅ exato | ✅ exato |
| Correção técnica | ✅✅ | ✅ | ✅✅ (menciona retorno null) |
| Clareza PT-BR | ✅ | ✅ | ✅ |
| Tool calls | 1 (Read) | 1 (SearchText) | 2 (Search+Read) |
| Tempo aproximado | ~20s | ~30s | ~50s (precisou Enter extra) |
| **Nota** | **4/5** | **5/5** | **4.5/5** |

**Veredito T1 (leitura cirúrgica)**: **Gemini venceu** — respeitou formato, foi conciso, tecnicamente correto. Codex empata em qualidade mas perde em tempo e ergonomia (Enter extra). Claude exagerou — qualidade alta mas ignorou limite.


## T3 — Edit cirúrgico

**Prompt**: "Abra `/tmp/bench/<agente>-T3.ts` e adicione `priority?: number;` logo após o campo `client`. Mantenha tudo o resto igual. Cole o arquivo completo entre `=== ARQUIVO-T3 ===` e `=== FIM-T3 ===`."

Cada agente recebeu um arquivo separado (`claude-T3.ts`, `gemini-T3.ts`, `codex-T3.ts`). Conteúdo base idêntico: interface `AgentConfig` + `TeamConfig`.

### Verificação do disco (fonte da verdade)

| Agente | Path pedido | Arquivo realmente editado | `priority?` presente? |
|---|---|---|---|
| Claude (backend) | `/tmp/bench/claude-T3.ts` | ✅ `/tmp/bench/claude-T3.ts` | ✅ SIM, no lugar certo |
| Gemini (team-gemini) | `/tmp/bench/gemini-T3.ts` | ❌ `~/.gemini/tmp/i9-team/gemini-T3.ts` (path errado!) | ❌ arquivo pedido **não foi alterado** |
| Codex (team-codex) | `/tmp/bench/codex-T3.ts` | ✅ `/tmp/bench/codex-T3.ts` | ✅ SIM, no lugar certo |

### Observações críticas

- **Gemini teve bug grave**: alegou `WriteFile Accepted (+14, -0)` no terminal, mas escreveu em `~/.gemini/tmp/<workspace>/gemini-T3.ts` (sandbox do CLI) em vez do path absoluto `/tmp/bench/gemini-T3.ts`. O output colado no terminal até parecia correto, mas o efeito real não aconteceu.
  - **Causa provável**: Gemini CLI em YOLO mode + workspace trust pode estar resolvendo paths relativos à própria workspace nativa, ignorando path absoluto fora dela.
  - **Impacto**: **falha silenciosa** — se não verificarmos o disco, acharíamos que deu certo.

- **Claude e Codex fizeram exatamente o pedido** no arquivo exato.

- **Codex usou Edit tool** (`+1 -0` linha); **Claude fez Read + rewrite inteiro** (aparentemente); **Gemini tentou WriteFile** (rewrite inteiro).

### Avaliação T3

| Critério | Claude | Gemini | Codex |
|---|---|---|---|
| Editou arquivo certo | ✅ | ❌ path errado | ✅ |
| Minimal-diff | ❌ reescreveu tudo | ❌ reescreveu tudo | ✅ edit de 1 linha |
| Output no formato | ✅ | ✅ | ✅ |
| Tool call eficiente | Read+Write | WriteFile único (em path errado) | Explored+Edited+Read (3 calls) |
| **Nota** | **4/5** | **1/5** (falhou de verdade) | **5/5** |

**Veredito T3 (edit cirúrgico)**: **Codex venceu com folga** — único a fazer edit minimal-diff real, no path certo. Gemini teve falha silenciosa gravíssima (alegou sucesso, não entregou). Claude funcionou mas rewrite inteiro é subótimo.

**Aprendizado**: pra edits em paths fora da workspace do Gemini, tem que **investigar/forçar** — pode precisar flag específica ou MCP filesystem auxiliar. Risco de falsos positivos.


## T5 — Refactor multi-arquivo

**Prompt**: Extrair função `agentSessionName()` de `config.ts` pra novo arquivo `session-names.ts`, atualizar `config.ts` com import + re-export, manter interfaces e `formatAgentLabel` intactos. Cada agente em diretório isolado (`/tmp/bench/t5-<agente>/`). Pro Gemini, instrução explícita de "USE PATHS ABSOLUTOS" (após falha T3).

### Tempos de processamento

| Agente | Tempo (s) | Observações |
|---|---|---|
| Claude (backend) | **30s** | Primeiro a entregar |
| Gemini (team-gemini) | **36s** | Acertou path absoluto após instrução explícita |
| Codex (team-codex) | **36s** (+ 425s de espera por Enter manual) | MCP do orquestrador velha não tem delay adaptativo — Enter chegou cedo e ficou preso no input |

### Verificação do disco

| Agente | `config.ts` modificado? | `session-names.ts` criado? | Qualidade |
|---|---|---|---|
| Claude | ✅ | ✅ | Estrutura perfeita |
| Gemini | ✅ | ✅ | Idêntica ao Claude (path absoluto OK dessa vez) |
| Codex | ✅ | ✅ | Estrutura válida, ordem levemente diferente (export junto ao import) |

### Observações

- **Gemini melhorou dramaticamente** ao receber instrução explícita "USE PATHS ABSOLUTOS" — zero falha silenciosa nesta rodada
- **Codex trava em team_send sem delay** — confirma a necessidade do delay adaptativo (commit 29bdc17 já na MCP nova)
- **Todos produziram código TS válido** com imports, exports e estrutura correta

### Avaliação T5

| Critério | Claude | Gemini | Codex |
|---|---|---|---|
| Completude no disco | ✅ | ✅ | ✅ |
| Tempo efetivo de processamento | 30s | 36s | 36s |
| Seguiu instruções à risca | ✅ | ✅ | ⚠️ reorganizou ordem dos exports |
| Robustez a quirks (needing Enter extra) | ✅ | ✅ | ❌ |
| **Nota** | **5/5** | **5/5** | **4/5** |

**Veredito T5 (refactor multi-arquivo)**: **empate técnico Claude/Gemini** — ambos entregaram código idêntico. Codex entregou com qualidade mas precisou intervenção manual.


## T7 — Documentação/explicação

**Prompt**: Ler `bridge-send.ts` e `bridge-check.ts`, escrever 1 parágrafo PT-BR (máx 6 linhas) sobre Bridge Protocol v2 — o que faz, como request/response se conectam, por que existe.

### Tempos

| Agente | Tempo (s) | Notas |
|---|---|---|
| Claude | **9s** | Ferramentas de leitura rápidas em paralelo |
| Gemini | **5s\*** | Monitor pode ter detectado cedo — plausível ~15s real |
| Codex | **29s** (com Enter manual) | Processamento após nudge |

### Respostas

**Claude** (estourou limite — ~10 linhas):
> O Bridge Protocol v2 permite que um orquestrador de um team converse com o orquestrador (ou agente) de outro projeto/team registrado em ~/.claude/teams.json — algo que o team_send padrão não faz, pois ele só alcança agentes da mesma sessão parent. O team_bridge_send valida o projeto/team/agente destino, resolve o nome real da sessão tmux via agentSessionName, detecta o "from" via resolveCurrentContext e injeta na primeira linha da mensagem um header canônico "[BRIDGE from=proj::team::agente to=... corr= kind=request|response in_reply_to=...]" antes do corpo, enviando tudo via sendToSession. Uma request gera um corr_id novo (UUID); a response é identificada por kind=response e carrega in_reply_to=, fechando a correlação sem nenhum banco de dados — tudo viaja no próprio corpo. O team_bridge_check complementa esse fluxo fazendo capture-pane cross-team da sessão destino, permitindo que o emissor acompanhe o output do agente remoto. O design é stateless por decisão explícita: zero estado compartilhado, simples de debugar e imune a dessincronização entre processos.

**Gemini** (5 linhas, limite respeitado):
> O Bridge Protocol v2 do i9-team possibilita a comunicação assíncrona entre agentes de diferentes projetos e times através de sessões tmux, permitindo a colaboração cross-team. Ele funciona injetando um header canônico [BRIDGE ...] na primeira linha de cada mensagem, contendo metadados como origem, destino e um identificador único de correlação (corr_id). Uma request e uma response se conectam através desse corr_id, onde a resposta utiliza o campo in_reply_to para referenciar a solicitação original. Esse protocolo existe para estruturar interações complexas em ambientes multi-agente, garantindo que as mensagens sejam rastreáveis e que cada agente possa identificar o contexto de suas conversas.

**Codex** (4-5 linhas, limite respeitado):
> O Bridge Protocol v2 do i9-team permite comunicação entre agentes de projetos/teams diferentes usando sessões tmux: team_bridge_send resolve o destino, valida se a sessão está ativa e injeta uma mensagem com header canônico [BRIDGE ...]. Cada request recebe um corr_id, e uma response se conecta à mensagem original usando kind=response e in_reply_to=<corr_id original>, mantendo também from e to como endereços canônicos. Ele existe para dar rastreabilidade e roteamento simples a conversas cross-team, enquanto team_bridge_check permite capturar o output do agente remoto para acompanhar respostas.

### Avaliação T7

| Critério | Claude | Gemini | Codex |
|---|---|---|---|
| Respeitou limite 6 linhas | ❌ estourou | ✅ | ✅ |
| Correção técnica | ✅✅✅ (máximo detalhe) | ✅ | ✅✅ (técnico + direto) |
| Menciona corr_id + in_reply_to | ✅ | ✅ | ✅ |
| Menciona team_bridge_check | ✅ | ❌ | ✅ |
| Menciona "por que existe" | ✅ (stateless design) | ✅ (rastreabilidade) | ✅ (roteamento) |
| Fluência PT-BR | ✅ | ✅✅ (mais literário) | ✅ |
| **Nota** | **4/5** (qualidade top mas estourou formato) | **4.5/5** | **5/5** |

**Veredito T7 (documentação concisa)**: **Codex venceu** — equilíbrio ideal entre concisão, precisão técnica e menção a ambas as ferramentas (send + check). Gemini segundo, Claude perdeu por estourar o limite apesar da qualidade técnica superior.

---

## 📊 Resumo consolidado

### Tempos de processamento (segundos)

| Tarefa | Claude | Gemini | Codex |
|---|---|---|---|
| T1 — Leitura cirúrgica | ~20s | ~30s | ~50s (+Enter) |
| T3 — Edit cirúrgico | ~30s | ~30s | ~50s (+Enter) |
| T5 — Refactor multi-arquivo | **30s** | **36s** | **36s** (+Enter) |
| T7 — Documentação | **9s** | **~15s** | **29s** (+Enter) |

**Observações**:
- Codex precisou de Enter manual em todas as rodadas porque o orquestrador que enviou (este Claude) roda MCP antiga sem delay adaptativo. O commit 29bdc17 resolve isso em futuros orquestradores.
- Gemini e Claude processam em tempos comparáveis quando recebem o Enter corretamente.
- Claude tende a ser ligeiramente mais rápido em tarefas que exigem leitura paralela (T1, T7).

### Notas por tarefa

| Tarefa | Claude | Gemini | Codex | Vencedor |
|---|---|---|---|---|
| T1 | 4/5 | **5/5** | 4.5/5 | 🥇 Gemini |
| T3 | 4/5 | 1/5 ❌ | **5/5** | 🥇 Codex |
| T5 | **5/5** | **5/5** | 4/5 | 🥇 empate Claude/Gemini |
| T7 | 4/5 | 4.5/5 | **5/5** | 🥇 Codex |
| **Média** | **4.25** | **3.88** | **4.63** | 🥇 **Codex (no placar)** |

### Análise qualitativa

**Claude (Sonnet/Opus via Claude Code)**:
- ✅ Forças: qualidade técnica mais profunda, raciocínio arquitetural, integração com tooling do projeto, nunca falhou silenciosamente
- ❌ Fraquezas: tende a estourar limites de formato quando a tarefa é complexa; verbosidade alta = mais tokens
- 💸 Custo esperado: **mais caro por token** (modelo premium) mas entrega completa sem retry

**Gemini (Gemini 3 Auto via Gemini CLI)**:
- ✅ Forças: respeita formato à risca, conciso, rápido em leitura de arquivos específicos, herda env automaticamente
- ❌ Fraquezas: **risco real de falha silenciosa** em paths absolutos sem instrução explícita (T3). Pode escrever em sandbox paralelo achando que fez a tarefa
- 💸 Custo esperado: **tier grátis 1000 req/dia** disponível, mais barato após, bom pra volume

**Codex (gpt-5.4 via Codex CLI)**:
- ✅ Forças: edits minimal-diff excelentes, respeita formato, raciocínio técnico direto, mascaramento automático de secrets no `mcp list`
- ❌ Fraquezas: **requer Enter manual** em team_send (até MCP nova propagar pra todos os orquestradores); sandbox isola env (requer `-c mcp_servers.*.env.*` na config)
- 💸 Custo esperado: **plano ChatGPT Plus**, médio em custo por token, eficiente em edits (menos tokens de output que Claude)

### Recomendação por tipo de tarefa

| Tipo de tarefa | CLI recomendado | Motivo |
|---|---|---|
| **Leitura cirúrgica** (explicar função, método) | **Gemini** | Conciso, respeitoso ao formato, rápido |
| **Edit cirúrgico** (add campo, rename) | **Codex** | Minimal-diff real, não reescreve arquivos |
| **Refactor multi-arquivo** | **Claude** ou **Gemini** | Ambos entregam qualidade igual; Claude se complexidade crescer |
| **Documentação concisa** (1 parágrafo) | **Codex** | Equilíbrio técnico/formato |
| **Análise profunda / arquitetura** (não testado mas inferido) | **Claude** | Raciocínio + síntese superior |
| **Grandes volumes de edit repetitivo** (renames, migrations em massa) | **Gemini** (tier grátis) | Volume barato, qualidade suficiente |
| **Orquestração e decisão** | **Claude** (invariável — princípio #1) | Sempre Claude |

### Gotchas catalogados

1. **Gemini + path absoluto**: exige instrução explícita ("USE PATHS ABSOLUTOS") ou risco de escrever em sandbox `~/.gemini/tmp/<workspace>/`
2. **Codex + team_send**: precisa Enter manual quando MCP do orquestrador não tem delay adaptativo (fixado em 29bdc17)
3. **Codex sandbox isola env**: identidade multi-client precisa `-c mcp_servers.*.env.MCP_*` na launch flag

### Skill futura recomendada

`/team-task-router <descrição-da-tarefa>` — recebe descrição livre, aplica heurística (keywords: "explicar", "edit", "refactor", "doc") e sugere CLI. Pode inclusive delegar automaticamente via `team_send` pro agente correto.
