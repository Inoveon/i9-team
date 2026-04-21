#!/usr/bin/env bash
# team.sh — Gerencia teams de agentes Claude Code via tmux
# Uso: team.sh <comando> [projeto] [team]
# Comandos: start, start-all, stop, stop-all, list, status

TEAMS_JSON="${HOME}/.claude/teams.json"
CLAUDE_BIN="${CLAUDE_BIN:-$HOME/.nvm/versions/node/v24.15.0/bin/claude}"

# Aguarda Claude inicializar antes de injetar prompt
CLAUDE_INIT_WAIT="${CLAUDE_INIT_WAIT:-15}"

# Delay entre agentes no start-all (distribui carga de CPU no boot)
START_ALL_DELAY="${START_ALL_DELAY:-5}"

usage() {
  echo "Uso: $(basename "$0") <comando> [projeto] [team]"
  echo ""
  echo "Comandos:"
  echo "  start     <projeto> <team>  — Sobe todas as sessões do team"
  echo "  start-all                   — Sobe todos os teams (5s entre agentes)"
  echo "  stop      <projeto> <team>  — Mata todas as sessões do team"
  echo "  stop-all                    — Mata todos os teams"
  echo "  list                        — Lista todos os teams configurados"
  echo "  status                      — Lista sessões tmux ativas de teams"
  echo ""
  echo "Exemplo:"
  echo "  $(basename "$0") start i9-smart-pdv dev"
  echo "  $(basename "$0") start-all"
}

# Monta nome da sessão tmux
session_name() {
  local project="$1" team="$2" agent="$3" is_orch="$4"
  if [ "$is_orch" = "true" ]; then
    echo "${project}-${team}-orquestrador"
  else
    echo "${project}-${team}-${agent}"
  fi
}

cmd_list() {
  echo "Teams configurados em ${TEAMS_JSON}:"
  echo ""
  jq -r '.projects[] | "Projeto: \(.name)\n" + (.teams[] | "  Team: \(.name) | orquestrador: \(.orchestrator) | agentes: \([.agents[].name] | join(", "))\n")' "$TEAMS_JSON"
}

cmd_status() {
  echo "Sessões tmux de teams ativas:"
  echo ""
  tmux ls -F '#{session_name}' 2>/dev/null | grep -E '^[a-z0-9-]+-[a-z0-9-]+-[a-z0-9-]+$' || echo "Nenhuma sessão ativa."
}

