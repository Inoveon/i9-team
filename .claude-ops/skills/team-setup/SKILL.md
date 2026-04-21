---
name: team-setup
description: Prepara um projeto Claude Code do zero para ter team de agentes funcionando via tmux. Orquestra MCPs, agentes, settings, CLAUDE.md, teams.json e validações. Inclui templates por tipo de projeto (dev-fullstack, dev-web, dev-mobile, pdv, service, infra, issues). Saída garantida: rodar `~/.claude/scripts/team.sh start <projeto> <team>` funciona. Invoque com /team-setup <projeto> [tipo] ou ao mencionar "configurar team", "preparar projeto pra team", "novo projeto com agentes", "team-setup", "criar team em".
user-invocable: true
---

# Team Setup — provisionamento completo de team em projetos

Aplique este procedimento quando precisar deixar um projeto **pronto pra rodar team de agentes**. É o entry-point que orquestra: MCPs + agentes + settings + CLAUDE.md + teams.json + validações.

---

## Sintaxe

```
/team-setup <projeto> [tipo]
```

Onde `[tipo]` ∈ `dev-fullstack | dev-web | dev-mobile | pdv | service | infra | issues`. Se omitido, perguntar ao user.

Se `<projeto>` omitido: usar cwd (`pwd`).

---

## Tipos de projeto

| Tipo | Agentes default | MCPs adicionais |
|------|-----------------|-----------------|
| `dev-fullstack` | orchestrator + backend + frontend + mobile + service | — |
| `dev-web` | orchestrator + backend + frontend + service | — |
| `dev-mobile` | orchestrator + mobile + backend + service | — |
| `pdv` | orchestrator + backend + frontend + mobile + service | i9-pdv, i9-cnpj, i9-dfe, i9-knowledge, i9-view |
| `service` | orchestrator + backend + web + mobile + service | i9-smartpass |
| `infra` | orchestrator + ops + analyst | — |
| `issues` | orchestrator + analyst-backend + analyst-frontend + analyst-mobile | — |

**Essenciais sempre** (em qualquer tipo): `i9-team`, `i9-agent-memory`, `evolution-api`.

---

## Fase 1 — Pré-requisitos

Validar e instruir instalação do que faltar:

```bash
# Comandos obrigatórios
for cmd in tmux jq node git docker; do
  command -v $cmd > /dev/null || echo "❌ FALTA: $cmd"
done

# Claude bin
CLAUDE_BIN=$(command -v claude || echo "$HOME/.nvm/versions/node/v24.15.0/bin/claude")
[ -x "$CLAUDE_BIN" ] || echo "❌ Claude bin não encontrado"

# team.sh
[ -x ~/.claude/scripts/team.sh ] || echo "❌ ~/.claude/scripts/team.sh não existe"

# repo mcp-servers
MCP_ROOT=""
for p in ~/mcp-servers /home/ubuntu/mcp-servers; do
  [ -d "$p" ] && MCP_ROOT="$p" && break
done
if [ -z "$MCP_ROOT" ]; then
  echo "❌ mcp-servers não clonado — rodando: git clone..."
  git clone git@github.com:Inoveon/mcp-servers.git ~/mcp-servers
  MCP_ROOT=~/mcp-servers
  for d in $MCP_ROOT/*/; do
    [ -f "$d/package.json" ] && (cd "$d" && npm install && npm run build)
  done
fi

# Postgres pra agent-memory
psql "postgresql://agent:agent123@localhost:5432/agent_memory" -c '\dt' >/dev/null 2>&1 \
  || echo "❌ Postgres pgvector não está pronto — ver troubleshooting"
```

---

## Fase 2 — MCPs do projeto

Reutiliza a skill `mcp-setup` (ou aplique inline):

