# Arquitetura — 3 camadas

## Visão geral

O Claude Ops tem 3 camadas independentes mas integradas:

1. **Orquestração** — teams de agentes em sessões tmux
2. **Vigília** — monitor de Remote Control + alertas WhatsApp
3. **Observabilidade** — métricas Prometheus + dashboards Grafana

## Camada 1 — Orquestração

### Componentes
- `~/.claude/teams.json` — configuração de projetos e teams
- `~/.claude/scripts/team.sh` — sobe/para teams
- `~/.claude/scripts/team-boot.sh` — wrapper pra boot automático
- Sessões tmux nomeadas: `<projeto>-<team>-<agente>`

### Ciclo de vida de um team

```
team.sh start <projeto> <team>
    ├─→ lê teams.json
    ├─→ pra cada agente:
    │     ├─→ cria sessão tmux detached em <projeto-root>
    │     ├─→ exporta I9_TEAM_SESSION, I9_PROJECT, I9_TEAM, I9_AGENT
    │     ├─→ roda: claude --agent <nome>
    │     ├─→ aguarda CLAUDE_INIT_WAIT (15s)
    │     ├─→ injeta: /team-protocol {orchestrator|agent}
    │     └─→ [só orquestrador] injeta: /remote-control <nome>
    └─→ log em /tmp/claude-teams-boot.log
```

### Boot automático

**Linux:** `systemd/claude-teams.service` → `team-boot.sh` → `team.sh start-all` (com `START_ALL_DELAY=5s` entre agentes pra não sobrecarregar CPU)

**macOS:** `launchd/com.claude.teams.plist` → mesma coisa, `RunAtLoad=true`

## Camada 2 — Vigília Remote Control

### Por que existe

O Remote Control do Claude Code permite conectar uma sessão tmux ao dashboard remoto Claude. Às vezes trava em "connecting..." ou desconecta silenciosamente. O monitor detecta e reconecta.

### Componentes
- `remote-control-monitor.sh` — roda a cada 30min
- Evolution API (WhatsApp) — via `~/.mcp.json` config
- Lock: `/tmp/rc-monitor.lock` (mkdir-based pra cross-platform)

### Classificação de estado

Para cada orquestrador em `teams.json`:
1. Captura últimas 5 linhas do pane (`tmux capture-pane`)
2. Classifica:
   - `ACTIVE` — "Remote Control active" visível
   - `STUCK_CONNECTING` — "Remote Control connecting..." há >15s
   - `DISCONNECTED` — nenhuma das duas
   - `NO_SESSION` — tmux não tem a sessão
3. Ação:
   - `ACTIVE` → nada
   - `STUCK` → `/remote-control` → Up Up Enter (menu Disconnect) → reconecta
   - `DISCONNECTED` → `/remote-control <nome>` (reconecta direto)
4. WhatsApp: envia notificação com status + `session_id` + URL `claude.ai/code/session_<id>`

### Execução

**Linux:** cron ou systemd timer (opcional — não incluído no instalador base)
**macOS:** `launchd/com.claude.rc-monitor.plist` com `StartInterval=1800` (30min)

Invocação manual: `bash ~/.claude/scripts/remote-control-monitor.sh`

## Camada 3 — Observabilidade

### Fluxo de dados

```
claude-metrics.py (psutil)
    ├─→ itera processos do OS
    ├─→ filtra cmdline contendo "bin/claude"
    ├─→ extrai --agent + basename(cwd) → (project, agent)
    ├─→ agrega: count, cpu_user, cpu_system, memory_rss
    └─→ escreve atomicamente em:
          <TEXTFILE_DIR>/claude_agents.prom
                    │
                    ▼
          node_exporter (:9100)
                    │ scrape 15s
                    ▼
          Prometheus (:9090)
                    ├─→ record rules (agregados por projeto)
                    └─→ alert rules (CPU/RAM thresholds)
                    │
                    ▼
          Grafana (:3000)
                    └─→ 3 dashboards provisionados automaticamente
```

### Execução periódica

**Linux:** `systemd/claude-metrics.timer` — `OnBootSec=10s`, `OnUnitActiveSec=30s`

**macOS:** `launchd/com.claude.metrics.plist` — `StartInterval=30`

### Cross-platform via psutil

O script original lia `/proc/<pid>/{cmdline,cwd,stat,status}` diretamente — Linux-only. Versão nova usa `psutil` que abstrai:

| Antes (Linux) | Agora (psutil) |
|---------------|---------------|
| `/proc/PID/cmdline` | `proc.cmdline()` |
| `/proc/PID/cwd` | `proc.cwd()` |
| `/proc/PID/stat` (campos 14,15) | `proc.cpu_times().user`, `.system` |
| `/proc/PID/status` (VmRSS) | `proc.memory_info().rss` |

Funciona em Linux + macOS + Windows (não testado).

### textfile_collector — onde fica

| OS | Path default |
|----|--------------|
| Linux (node_exporter via apt) | `/var/lib/node_exporter/textfile_collector/` |
| Linux (via Docker) | Volume montado |
| macOS (Homebrew) | `/usr/local/var/node_exporter/textfile_collector/` |
| macOS (Apple Silicon) | `/opt/homebrew/var/node_exporter/textfile_collector/` |

O `install.sh` detecta e cria.

## Containers monitoring

Todos via `docker-compose.yml`:

| Container | Porta | Função |
|-----------|-------|--------|
| `prometheus` | 9090 | Scrape + TSDB + alertas |
| `grafana` | 3000 | Dashboards |
| `node_exporter` | 9100 | Sistema + textfile_collector |
| `process_exporter` | 9256 | Fallback por `--agent` (Linux only) |

## Integrações

### Claude Code ↔ MCPs

Cada agente abre com `claude --agent <nome>`. O `.mcp.json` do projeto define MCPs ativos:
- `i9-team` (orquestração) — sempre
- `i9-agent-memory` — vault + busca semântica
- `evolution-api` — WhatsApp

### Claude Code ↔ monitoramento

Os processos `claude` ativos são detectados pelo `claude-metrics.py` (cmdline contém `bin/claude`), sem API do Claude — é passivo via OS.

### Monitor ↔ WhatsApp

`remote-control-monitor.sh` lê credenciais da Evolution API em `~/.mcp.json` e usa `curl` pra API REST. Evolution API roda fora do nosso ambiente.