cmd_start() {
  local project_name="$1" team_name="$2"

  if [ -z "$project_name" ] || [ -z "$team_name" ]; then
    echo "Erro: informe projeto e team."
    usage
    exit 1
  fi

  # Busca projeto e team no JSON
  local project_root
  project_root=$(jq -r --arg p "$project_name" '.projects[] | select(.name == $p) | .root' "$TEAMS_JSON")

  if [ -z "$project_root" ] || [ "$project_root" = "null" ]; then
    echo "Erro: projeto '$project_name' não encontrado em $TEAMS_JSON"
    exit 1
  fi

  local team_json
  team_json=$(jq -c --arg p "$project_name" --arg t "$team_name" \
    '.projects[] | select(.name == $p) | .teams[] | select(.name == $t)' "$TEAMS_JSON")

  if [ -z "$team_json" ]; then
    echo "Erro: team '$team_name' não encontrado no projeto '$project_name'"
    exit 1
  fi

  local orchestrator
  orchestrator=$(echo "$team_json" | jq -r '.orchestrator')

  echo "Iniciando team '${team_name}' do projeto '${project_name}'..."
  echo ""

  # Sobe cada agente
  while IFS= read -r agent_json; do
    local aname adir extra prompt
    aname=$(echo "$agent_json" | jq -r '.name')
    adir=$(echo "$agent_json" | jq -r '.dir // "."')
    extra=$(echo "$agent_json" | jq -r '.extra_args // ""')
    prompt=$(echo "$agent_json" | jq -r '.prompt_inicial // ""')

    local is_orch="false"
    [ "$aname" = "$orchestrator" ] && is_orch="true"

    local sname
    sname=$(session_name "$project_name" "$team_name" "$aname" "$is_orch")

    local abs_dir="${project_root}"

    # Verifica se sessão já existe
    if tmux has-session -t "$sname" 2>/dev/null; then
      echo "  ⚠ Sessão '$sname' já existe — pulando."
      continue
    fi

    echo "  → Criando sessão: $sname (dir: $abs_dir)"
    tmux new-session -d -s "$sname" -c "$abs_dir" \
      -e "I9_TEAM_SESSION=$sname" \
      -e "I9_PROJECT=$project_name" \
      -e "I9_TEAM=$team_name" \
      -e "I9_AGENT=$aname"

    local claude_cmd="export I9_TEAM_SESSION=$sname I9_PROJECT=$project_name I9_TEAM=$team_name I9_AGENT=$aname && $CLAUDE_BIN --agent $aname"
    [ -n "$extra" ] && claude_cmd="export I9_TEAM_SESSION=$sname I9_PROJECT=$project_name I9_TEAM=$team_name I9_AGENT=$aname && $CLAUDE_BIN --agent $aname $extra"
    tmux send-keys -t "$sname" "$claude_cmd" Enter

    local protocol_role="agent"
    [ "$is_orch" = "true" ] && protocol_role="orchestrator"

    (
      sleep "$CLAUDE_INIT_WAIT"
      tmux send-keys -t "$sname" "/team-protocol ${protocol_role}" Enter

      sleep 10
      tmux send-keys -t "$sname" "/team-protocol ${protocol_role}" Enter

      if [ "$is_orch" = "true" ]; then
        sleep 5
        tmux send-keys -t "$sname" -l "/remote-control ${project_name}-${team_name}-${aname}"
        tmux send-keys -t "$sname" Enter
        sleep 3
        tmux send-keys -t "$sname" Escape
      fi
    ) &

    # Delay entre agentes apenas no start-all (variável definida externamente)
    if [ -n "$_START_ALL_MODE" ]; then
      sleep "$START_ALL_DELAY"
    fi

  done < <(echo "$team_json" | jq -c '.agents[]')

  echo ""
  echo "Team '${team_name}' iniciado! Sessões:"
  tmux ls -F '#{session_name}' 2>/dev/null | grep "^${project_name}-${team_name}-"
  echo ""
  echo "Para entrar: tmux attach -t <sessão>"
}

cmd_start_all() {
  echo "Iniciando todos os teams (delay: ${START_ALL_DELAY}s entre agentes)..."
  echo ""

  export _START_ALL_MODE=1

  while IFS=' ' read -r project team; do
    cmd_start "$project" "$team"
  done < <(jq -r '.projects[] | .name as $p | .teams[] | "\($p) \(.name)"' "$TEAMS_JSON")

  unset _START_ALL_MODE

  echo ""
  echo "Todos os teams iniciados! Total de sessões: $(tmux ls 2>/dev/null | wc -l)"
}

cmd_stop() {
  local project_name="$1" team_name="$2"

  if [ -z "$project_name" ] || [ -z "$team_name" ]; then
    echo "Erro: informe projeto e team."
    usage
    exit 1
  fi

  echo "Encerrando team '${team_name}' do projeto '${project_name}'..."

  local prefix="${project_name}-${team_name}-"
  local count=0
  while IFS= read -r sname; do
    tmux kill-session -t "$sname" 2>/dev/null && echo "  ✓ $sname encerrada" && ((count++))
  done < <(tmux ls -F '#{session_name}' 2>/dev/null | grep "^${prefix}")

  [ "$count" -eq 0 ] && echo "Nenhuma sessão ativa encontrada para este team."
}

cmd_stop_all() {
  echo "Encerrando todos os teams..."
  local count=0
  while IFS= read -r sname; do
    tmux kill-session -t "$sname" 2>/dev/null && echo "  ✓ $sname encerrada" && ((count++))
  done < <(tmux ls -F '#{session_name}' 2>/dev/null)
  echo "Total encerradas: $count"
}

# Main
CMD="${1:-}"
case "$CMD" in
  start)      cmd_start "$2" "$3" ;;
  start-all)  cmd_start_all ;;
  stop)       cmd_stop "$2" "$3" ;;
  stop-all)   cmd_stop_all ;;
  list)       cmd_list ;;
  status)     cmd_status ;;
  *)          usage; exit 1 ;;
esac
