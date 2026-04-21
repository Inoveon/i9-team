#!/usr/bin/env bash
# sync-to-claude.sh — Copia scripts e skills do projeto pro ~/.claude/

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅${NC} $*"; }
info() { echo -e "${YELLOW}→${NC}  $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Scripts ──
info "Sincronizando scripts pro ~/.claude/scripts/..."
mkdir -p "$HOME/.claude/scripts"
for f in scripts/*.sh; do
  cp "$f" "$HOME/.claude/scripts/"
  chmod +x "$HOME/.claude/scripts/$(basename $f)"
  bash -n "$HOME/.claude/scripts/$(basename $f)" && ok "$(basename $f) copiado e validado"
done

# ── Skills ──
info "Sincronizando skills pro ~/.claude/skills/..."
mkdir -p "$HOME/.claude/skills"
for d in skills/*/; do
  name=$(basename "$d")
  cp -r "$d" "$HOME/.claude/skills/"
  ok "skill $name copiada"
done

ok "Sync completo. Reinicie sessões Claude para carregar mudanças."
