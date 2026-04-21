#!/usr/bin/env bash
# install.sh — Instala todo o ecossistema Claude Ops em Linux ou macOS
#
# O que faz:
#   1. Detecta OS (Linux/Darwin)
#   2. Verifica deps (tmux, jq, docker, python3, git, node)
#   3. Instala psutil
#   4. Carrega .env (ou copia do .env.example)
#   5. Clona/atualiza mcp-servers
#   6. Builda todos os MCPs
#   7. Sobe Postgres pgvector via Docker (pra i9-agent-memory)
#   8. Copia scripts → ~/.claude/scripts/
#   9. Copia skills → ~/.claude/skills/
#   10. Copia/renderiza systemd units (Linux) OU launchd plists (macOS)
#   11. Cria diretório textfile_collector
#   12. Sobe stack monitoring (docker compose)
#   13. Habilita timer/agent
#   14. Roda doctor.sh

set -euo pipefail

# ── Cores ──
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅${NC} $*"; }
warn() { echo -e "${YELLOW}⚠️${NC}  $*"; }
err()  { echo -e "${RED}❌${NC} $*" >&2; }
info() { echo -e "${BLUE}→${NC} $*"; }

# ── Detecta OS ──
OS=$(uname -s)
case "$OS" in
  Linux)  OS_KIND="linux" ;;
  Darwin) OS_KIND="darwin" ;;
  *) err "OS não suportado: $OS"; exit 1 ;;
esac
info "Detected OS: $OS ($OS_KIND)"

# ── Paths absolutos ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Carrega .env ──
if [ ! -f .env ]; then
  warn ".env ausente — copiando de .env.example"
  cp templates/.env.example .env
  err "Edite .env com seus valores e rode novamente: nano $SCRIPT_DIR/.env"
  exit 1
fi
# shellcheck disable=SC1091
set -a; source .env; set +a

# ── Resolve paths default ──
MCP_ROOT="${MCP_ROOT:-$HOME/mcp-servers}"
CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude || echo "")}"
[ -z "$CLAUDE_BIN" ] && { err "Claude bin não encontrado. Defina CLAUDE_BIN em .env"; exit 1; }

# Resolve TEXTFILE_DIR
if [ -z "${TEXTFILE_DIR:-}" ]; then
  if [ "$OS_KIND" = "linux" ]; then
    TEXTFILE_DIR="/var/lib/node_exporter/textfile_collector"
  else
    TEXTFILE_DIR="/usr/local/var/node_exporter/textfile_collector"
  fi
fi

info "MCP_ROOT=$MCP_ROOT"
info "CLAUDE_BIN=$CLAUDE_BIN"
info "TEXTFILE_DIR=$TEXTFILE_DIR"

# ── 1. Verifica deps ──
echo ""
info "Fase 1/14 — Verificando dependências..."
MISSING=()
for cmd in tmux jq docker python3 git node; do
  if ! command -v "$cmd" >/dev/null; then
    MISSING+=("$cmd")
  else
    ok "$cmd: $(command -v $cmd)"
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  err "Dependências faltando: ${MISSING[*]}"
  if [ "$OS_KIND" = "linux" ]; then
    echo "Instale com: sudo apt install ${MISSING[*]}"
  else
    echo "Instale com: brew install ${MISSING[*]}"
  fi
  exit 1
fi

# ── 2. Instala psutil ──
echo ""
info "Fase 2/14 — Instalando psutil..."
python3 -c "import psutil" 2>/dev/null && ok "psutil já instalado" || \
  pip3 install --user psutil && ok "psutil instalado"

# ── 3. Clona/atualiza mcp-servers ──
echo ""
info "Fase 3/14 — Repositório mcp-servers..."
if [ ! -d "$MCP_ROOT" ]; then
  info "Clonando mcp-servers em $MCP_ROOT..."
  git clone git@github.com:Inoveon/mcp-servers.git "$MCP_ROOT"
else
  info "Atualizando mcp-servers..."
  (cd "$MCP_ROOT" && git pull origin main || true)
fi

