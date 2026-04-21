#!/usr/bin/env bash
# team-boot.sh — Levanta todos os teams na inicialização via team.sh start-all

export HOME="/home/ubuntu"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

TEAM_SH="${HOME}/.claude/scripts/team.sh"
LOG="/tmp/claude-teams-boot.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Iniciando boot de teams..." | tee -a "$LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Claude: $(which claude 2>/dev/null || echo NOT_FOUND)" | tee -a "$LOG"

# Aguarda tmux estar disponível
for i in $(seq 1 15); do
  tmux info >/dev/null 2>&1 && break
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Aguardando tmux... ($i/15)" | tee -a "$LOG"
  sleep 2
done

"$TEAM_SH" start-all >> "$LOG" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Boot concluido. Sessoes: $(tmux ls 2>/dev/null | wc -l)" | tee -a "$LOG"
