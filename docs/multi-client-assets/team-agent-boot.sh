#!/usr/bin/env bash
# team-agent-boot.sh — sobe uma sessão tmux de agente multi-client.
#
# Lê ~/.claude/teams.json, descobre o agente, respeita o campo "client"
# (claude-code | gemini-cli | codex-cli, default claude-code), e lança o
# CLI correto na sessão tmux com as env vars MCP_* injetadas.
#
# Uso:
#   team-agent-boot.sh <project> <team> <agent>
#
# Exemplo:
#   team-agent-boot.sh i9-team dev team-gemini
#
# Nota: este script é experimental da Fase 0/1 do multi-client.
# Complementa (não substitui) o team.sh tradicional que sobe Claude Code.

set -euo pipefail

PROJECT="${1:?Uso: $0 <project> <team> <agent>}"
TEAM="${2:?Uso: $0 <project> <team> <agent>}"
AGENT="${3:?Uso: $0 <project> <team> <agent>}"

TEAMS_JSON="${HOME}/.claude/teams.json"

# Lê o projeto/team/agente e o CLI dele
read -r -d '' JQ_QUERY <<'EOF' || true
  .projects[]
  | select(.name == $p)
  | .teams[]
  | select(.name == $t)
  | . as $team
  | $team.agents[]
  | select(.name == $a)
  | {
      root: ($team | $ARGS.positional[0] as $proj | $proj),
      dir: (.dir // "."),
      client: (.client // "claude-code"),
      orchestrator: $team.orchestrator
    }
EOF

# Projeto root
PROJECT_ROOT=$(jq -r --arg p "$PROJECT" '.projects[] | select(.name == $p) | .root' "$TEAMS_JSON")
[ -z "$PROJECT_ROOT" ] && { echo "ERRO: projeto '$PROJECT' não encontrado em teams.json"; exit 1; }

# Agente config (dir, client)
AGENT_DIR=$(jq -r --arg p "$PROJECT" --arg t "$TEAM" --arg a "$AGENT" \
  '.projects[] | select(.name == $p) | .teams[] | select(.name == $t) | .agents[] | select(.name == $a) | .dir // "."' \
  "$TEAMS_JSON")
AGENT_CLIENT=$(jq -r --arg p "$PROJECT" --arg t "$TEAM" --arg a "$AGENT" \
  '.projects[] | select(.name == $p) | .teams[] | select(.name == $t) | .agents[] | select(.name == $a) | .client // "claude-code"' \
  "$TEAMS_JSON")
ORCHESTRATOR=$(jq -r --arg p "$PROJECT" --arg t "$TEAM" \
  '.projects[] | select(.name == $p) | .teams[] | select(.name == $t) | .orchestrator' \
  "$TEAMS_JSON")

[ -z "$AGENT_DIR" ] && { echo "ERRO: agente '$AGENT' não encontrado em $PROJECT/$TEAM"; exit 1; }

# Nome da sessão tmux
if [ "$AGENT" = "$ORCHESTRATOR" ]; then
  SESSION_NAME="${PROJECT}-${TEAM}-orquestrador"
else
  SESSION_NAME="${PROJECT}-${TEAM}-${AGENT}"
fi

# CWD do agente
CWD="$PROJECT_ROOT"
if [ "$AGENT_DIR" != "." ]; then
  CWD="$PROJECT_ROOT/$AGENT_DIR"
fi

# Verifica se a sessão já existe
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "Sessão '$SESSION_NAME' já existe. Use 'tmux attach -t $SESSION_NAME' pra anexar."
  exit 0
fi

# Comando do CLI por tipo de client
case "$AGENT_CLIENT" in
  claude-code)
    CLI_CMD="claude"
    CLI_ARGS=""
    ;;
  gemini-cli)
    # Gemini herda env do shell → MCP vê MCP_* automaticamente
    CLI_CMD="gemini"
    CLI_ARGS="--yolo"
    ;;
  codex-cli)
    # Codex sandbox isola env → injeta via flags -c mcp_servers.*.env.*
    # Modo interativo usa --yolo (não existem --skip-git-repo-check nem
    # --dangerously-bypass-approvals-and-sandbox fora do subcomando 'exec').
    CLI_CMD="codex"
    CLI_ARGS="--yolo \
      -c mcp_servers.i9-team.env.MCP_PROJECT=\"${PROJECT}\" \
      -c mcp_servers.i9-team.env.MCP_TEAM=\"${TEAM}\" \
      -c mcp_servers.i9-team.env.MCP_AGENT_NAME=\"${AGENT}\" \
      -c mcp_servers.i9-team.env.MCP_CLIENT_ID=\"codex\" \
      -c mcp_servers.i9-agent-memory.env.MCP_PROJECT=\"${PROJECT}\" \
      -c mcp_servers.i9-agent-memory.env.MCP_TEAM=\"${TEAM}\" \
      -c mcp_servers.i9-agent-memory.env.MCP_AGENT_NAME=\"${AGENT}\" \
      -c mcp_servers.i9-agent-memory.env.MCP_CLIENT_ID=\"codex\""
    ;;
  *)
    echo "ERRO: cliente '$AGENT_CLIENT' não suportado. Aceitos: claude-code, gemini-cli, codex-cli"
    exit 1
    ;;
esac

echo "=== boot agente multi-client ==="
echo "project:        $PROJECT"
echo "team:           $TEAM"
echo "agent:          $AGENT"
echo "client:         $AGENT_CLIENT"
echo "cli_cmd:        $CLI_CMD"
echo "session_name:   $SESSION_NAME"
echo "cwd:            $CWD"
echo ""

# Cria a sessão tmux com env vars MCP_* + legados I9_*
tmux new-session -d -s "$SESSION_NAME" -c "$CWD" \
  -e "I9_TEAM_SESSION=$SESSION_NAME" \
  -e "I9_PROJECT=$PROJECT" \
  -e "I9_TEAM=$TEAM" \
  -e "I9_AGENT=$AGENT" \
  -e "MCP_PROJECT=$PROJECT" \
  -e "MCP_TEAM=$TEAM" \
  -e "MCP_AGENT_NAME=$AGENT" \
  -e "MCP_CLIENT_ID=$AGENT_CLIENT"

# Lança o CLI dentro da sessão
tmux send-keys -t "$SESSION_NAME" "$CLI_CMD $CLI_ARGS" Enter

echo "✅ Sessão '$SESSION_NAME' criada com CLI '$CLI_CMD'"
echo "   Attach: tmux attach -t $SESSION_NAME"
