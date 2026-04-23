# Atualização do Ambiente Local — Prompt pro Claude Code

> **Como usar**: copie TUDO a partir da linha marcada `===PROMPT-BEGIN===` até `===PROMPT-END===` e cole como mensagem no Claude Code da sua **máquina local**. Claude vai atualizar o ambiente automaticamente pra refletir o estado do servidor Inoveon após a sessão de 2026-04-23.

**Contexto do que foi feito no servidor** (já commitado e pushado):

- `i9-tools` MCP cresceu de 5 → 36 tools (antes se chamava `team-media-studio`)
- `team.sh` oficial agora respeita campo `client` em `teams.json` (suporta Gemini/Codex)
- Novas skills globais: `/team-auth-cli`, `/team-task-router`, `/team-protocol` atualizado
- Monitor `/remote-control` com detecção de menu aberto + WhatsApp desligado
- Guia único de tokens em `docs/i9-tools-TOKENS.md`

---

===PROMPT-BEGIN===

# Atualize meu ambiente local com as melhorias Inoveon (sessão 2026-04-23)

Você é o Claude Code rodando na **máquina local do Lee**. Sua tarefa é sincronizar este ambiente com as evoluções que foram feitas no servidor Inoveon durante a sessão de 2026-04-23. Os repos já foram `git pull`. Agora você precisa atualizar: MCPs, skills, scripts e configs.

## Contexto que você precisa saber

- O MCP `team-media-studio` foi **renomeado pra `i9-tools`** (mesmo código, nome novo) e cresceu pra 36 tools
- Há 4 skills novas/atualizadas em `~/.claude/skills/` (team-auth-cli, team-task-router, team-protocol, team-watch)
- O `~/.claude/scripts/team.sh` foi alterado pra suportar campo `client` em `teams.json`
- Um novo script `~/.claude/scripts/team-agent-boot.sh` foi criado (boot individual de agentes multi-CLI)
- Há um guia consolidado em `docs/i9-tools-TOKENS.md` pra credenciais opcionais

## Pré-requisitos que você deve validar

```bash
for cmd in node npm git jq tmux gh; do
  command -v "$cmd" >/dev/null && echo "OK: $cmd" || echo "MISSING: $cmd"
done
[ -f ~/.claude/teams.json ] && echo "OK: teams.json" || echo "MISSING: teams.json"
[ -d ~/mcp-servers/i9-tools ] || [ -d ~/mcp-servers/team-media-studio ] && echo "OK: mcp-servers dir presente"
```

Se `MISSING: gh`, pode instalar depois — só é necessário pras tools de GitHub.

## Passo 1 — Confirmar que os pulls foram feitos

```bash
cd ~/mcp-servers && git log --oneline -5
cd ~/projects/i9-team && git log --oneline -5
```

Verifique que os últimos commits incluem:
- mcp-servers: `4644d91` (desativa Slack), `956db3f` (sprint 4), `eda2e2d` (image tools)
- i9-team: `18cd4d1` (tokens doc), `ae98306` (monitor fix), `ff89dd4` (multi-client v0.6)

Se não aparecerem, o pull ainda precisa ser feito:
```bash
cd ~/mcp-servers && git pull origin main
cd ~/projects/i9-team && git pull origin main
```

## Passo 2 — Se o diretório antigo `team-media-studio` existe, migrar pra `i9-tools`

```bash
cd ~/mcp-servers
if [ -d team-media-studio ] && [ ! -d i9-tools ]; then
  echo "Migração team-media-studio → i9-tools (git já tá ciente pelo pull)"
  # O git pull já fez o rename; se por algum motivo ficou o dir antigo, remove:
  [ -d team-media-studio ] && rm -rf team-media-studio
fi
ls -la i9-tools/
```

## Passo 3 — Rebuild do i9-tools

```bash
cd ~/mcp-servers/i9-tools
npm install  # instala @google/genai e outras deps novas
npm run build
```

Valide que compilou e conte as tools:
```bash
ls dist/tools/
grep -c 'server.tool(' dist/tools/*.js | awk -F: '{s+=$2} END {print "Tools:", s}'
```

Esperado: **36 tools** (se aparecer 37, inclui o slack.ts que tá no repo mas não é registrado).

## Passo 4 — Re-registrar MCP i9-tools nos CLIs