1. Detectar `MCP_ROOT` (acima)
2. Pegar `PROJECT_NAME` = basename do path do projeto
3. Pegar `PROJECT_ROOT` = path absoluto do projeto
4. Gerar `.mcp.json` com **3 essenciais + adicionais por tipo** (ver tabela acima)
5. Criar `.memory/` (`mkdir -p $PROJECT_ROOT/.memory`)
6. Verificar `.gitignore`:
   - Se `.mcp.json` ignorado → criar `.mcp.json.example` versionável
   - Se não → versionar `.mcp.json` direto

Template completo na skill `mcp-setup` (consultar `~/.claude/skills/mcp-setup/SKILL.md`).

---

## Fase 3 — CLAUDE.md (se ausente)

Se `$PROJECT_ROOT/CLAUDE.md` não existir, criar com template:

```markdown
# {PROJECT_NAME}

{Descrição curta do projeto}

## Stack

- **Backend**: ...
- **Frontend**: ...
- **Mobile**: ...

## Memória

Usar `mcp__i9-agent-memory__*` para persistência entre sessões.
Buscar contexto antes de qualquer ação: `mcp__i9-agent-memory__search(query: "tema")`.

## context-mode — MANDATORY routing rules

Bash com output >20 linhas → usar ctx_execute ou ctx_batch_execute.
curl/wget → bloqueado, usar ctx_fetch_and_index.

## Padrões

- Português brasileiro em todas as respostas e comentários
- Commits apenas via `/commit` skill
- TypeScript strict em backend e frontend
- Dark mode obrigatório no frontend e mobile

## Portas

| Serviço  | Porta |
|----------|-------|
| Backend  | ?    |
| Frontend | ?    |
```

Perguntar ao user pra preencher stack/portas se quiser, ou deixar genérico.

---

## Fase 4 — Agentes

Criar `.claude/agents/` com um arquivo `.md` por agente do tipo escolhido.

### Template padrão de agente

```markdown
---
name: {agent-name}
description: {Função clara do agente em 1-2 frases. Use ao mencionar X, Y, Z}
model: sonnet
---

# {agent-name}

## Contexto

{Qual subsistema esse agente domina}

## Subdomínios

- {area 1}
- {area 2}

## Arquivos-chave

- `{path/relevante}` — descrição

## Padrões

- {padrão 1}
- {padrão 2}

## NUNCA fazer

- ❌ {antipattern 1}
- ❌ {antipattern 2}

## Persistent Agent Memory

Path: `{PROJECT_ROOT}/.claude/agent-memory/{agent-name}/MEMORY.md`

Atualizar MEMORY.md com decisões importantes, padrões aprendidos, edge cases.

## Regras de Git e Permissões

- Branch sempre prefixada: `fix/`, `feat/`, `chore/`, `refactor/`
- Commits via `/commit` skill
- NUNCA `git push --force` em main
- NUNCA `git reset --hard` sem confirmação
```

### Conteúdo específico por agente

**`team-orchestrator`** (presente em TODOS os tipos):
- Coordena os outros agentes via `team_send` / `team_check`
- NUNCA usa Agent tool — sempre `team_send`
- Reusa skill `team-protocol orchestrator`

**`team-dev-backend`**:
- Especialista no backend do projeto
- Conhece stack (Fastify/NestJS/Express/etc.)
- Implementa endpoints, schemas, testes

**`team-dev-frontend`** (web):
- Next.js / React / Vue conforme projeto
- Componentes, estado, integração API

**`team-dev-mobile`** (mobile):
- Flutter / React Native conforme projeto
- Telas, navegação, integração API

**`team-dev-service`** (sempre):
- Gerencia processos em background (postgres, backend, frontend)
- Usa tmux detached como process manager
- Faz health checks + restart on demand

**`team-ops-analyst-*`** (tipo issues):
- Análise crítica + auditoria
- Não implementa, só investiga e reporta

Sempre criar `.claude/agent-memory/{agent-name}/MEMORY.md` vazio com header inicial.

---

## Fase 5 — Settings

### `.claude/settings.json`

