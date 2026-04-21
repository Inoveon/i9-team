#!/usr/bin/env bash
# remote-control-monitor.sh
# Monitora os orquestradores configurados em ~/.claude/teams.json e mantém
# o Remote Control do Claude Code ativo em cada um.
#
# Comportamento:
#   - Lista todos os orquestradores dinamicamente do teams.json
#   - Para cada sessão tmux do orquestrador, inspeciona o rodapé
#   - Classifica em ACTIVE, STUCK_CONNECTING ou DISCONNECTED
#   - STUCK → faz disconnect via menu e reconecta com nome
#   - DISCONNECTED → reconecta direto com nome
#   - Toda ação de conectar dispara mensagem no WhatsApp via Evolution API
#
# Dependências: bash, jq, tmux, curl

set -uo pipefail

TEAMS_JSON="${HOME}/.claude/teams.json"
LOG_FILE="${HOME}/.claude/logs/remote-control-monitor.log"
LOCK_FILE="/tmp/rc-monitor.lock"
MCP_JSON="${HOME}/.mcp.json"

# Evolution API — lidas de ~/.mcp.json via jq
EVO_URL=$(jq -r '.mcpServers."evolution-api".env.EVOLUTION_API_URL // empty' "$MCP_JSON")
EVO_KEY=$(jq -r '.mcpServers."evolution-api".env.EVOLUTION_API_KEY // empty' "$MCP_JSON")
EVO_INSTANCE=$(jq -r '.mcpServers."evolution-api".env.EVOLUTION_DEFAULT_INSTANCE // empty' "$MCP_JSON")

# Destinatário de alertas
WHATSAPP_NUMBER="5583988710328"

# Intervalo entre o 1º e o 2º check de "connecting" (para evitar falso positivo)
STUCK_RECHECK_SECONDS=15

log() {
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "[$ts] $*" | tee -a "$LOG_FILE"
}

send_whatsapp() {
  local msg="$1"
  if [ -z "$EVO_URL" ] || [ -z "$EVO_KEY" ] || [ -z "$EVO_INSTANCE" ]; then
    log "WARN: Evolution config ausente — mensagem não enviada"
    return 1
  fi
  local resp
  resp=$(curl -sS -m 10 -X POST "$EVO_URL/message/sendText/$EVO_INSTANCE" \
    -H "apikey: $EVO_KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg n "$WHATSAPP_NUMBER" --arg t "$msg" '{number:$n,text:$t}')" 2>&1)
  if echo "$resp" | grep -q '"status":"PENDING"'; then
    log "whatsapp_sent to=$WHATSAPP_NUMBER"
    return 0
  else
    log "whatsapp_FAILED resp=$(echo "$resp" | head -c 200)"
    return 1
  fi
}

# Classifica estado do Remote Control numa sessão tmux
# Saída: ACTIVE | STUCK_CONNECTING | DISCONNECTED | NO_SESSION
classify_state() {
  local session="$1"
  if ! tmux has-session -t "$session" 2>/dev/null; then
    echo "NO_SESSION"
    return
  fi
  local pane
  pane=$(tmux capture-pane -t "$session" -p 2>/dev/null | tail -5)
  if echo "$pane" | grep -q "Remote Control active"; then
    echo "ACTIVE"
    return
  fi
  # Procurar "Remote Control connecting…" nas últimas linhas
  if echo "$pane" | grep -q "Remote Control connecting"; then
    # Re-checa depois de N segundos — se ainda estiver "connecting" é travado
    sleep "$STUCK_RECHECK_SECONDS"
    local pane2
    pane2=$(tmux capture-pane -t "$session" -p 2>/dev/null | tail -5)
    if echo "$pane2" | grep -q "Remote Control active"; then
      echo "ACTIVE"
      return
    elif echo "$pane2" | grep -q "Remote Control connecting"; then
      echo "STUCK_CONNECTING"
      return
    fi
  fi
  echo "DISCONNECTED"
}