### Claude Code (edita `~/.mcp.json`)

Remove se existir `team-media-studio`, adiciona `i9-tools`:

```bash
jq 'del(.mcpServers."team-media-studio") | .mcpServers."i9-tools" = {
  "command": "'$(which node)'",
  "args": ["'$HOME'/mcp-servers/i9-tools/dist/index.js"]
}' ~/.mcp.json > /tmp/mcp.json && mv /tmp/mcp.json ~/.mcp.json
jq '.mcpServers | keys' ~/.mcp.json
```

### Gemini CLI (se instalado)

```bash
gemini mcp remove team-media-studio 2>/dev/null || true
gemini mcp add --scope user --transport stdio i9-tools \
  $(which node) $HOME/mcp-servers/i9-tools/dist/index.js
```

Se não tem Gemini CLI instalado: `npm install -g @google/gemini-cli` → `gemini` (OAuth Google)

### Codex CLI (se instalado)

```bash
codex mcp remove team-media-studio 2>/dev/null || true
codex mcp add i9-tools -- $(which node) $HOME/mcp-servers/i9-tools/dist/index.js
```

Se não tem Codex: `npm install -g @openai/codex` → `codex login --device-auth`

## Passo 5 — Atualizar skills globais

O servidor tem 3 skills novas/atualizadas em `~/.claude/skills/`. Busque elas no repo `i9-team` ou no servidor via rsync/scp. Se tiver acesso SSH ao servidor:

```bash
# Ajuste o hostname
SERVER=ubuntu-claude-agents  # ou IP do servidor Inoveon
rsync -av ubuntu@$SERVER:~/.claude/skills/team-auth-cli/ ~/.claude/skills/team-auth-cli/
rsync -av ubuntu@$SERVER:~/.claude/skills/team-task-router/ ~/.claude/skills/team-task-router/
rsync -av ubuntu@$SERVER:~/.claude/skills/team-protocol/SKILL.md ~/.claude/skills/team-protocol/SKILL.md
```

Se **não** tiver SSH pro servidor, clone do repo:
- `team-task-router` e `team-auth-cli` não estão versionados no repo i9-team (moram em `~/.claude/skills/`)
- Você pode pedir pro Claude do servidor empacotar elas via skill `/skill-pack` e enviar por WhatsApp/email

Ou criar manualmente a partir do `docs/i9-tools-TOKENS.md` (tem as instruções principais).

## Passo 6 — Atualizar scripts team.sh + team-agent-boot.sh

O servidor tem versão atualizada do `team.sh` (suporta multi-CLI) e um novo `team-agent-boot.sh`. Há cópia arquivada no repo:

```bash
cp ~/projects/i9-team/docs/multi-client-assets/team.sh.multi-client ~/.claude/scripts/team.sh
cp ~/projects/i9-team/docs/multi-client-assets/team-agent-boot.sh ~/.claude/scripts/team-agent-boot.sh
chmod +x ~/.claude/scripts/team.sh ~/.claude/scripts/team-agent-boot.sh

# Backup da versão antiga, se tinha:
ls -la ~/.claude/scripts/team.sh.bak* 2>/dev/null | tail -5
```

## Passo 7 — Criar estrutura `~/.i9-tools/`

Para quando for ativar as credenciais opcionais:

```bash
mkdir -p ~/.i9-tools
chmod 700 ~/.i9-tools
touch ~/.i9-tools/.env
chmod 600 ~/.i9-tools/.env

# Template do .env
cat > ~/.i9-tools/.env <<'EOF'
# i9-tools — secrets (chmod 600)
# Preencha conforme docs/i9-tools-TOKENS.md

# Geração de imagem (Gemini) — requer billing habilitado
# GEMINI_API_KEY=AIza...

# Upload S3 / Cloudflare R2
# AWS_ACCESS_KEY_ID=...
# AWS_SECRET_ACCESS_KEY=...
# AWS_REGION=sa-east-1
# AWS_S3_BUCKET=...
# AWS_S3_ENDPOINT=https://<accountid>.r2.cloudflarestorage.com  # apenas R2

# Google Drive / Sheets / Gmail
# GOOGLE_CLIENT_ID=...
# GOOGLE_CLIENT_SECRET=...
# GOOGLE_REFRESH_TOKEN=...
EOF
echo "✅ ~/.i9-tools/.env criado (vazio — preencher conforme precisar)"
```

