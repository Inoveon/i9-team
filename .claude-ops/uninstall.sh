#!/usr/bin/env bash
# uninstall.sh — Remove o ecossistema Claude Ops (preserva ~/.claude/scripts e skills)

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅${NC} $*"; }
warn() { echo -e "${YELLOW}⚠️${NC}  $*"; }
info() { echo -e "${YELLOW}→${NC}  $*"; }

OS=$(uname -s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
warn "Este script vai:"
echo "   - Parar e remover unidades systemd/launchd (Claude Teams + Metrics + RC Monitor)"
echo "   - Parar containers do monitoring (prometheus, grafana, node_exporter, process_exporter)"
echo "   - NÃO remove ~/.claude/scripts, ~/.claude/skills, mcp-servers, ou dados"
echo ""
read -p "Continuar? (y/N) " ans
[ "$ans" = "y" ] || { info "Cancelado"; exit 0; }

# ── systemd (Linux) ──
if [ "$OS" = "Linux" ]; then
  info "Removendo systemd units..."
  for unit in claude-metrics.timer claude-metrics.service claude-teams.service; do
    sudo systemctl stop "$unit" 2>/dev/null || true
    sudo systemctl disable "$unit" 2>/dev/null || true
    sudo rm -f "/etc/systemd/system/$unit"
  done
  sudo systemctl daemon-reload
  ok "systemd units removidas"
fi

# ── launchd (macOS) ──
if [ "$OS" = "Darwin" ]; then
  info "Removendo launchd plists..."
  for name in com.claude.teams com.claude.metrics com.claude.rc-monitor; do
    launchctl unload "$HOME/Library/LaunchAgents/$name.plist" 2>/dev/null || true
    rm -f "$HOME/Library/LaunchAgents/$name.plist"
  done
  ok "launchd plists removidos"
fi

# ── Docker monitoring ──
info "Parando monitoring..."
(cd monitoring && docker compose down) || true
ok "Containers monitoring parados"

echo ""
ok "Uninstall completo. Mantido: ~/.claude/scripts, ~/.claude/skills, ~/mcp-servers, agent-memory-pg"