```json
{
  "permissions": {
    "allow": [
      "mcp__i9-team__*",
      "mcp__i9-agent-memory__*",
      "mcp__evolution-api__*",
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git push:*)",
      "Bash(git pull:*)",
      "Bash(npm run build:*)",
      "Bash(npm install:*)",
      "Bash(node:*)",
      "Bash(npx tsc:*)"
    ]
  }
}
```

Adicionar permissões dos MCPs específicos do tipo (ex.: `mcp__i9-pdv__*` em PDV).

### `.claude/settings.local.json`

```json
{
  "enabledMcpjsonServers": [
    "i9-team",
    "i9-agent-memory",
    "evolution-api"
  ]
}
```

Adicionar MCPs específicos no array conforme tipo.

---

## Fase 6 — `~/.claude/teams.json`

Adicionar/atualizar entry do projeto. **Antes de qualquer escrita**: backup + validação.

```bash
TEAMS_JSON=~/.claude/teams.json
cp "$TEAMS_JSON" "$TEAMS_JSON.bak.$(date +%s)"

# Verificar se projeto já existe
EXISTS=$(jq --arg p "$PROJECT_NAME" '.projects[] | select(.name == $p) | .name' "$TEAMS_JSON")

if [ -n "$EXISTS" ]; then
  echo "⚠️  Projeto '$PROJECT_NAME' já existe em teams.json. Atualizar?"
  # ... lógica de update via jq
else
  # Adicionar novo
  jq --arg p "$PROJECT_NAME" --arg root "$PROJECT_ROOT" --argjson agents '[...]' \
    '.projects += [{
       "name": $p,
       "root": $root,
       "teams": [{
         "name": "dev",
         "orchestrator": "team-orchestrator",
         "agents": $agents
       }]
     }]' "$TEAMS_JSON" > "$TEAMS_JSON.new"
  jq . "$TEAMS_JSON.new" >/dev/null && mv "$TEAMS_JSON.new" "$TEAMS_JSON"
fi
```

### Estrutura de agents no teams.json

```json
{
  "name": "team-orchestrator", "dir": "."
},
{
  "name": "team-dev-backend", "dir": "backend"
},
{
  "name": "team-dev-frontend", "dir": "frontend"
},
{
  "name": "team-dev-mobile", "dir": "mobile"
},
{
  "name": "team-dev-service", "dir": "."
}
```

`dir` = subdir do projeto onde o agente deve operar (relativo ao `root`).

---

## Fase 7 — Validação final

Confirmar tudo OK antes de declarar pronto:

```bash
echo "── Validação ──"

# JSON válidos
for f in .mcp.json .claude/settings.json .claude/settings.local.json; do
  [ -f "$PROJECT_ROOT/$f" ] && jq . "$PROJECT_ROOT/$f" >/dev/null \
    && echo "✅ $f válido" || echo "❌ $f inválido"
done

# Builds existem
for srv in $(jq -r '.mcpServers[] | .args[0]' "$PROJECT_ROOT/.mcp.json"); do
  [ -f "$srv" ] && echo "✅ $srv" || echo "❌ FALTA: $srv"
done

# Vault existe
[ -d "$PROJECT_ROOT/.memory" ] && echo "✅ .memory/" || echo "❌ FALTA .memory/"

# Agentes existem
for a in $(ls $PROJECT_ROOT/.claude/agents/*.md 2>/dev/null); do
  echo "✅ agente: $(basename $a .md)"
done

# Sessões tmux limpas (não pode ter conflito)
EXISTING=$(tmux ls 2>/dev/null | grep -c "^${PROJECT_NAME}-dev-")
[ "$EXISTING" -gt 0 ] && echo "⚠️  $EXISTING sessões antigas — rode: team.sh stop $PROJECT_NAME dev"

# teams.json contém o projeto
jq -r --arg p "$PROJECT_NAME" '.projects[] | select(.name == $p) | "✅ teams.json contém \(.name)"' \
  ~/.claude/teams.json
```