## Passo 8 — (Opcional) Monitor de Remote Control local

Se você quer o monitor rodando na máquina local também:

```bash
# Requisitos: systemd (Linux), systemd-user no macOS via brew/launchd (macOS nativo)
# Guia completo em:
cat ~/projects/i9-team/docs/REMOTE-CONTROL-MONITOR.md | less

# Use prefixo diferente do servidor (ex: "mac" se é MacBook)
cat > ~/.claude/remote-control-monitor.env <<'EOF'
WHATSAPP_ENABLED=false
CLAUDE_ENV_PREFIX=mac  # ou: lin, wsl, etc
EOF
chmod 600 ~/.claude/remote-control-monitor.env
```

## Passo 9 — Validação final

Execute smoke test do i9-tools:

```bash
# Lista as tools registradas
node -e "
const { spawn } = require('child_process');
const mcp = spawn('$(which node)', ['$HOME/mcp-servers/i9-tools/dist/index.js']);
let buf='';
mcp.stdout.on('data', d => {
  buf += d;
  const lines = buf.split('\n'); buf = lines.pop();
  for (const l of lines) {
    try { const m = JSON.parse(l); if (m.id===1) { console.log('TOOLS:', m.result.tools.length); mcp.kill(); } } catch {}
  }
});
setTimeout(() => mcp.stdin.write(JSON.stringify({jsonrpc:'2.0',id:0,method:'initialize',params:{protocolVersion:'2024-11-05',capabilities:{},clientInfo:{name:'t',version:'1'}}})+'\n'), 200);
setTimeout(() => { mcp.stdin.write(JSON.stringify({jsonrpc:'2.0',method:'notifications/initialized'})+'\n'); setTimeout(()=>mcp.stdin.write(JSON.stringify({jsonrpc:'2.0',id:1,method:'tools/list'})+'\n'), 200); }, 700);
setTimeout(() => { console.error('timeout'); mcp.kill(); process.exit(1); }, 10000);
"
```

Esperado: `TOOLS: 36`

## Passo 10 — Reportar estado final

Me resuma em resposta:

```
✅ Ambiente atualizado — <hostname>

Repos sync:
- mcp-servers: HEAD = <commit>
- i9-team: HEAD = <commit>

MCPs registradas no Claude:
- <lista>

i9-tools:
- versão: 0.3.0
- tools: 36
- build: OK

Skills atualizadas: <lista>

~/.i9-tools/.env: criado (vazio, aguarda credenciais)

Monitor Remote Control: <ativado | pulado>

Próximo passo sugerido: <se credenciais faltando, lembrar> ou pronto pra trabalhar.
```

===PROMPT-END===

---

## 📦 Resumo do que vai ser atualizado

| Item | Origem | Destino |
|---|---|---|
| Código MCP | `~/mcp-servers/i9-tools/` (já no git) | Build local + registro nos 3 CLIs |
| Skills | `~/.claude/skills/team-*` (servidor) | Copiar pra local (via rsync ou skill-pack) |
| Scripts team | `docs/multi-client-assets/` (no repo) | `~/.claude/scripts/` |
| Config | — | Criar `~/.i9-tools/.env` vazio |
| Monitor | `docs/remote-control-monitor/` | Opcional — seguir guia |

## ⚠️ Pontos de atenção

1. **Skills globais não estão versionadas no repo** (moram em `~/.claude/skills/` do servidor). Opções:
   - SSH + rsync do servidor
   - Skill `/skill-pack` pra empacotar e enviar
   - Recriar manualmente (as skills têm SKILL.md + scripts — dá pra reproduzir)

2. **Tokens pessoais** não moram no git nem em nenhum lugar sincronizado. Cada máquina tem seu próprio `~/.i9-tools/.env` — preenche conforme precisar.

3. **Monitor Remote Control** no local precisa de **prefixo diferente** do servidor (ex: `mac`, `lin`, `wsl`) pra não colidir nomes no `claude.ai/code`. O guia em `docs/REMOTE-CONTROL-MONITOR.md` explica detalhado.

4. **Gemini CLI e Codex CLI opcionais** — se você não usa multi-cliente na máquina local, pode pular Passo 4 (pro Gemini/Codex). O Claude Code sozinho já aproveita todos os recursos.
