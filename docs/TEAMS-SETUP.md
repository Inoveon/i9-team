# Teams Setup — Claude Code

Configuração dos teams de agentes Claude Code via tmux + MCP i9-team.

---

## Estrutura de Teams

```
~/.claude/teams.json          ← catálogo de projetos e teams
~/.claude/scripts/team.sh     ← gerencia sessões tmux
~/.claude/scripts/team-tmux.sh ← layout tmux (Linux)
~/.claude/scripts/team-iterm.sh ← layout iTerm2 (macOS)
~/.claude/skills/team-launch/ ← skill /team-launch
~/.claude/skills/team-protocol/ ← skill /team-protocol
~/.claude/skills/team-watch/  ← skill /team-watch
```

---

## `~/.claude/teams.json`

```json
{
  "version": "1",
  "projects": [
    {
      "name": "i9-team",
      "root": "/home/ubuntu/projects/i9-team",
      "teams": [{
        "name": "dev",
        "orchestrator": "team-orchestrator",
        "agents": [
          { "name": "team-orchestrator", "dir": "." },
          { "name": "team-dev-backend", "dir": "." },
          { "name": "team-dev-frontend", "dir": "." },
          { "name": "team-dev-mobile", "dir": "." }
        ]
      }]
    },
    {
      "name": "i9-smart-pdv",
      "root": "/home/ubuntu/projects/i9-smart-pdv",
      "teams": [{
        "name": "dev",
        "orchestrator": "team-orchestrator",
        "agents": [
          { "name": "team-orchestrator", "dir": "." },
          { "name": "team-dev-backend", "dir": "backend" },
          { "name": "team-dev-frontend", "dir": "frontend" }
        ]
      }]
    },
    {
      "name": "proxmox-infrastructure",
      "root": "/home/ubuntu/projects/proxmox-infrastructure",
      "teams": [{
        "name": "infra",
        "orchestrator": "team-orchestrator",
        "agents": [
          { "name": "team-orchestrator", "dir": "." },
          { "name": "team-infra", "dir": "." },
          { "name": "team-ops", "dir": "." }
        ]
      }]
    }
  ]
}
```

---

## Comandos

```bash
# Listar teams configurados
~/.claude/scripts/team.sh list

# Ver sessões ativas
~/.claude/scripts/team.sh status

# Subir um team
~/.claude/scripts/team.sh start <projeto> <team>

# Parar um team
~/.claude/scripts/team.sh stop <projeto> <team>

# Abrir no iTerm2 (macOS)
~/.claude/scripts/team-iterm.sh <projeto> <team>

# Abrir no tmux nativo (Linux)
~/.claude/scripts/team-tmux.sh <projeto> <team>
```

---

## Protocolo de Orquestração

Sempre usar a skill `/team-protocol orchestrator` ao iniciar uma sessão de orquestrador.

### Fluxo obrigatório

```
team_list_agents()
→ team_send(agente, tarefa)
→ sleep 30s
→ loop: team_check(agente, 80) a cada 60s
→ team_note_write("progresso", resultado, "append")
→ reportar ao usuário
```

### Regras absolutas

- ❌ NUNCA usar Agent tool para delegar — sempre `team_send`
- ✅ SEMPRE fazer `team_check` antes de concluir
- ✅ SEMPRE salvar com `team_note_write`

---

## MCP i9-team — Tools Disponíveis

| Tool | Descrição |
|------|-----------|
| `team_list_agents` | Lista agentes e status das sessões tmux |
| `team_send(agent, msg)` | Envia mensagem para um agente |
| `team_check(agent, lines)` | Captura output atual do agente |
| `team_note_write(name, content, mode)` | Salva nota no vault |
| `team_note_read(name)` | Lê nota do vault |
| `team_note_list()` | Lista todas as notas |

---

## Agentes Disponíveis por Projeto

### i9-team Portal
| Agente | Escopo |
|--------|--------|
| `team-orchestrator` | Coordena todos os agentes |
| `team-dev-backend` | Fastify 5, node-pty, WebSocket, Prisma |
| `team-dev-frontend` | Next.js 15, xterm.js, ShadCN |
| `team-dev-mobile` | Flutter, Riverpod, glass UI |

### proxmox-infrastructure
| Agente | Escopo |
|--------|--------|
| `team-orchestrator` | Coordena infra e ops |
| `team-infra` | Terraform, Ansible, Proxmox, Redes, DNS |
| `team-ops` | Monitoramento, Backup, Segurança, VPN |