---

## Fase 8 — Boot opcional

Perguntar ao user:

> "Tudo configurado. Quer subir o team agora? (y/N)"

Se sim:
```bash
~/.claude/scripts/team.sh start "$PROJECT_NAME" dev
```

Aguardar ~30s, fazer `tmux ls | grep $PROJECT_NAME` pra confirmar que as sessões subiram.

---

## Saídas garantidas

Ao final da skill, o projeto tem:

1. ✅ `.mcp.json` (ou `.mcp.json.example`) com MCPs essenciais + extras do tipo
2. ✅ `.memory/` criado
3. ✅ `.claude/agents/*.md` populados
4. ✅ `.claude/agent-memory/*/MEMORY.md` inicializados
5. ✅ `.claude/settings.json` + `.claude/settings.local.json` válidos
6. ✅ `CLAUDE.md` (criado se ausente)
7. ✅ Entry no `~/.claude/teams.json`
8. ✅ (Opcional) team rodando em sessões tmux

---

## Modo dry-run

Se user pedir `/team-setup --dry-run <projeto> [tipo]`:
- Mostrar o que SERIA criado/modificado
- NÃO escrever arquivos
- NÃO mexer em `~/.claude/teams.json`
- Listar MCPs, agentes, paths, próximos comandos

Útil pra revisar antes de aplicar.

---

## Regras absolutas

- ❌ NUNCA sobrescrever agentes existentes sem confirmar com user
- ❌ NUNCA mexer em `~/.claude/teams.json` sem backup `.bak.<timestamp>`
- ❌ NUNCA criar agente sem inicializar `MEMORY.md`
- ❌ NUNCA pular validação JSON antes de salvar
- ❌ NUNCA assumir tipo do projeto — perguntar se não óbvio
- ❌ NUNCA criar MCP que não existe no repo (`github-stats` é exemplo de bug histórico)
- ✅ SEMPRE validar `jq .` em cada arquivo JSON tocado
- ✅ SEMPRE backup antes de mexer em arquivos compartilhados (teams.json)
- ✅ SEMPRE oferecer dry-run pra mudanças destrutivas
- ✅ SEMPRE avisar pra reiniciar sessão Claude após mudanças no `.mcp.json`
- ✅ SEMPRE avisar próximo comando ao final: `~/.claude/scripts/team.sh start <projeto> dev`

---

## Casos de uso comuns

### Caso 1 — Projeto novo zerado
User: "configurar team no projeto i9-novosistema"
→ Detecta tipo (perguntar), faz fases 1-8 todas

### Caso 2 — Projeto com `.mcp.json` mas sem agents
User: "preparar i9-existente pra ter team"
→ Detecta o que falta, pula fase 2, segue 3-8

### Caso 3 — Adicionar agente novo a team existente
User: "adicionar team-dev-data ao team do i9-team"
→ Pular pra fase 4 (criar só esse agente) + fase 6 (atualizar teams.json) + validação

### Caso 4 — Mudar tipo (ex.: dev-web → pdv)
User: "transformar i9-existente em PDV"
→ Re-rodar fase 2 (adicionar MCPs do PDV) + fase 5 (settings) + confirmar

---

## Skills relacionadas (orquestração)

- `mcp-setup` — sub-rotina pra fase 2
- `criar-agente` — sub-rotina pra fase 4 (cada agente)
- `team-protocol` — usado dentro de cada agente criado
- `team-launch` — sub-rotina pra fase 8 (boot)
- `team-watch` — após boot, monitorar progresso

---

## Referências

- Padrão MCP: vault `padrao-mcp-servers-projetos`
- Estratégia skills versionadas: vault `estrategia-skills-versionadas-projeto`
- Scripts orquestração: `~/.claude/scripts/{team.sh,team-boot.sh,remote-control-monitor.sh}`
- Repo MCPs: `~/mcp-servers` ou `/home/ubuntu/mcp-servers`