# Extrai o session_id da URL que aparece depois do connect
extract_session_id() {
  local session="$1"
  tmux capture-pane -t "$session" -p 2>/dev/null \
    | grep -oE "session_[A-Za-z0-9]+" | tail -1
}

# Desconecta via menu: /remote-control → Up Up → Enter
disconnect_remote() {
  local session="$1"
  tmux send-keys -t "$session" -l "/remote-control"
  tmux send-keys -t "$session" Enter
  sleep 3
  tmux send-keys -t "$session" Up
  sleep 0.3
  tmux send-keys -t "$session" Up
  sleep 0.3
  tmux send-keys -t "$session" Enter
  sleep 3
}

# Conecta com nome: /remote-control <nome>
connect_remote() {
  local session="$1"
  local rc_name="$2"
  tmux send-keys -t "$session" -l "/remote-control $rc_name"
  tmux send-keys -t "$session" Enter
  sleep 10
}

# Executa ação em um orquestrador + envia WhatsApp se houve ação de conectar
process_orchestrator() {
  local project="$1"
  local team="$2"
  local agent="$3"
  local session="$4"
  local rc_name="$5"

  local state
  state=$(classify_state "$session")
  log "[$project/$team] session=$session state=$state"

  case "$state" in
    ACTIVE)
      return 0
      ;;
    NO_SESSION)
      log "[$project/$team] WARN session not found in tmux — skipping"
      return 0
      ;;
    STUCK_CONNECTING)
      log "[$project/$team] action=reset (disconnect + connect as '$rc_name')"
      disconnect_remote "$session"
      connect_remote "$session" "$rc_name"
      ;;
    DISCONNECTED)
      log "[$project/$team] action=connect (as '$rc_name')"
      connect_remote "$session" "$rc_name"
      ;;
  esac

  # Validar resultado
  sleep 2
  local final_state final_sid
  final_state=$(tmux capture-pane -t "$session" -p 2>/dev/null | tail -5 \
    | grep -q "Remote Control active" && echo "ACTIVE" || echo "UNKNOWN")
  final_sid=$(extract_session_id "$session")

  log "[$project/$team] result=$final_state session_id=$final_sid"

  # WhatsApp — só quando o script executou ação de conectar
  local url="https://claude.ai/code/$final_sid"
  local status_icon
  [ "$final_state" = "ACTIVE" ] && status_icon="✅" || status_icon="❌"
  local msg
  msg=$(cat <<EOF
$status_icon Remote Control — ação executada

📍 $project / $team
🧭 $agent
⚠️ Estado anterior: $state
📌 Resultado: $final_state
🔗 $url
🏷️ $rc_name
⏰ $(date +"%Y-%m-%d %H:%M:%S %Z")
EOF
)
  send_whatsapp "$msg"
}

main() {
  # Lock pra não rodar ticks em paralelo
  exec 200>"$LOCK_FILE"
  if ! flock -n 200; then
    log "ERROR another tick in progress — exiting"
    exit 1
  fi

  if [ ! -f "$TEAMS_JSON" ]; then
    log "ERROR teams.json not found at $TEAMS_JSON"
    exit 1
  fi

  local start_ts
  start_ts=$(date +%s)
  log "tick start"

  # Itera orquestradores: projeto, team, agente, sessão, nome_remote
  local count=0
  while IFS=$'\t' read -r project team agent session rc_name; do
    [ -z "$project" ] && continue
    count=$((count + 1))
    process_orchestrator "$project" "$team" "$agent" "$session" "$rc_name"
  done < <(jq -r '
    .projects[] | .name as $p | .teams[] |
    [$p, .name, .orchestrator, "\($p)-\(.name)-orquestrador", "\($p)-\(.name)-\(.orchestrator)"] |
    @tsv
  ' "$TEAMS_JSON")

  local duration=$(( $(date +%s) - start_ts ))
  log "tick end duration=${duration}s orchestrators=$count"
}

main "$@"
