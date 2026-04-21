#!/usr/bin/env bash
# sync-from-claude.sh — Pull mode: copia ~/.claude/scripts e skills pro projeto.
# Útil quando algo foi editado direto no Claude global e queremos versionar.

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅${NC} $*"; }
info() { echo -e "${YELLOW}→${NC}  $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Scripts (apenas os que já estão versionados) ──
info "Pull scripts (existentes no projeto)..."
for f in scripts/*.sh; do
  name=$(basename "$f")
  if [ -f "$HOME/.claude/scripts/$name" ]; then
    if ! diff -q "$HOME/.claude/scripts/$name" "$f" >/dev/null 2>&1; then
      cp "$HOME/.claude/scripts/$name" "$f"
      ok "$name atualizado a partir do Claude global"
    fi
  fi
done

# ── Skills (apenas as que já estão versionadas) ──
info "Pull skills (existentes no projeto)..."
for d in skills/*/; do
  name=$(basename "$d")
  if [ -d "$HOME/.claude/skills/$name" ]; then
    if ! diff -qr "$HOME/.claude/skills/$name" "$d" >/dev/null 2>&1; then
      rm -rf "$d"
      cp -r "$HOME/.claude/skills/$name" "skills/"
      ok "skill $name atualizada"
    fi
  fi
done

ok "Pull completo. Revise com 'git diff' antes de commitar."
