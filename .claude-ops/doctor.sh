#!/usr/bin/env bash
# doctor.sh — Diagnóstico cross-platform do ecossistema Claude Ops

set +e  # Não sair em erros — queremos mostrar TODOS os problemas

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅${NC} $*"; }
err()  { echo -e "${RED}❌${NC} $*"; }
warn() { echo -e "${YELLOW}⚠️${NC}  $*"; }
hdr()  { echo ""; echo -e "${BLUE}── $* ──${NC}"; }

OS=$(uname -s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Deps ──
hdr "Dependências"
for cmd in tmux jq docker python3 git node; do
  command -v "$cmd" >/dev/null && ok "$cmd → $(command -v $cmd)" || err "$cmd ausente"
done

command -v claude >/dev/null && ok "claude → $(command -v claude)" \
  || warn "claude não no PATH (pode estar em NVM)"

python3 -c "import psutil" 2>/dev/null && ok "psutil instalado" || err "psutil ausente (pip3 install --user psutil)"

# ── Scripts ──
hdr "Scripts globais (~/.claude/scripts/)"
for f in team.sh team-boot.sh team-tmux.sh remote-control-monitor.sh; do
  [ -x "$HOME/.claude/scripts/$f" ] && ok "$f executável" || err "$f ausente ou sem +x"
done

# ── Skills ──
hdr "Skills globais (~/.claude/skills/)"
for s in team-protocol team-launch team-watch team-survey mcp-setup team-setup; do
  [ -f "$HOME/.claude/skills/$s/SKILL.md" ] && ok "$s" || err "$s ausente"
done

# ── teams.json ──
hdr "~/.claude/teams.json"
if [ -f "$HOME/.claude/teams.json" ]; then
  jq . "$HOME/.claude/teams.json" >/dev/null 2>&1 && ok "JSON válido" || err "JSON inválido"
  count=$(jq -r '.projects | length' "$HOME/.claude/teams.json")
  ok "$count projetos configurados"
else
  warn "teams.json ausente — copie de templates/teams.json.example"
fi

# ── mcp-servers ──
hdr "Repositório mcp-servers"
MCP_ROOT=""
for p in ~/mcp-servers /home/ubuntu/mcp-servers; do
  [ -d "$p" ] && MCP_ROOT="$p" && break
done
if [ -n "$MCP_ROOT" ]; then
  ok "Repo em $MCP_ROOT"
  for d in "$MCP_ROOT"/*/; do
    [ -f "$d/package.json" ] || continue
    name=$(basename "$d")
    [ -f "$d/dist/index.js" ] && ok "$name build OK" || err "$name SEM build"
  done
else
  err "mcp-servers não clonado"
fi

# ── Postgres pgvector ──
hdr "Postgres (i9-agent-memory)"
if docker ps --format '{{.Names}}' | grep -q '^agent-memory-pg$'; then
  ok "Container agent-memory-pg rodando"
  docker exec agent-memory-pg pg_isready -U agent -d agent_memory >/dev/null 2>&1 \
    && ok "Postgres pronto" || err "Postgres não aceita conexões"
else
  err "Container agent-memory-pg não rodando"
fi

# ── systemd (Linux) ──
if [ "$OS" = "Linux" ]; then
  hdr "systemd units"
  for u in claude-teams.service claude-metrics.service claude-metrics.timer; do
    systemctl is-enabled "$u" >/dev/null 2>&1 && ok "$u enabled" || err "$u não habilitado"
  done
  systemctl is-active claude-metrics.timer >/dev/null 2>&1 && ok "timer ativo" || err "timer inativo"
fi

# ── launchd (macOS) ──
if [ "$OS" = "Darwin" ]; then
  hdr "launchd agents"
  for name in com.claude.teams com.claude.metrics com.claude.rc-monitor; do
    if launchctl list | grep -q "$name"; then
      ok "$name carregado"
    else
      err "$name não carregado"
    fi
  done
fi

# ── Containers monitoring ──
hdr "Stack monitoring (Docker)"
for c in prometheus grafana node_exporter process_exporter; do
  docker ps --format '{{.Names}}' | grep -q "^$c$" && ok "$c UP" || err "$c não rodando"
done

# ── Textfile collector ──
hdr "Métricas (textfile_collector)"
for p in /var/lib/node_exporter/textfile_collector /usr/local/var/node_exporter/textfile_collector; do
  if [ -f "$p/claude_agents.prom" ]; then
    lines=$(wc -l < "$p/claude_agents.prom")
    age=$(( $(date +%s) - $(stat -c %Y "$p/claude_agents.prom" 2>/dev/null || stat -f %m "$p/claude_agents.prom") ))
    ok "$p/claude_agents.prom ($lines linhas, $age s atrás)"
  fi
done

# ── URLs ──
hdr "URLs de serviço"
curl -sf -o /dev/null http://localhost:9090/-/healthy && ok "Prometheus http://localhost:9090" || err "Prometheus não responde"
curl -sf "http://localhost:3000/api/health" | grep -q '"database":"ok"' && ok "Grafana http://localhost:3000" || err "Grafana não pronto"
curl -sf -o /dev/null http://localhost:9100/metrics && ok "node_exporter :9100" || err "node_exporter não responde"
curl -sf -o /dev/null http://localhost:9256/metrics && ok "process_exporter :9256" || err "process_exporter não responde"

# ── Sessões tmux ativas ──
hdr "Sessões tmux"
sessions=$(tmux ls 2>/dev/null | wc -l)
if [ "$sessions" -gt 0 ]; then
  ok "$sessions sessões tmux ativas"
  tmux ls 2>/dev/null | head -5 | sed 's/^/   /'
else
  warn "Nenhuma sessão tmux"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
ok "Diagnóstico completo"