# ── 4. Builda MCPs ──
echo ""
info "Fase 4/14 — Buildando MCPs..."
for d in "$MCP_ROOT"/*/; do
  [ -f "$d/package.json" ] || continue
  name=$(basename "$d")
  if [ -f "$d/dist/index.js" ]; then
    ok "$name: build existe (pulando)"
  else
    info "Buildando $name..."
    (cd "$d" && npm install --silent && npm run build) && ok "$name buildado"
  fi
done

# ── 5. Postgres pgvector via Docker ──
echo ""
info "Fase 5/14 — Postgres pgvector..."
if docker ps --format '{{.Names}}' | grep -q '^agent-memory-pg$'; then
  ok "Container agent-memory-pg já rodando"
elif docker ps -a --format '{{.Names}}' | grep -q '^agent-memory-pg$'; then
  info "Iniciando container agent-memory-pg existente..."
  docker start agent-memory-pg
else
  info "Criando container agent-memory-pg..."
  docker run -d --name agent-memory-pg \
    -e POSTGRES_USER="${POSTGRES_USER:-agent}" \
    -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-agent123}" \
    -e POSTGRES_DB="${POSTGRES_DB:-agent_memory}" \
    -p "${POSTGRES_PORT:-5432}:5432" \
    --restart unless-stopped \
    pgvector/pgvector:pg16
fi

# ── 6. Copia scripts → ~/.claude/scripts/ ──
echo ""
info "Fase 6/14 — Sincronizando scripts pro Claude global..."
bash "$SCRIPT_DIR/sync-to-claude.sh"

# ── 7. textfile_collector dir ──
echo ""
info "Fase 7/14 — Criando $TEXTFILE_DIR..."
if [ "$OS_KIND" = "linux" ] && [[ "$TEXTFILE_DIR" =~ ^/var ]]; then
  sudo mkdir -p "$TEXTFILE_DIR"
  sudo chown "$(id -u):$(id -g)" "$TEXTFILE_DIR"
else
  mkdir -p "$TEXTFILE_DIR"
fi
ok "$TEXTFILE_DIR criado"

# ── 8. Systemd (Linux) OU Launchd (macOS) ──
echo ""
if [ "$OS_KIND" = "linux" ]; then
  info "Fase 8/14 — Instalando systemd units..."

  # Renderiza units com paths corretos
  for unit in claude-teams.service claude-metrics.service claude-metrics.timer; do
    sed "s|{HOME}|$HOME|g; s|{TEXTFILE_DIR}|$TEXTFILE_DIR|g; s|{SCRIPT_DIR}|$SCRIPT_DIR|g" \
      "$SCRIPT_DIR/systemd/$unit" > "/tmp/$unit"
    sudo cp "/tmp/$unit" "/etc/systemd/system/$unit"
  done

  sudo systemctl daemon-reload
  sudo systemctl enable claude-teams.service claude-metrics.timer
  sudo systemctl start claude-metrics.timer
  ok "systemd units instaladas e timer ativo"
else
  info "Fase 8/14 — Instalando launchd plists..."
  LAUNCHD_DIR="$HOME/Library/LaunchAgents"
  mkdir -p "$LAUNCHD_DIR"

  for tmpl in launchd/*.plist.tmpl; do
    name=$(basename "$tmpl" .tmpl)
    sed "s|{HOME}|$HOME|g; s|{TEXTFILE_DIR}|$TEXTFILE_DIR|g" \
      "$tmpl" > "$LAUNCHD_DIR/$name"
    launchctl unload "$LAUNCHD_DIR/$name" 2>/dev/null || true
    launchctl load "$LAUNCHD_DIR/$name"
    ok "$name carregado"
  done
fi

# ── 9. Stack monitoring ──
echo ""
info "Fase 9/14 — Subindo stack monitoring (Prometheus + Grafana)..."
(cd monitoring && docker compose up -d)
ok "Containers up: prometheus:9090, grafana:3000, node_exporter:9100, process_exporter:9256"

# ── 10. Aguarda Grafana ficar pronto ──
echo ""
info "Fase 10/14 — Aguardando Grafana subir..."
for i in {1..30}; do
  if curl -s "http://localhost:3000/api/health" | grep -q '"database":"ok"'; then
    ok "Grafana pronto em http://localhost:3000 (admin/${GRAFANA_ADMIN_PASSWORD:-admin123})"
    break
  fi
  sleep 2
done

# ── 11. Roda métricas uma vez (validação) ──
echo ""
info "Fase 11/14 — Coletando métricas iniciais..."
TEXTFILE_DIR="$TEXTFILE_DIR" python3 monitoring/scripts/claude-metrics.py

# ── 12. Doctor ──
echo ""
info "Fase 12/14 — Diagnóstico..."
bash "$SCRIPT_DIR/doctor.sh"

# ── 13. teams.json (se ausente) ──
echo ""
info "Fase 13/14 — Verificando teams.json..."
if [ ! -f "$HOME/.claude/teams.json" ]; then
  warn "$HOME/.claude/teams.json ausente — copiando template"
  cp templates/teams.json.example "$HOME/.claude/teams.json"
  warn "Edite $HOME/.claude/teams.json com seus projetos"
else
  ok "teams.json existe"
fi

# ── 14. Final ──
echo ""
echo "════════════════════════════════════════════════════════════"
ok "Instalação concluída!"
echo ""
info "Próximos passos:"
echo "   1. Editar $HOME/.claude/teams.json (adicionar seus projetos)"
echo "   2. Pra cada projeto: rode /team-setup <nome> [tipo] no Claude"
echo "   3. Pra subir um team: $HOME/.claude/scripts/team.sh start <projeto> dev"
echo ""
info "URLs:"
echo "   • Grafana:    http://localhost:3000  (admin/${GRAFANA_ADMIN_PASSWORD:-admin123})"
echo "   • Prometheus: http://localhost:9090"
echo ""
info "Logs:"
echo "   • Boot teams:    /tmp/claude-teams-boot.log"
echo "   • Métricas:      /tmp/claude-metrics.log"
echo "   • RC monitor:    $HOME/.claude/logs/remote-control-monitor.log"
echo "════════════════════════════════════════════════════════════"
