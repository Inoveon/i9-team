#!/usr/bin/env bash
# team-tmux.sh — Abre sessões do team em split panes no tmux (Linux)
# Uso: team-tmux.sh <projeto> <team>

project_name="$1"
team_name="$2"

if [ -z "$project_name" ] || [ -z "$team_name" ]; then
  echo "Uso: $(basename "$0") <projeto> <team>"
  exit 1
fi

prefix="${project_name}-${team_name}-"
orch_session="${prefix}orquestrador"

if ! tmux has-session -t "$orch_session" 2>/dev/null; then
  echo "Erro: sessão '$orch_session' não encontrada."
  echo "Execute: team.sh start ${project_name} ${team_name}"
  exit 1
fi

# Cria janela de visualização no tmux com splits
WIN="team-view-${project_name}-${team_name}"
tmux new-window -n "$WIN"

# Painel esquerdo: orquestrador
tmux send-keys -t "$WIN" "tmux attach -t $orch_session" Enter

# Agentes à direita
mapfile -t agents < <(tmux ls -F '#{session_name}' 2>/dev/null | grep "^${prefix}" | grep -v orquestrador)

for i in "${!agents[@]}"; do
  sname="${agents[$i]}"
  tmux split-window -t "$WIN" -v
  tmux send-keys -t "$WIN" "tmux attach -t $sname" Enter
done

tmux select-layout -t "$WIN" tiled
echo "Layout tmux aberto: $orch_session + ${#agents[@]} agente(s)"
