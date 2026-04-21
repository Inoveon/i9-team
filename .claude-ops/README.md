# Claude Ops — Ecossistema auto-contido

Tudo o que é necessário para rodar um sistema completo de agentes Claude Code orquestrados em tmux, com monitoramento em tempo real e WhatsApp alerting — **em qualquer máquina Linux ou macOS**, a partir deste diretório.

---

## O que tem aqui

```
.claude-ops/
├── README.md                   ← você está aqui
├── INSTALL.md                  ← passo-a-passo detalhado cross-platform
├── install.sh                  ← instalador automatizado (detecta OS)
├── uninstall.sh                ← remove tudo (preserva dados)
├── sync-to-claude.sh           ← projeto → ~/.claude/
├── sync-from-claude.sh         ← ~/.claude/ → projeto (pull mode)
├── doctor.sh                   ← diagnóstico completo
│
├── scripts/                    ← scripts shell (cross-platform)
│   ├── team.sh                   # orquestra teams via tmux
│   ├── team-boot.sh              # wrapper pra systemd/launchd
│   ├── team-tmux.sh              # split-view dos agentes
│   └── remote-control-monitor.sh # vigia RC + WhatsApp alerting
│
├── skills/                     ← 6 skills do ecossistema
│   ├── team-protocol/            # define orchestrator/agent
│   ├── team-launch/              # sobe/para teams
│   ├── team-watch/               # monitora teams em loop
│   ├── team-survey/              # levantamento multi-camada
│   ├── mcp-setup/                # instala MCPs em projetos
│   └── team-setup/               # entry-point completo por projeto
│
├── monitoring/                 ← stack Prometheus + Grafana
│   ├── docker-compose.yml
│   ├── scripts/
│   │   └── claude-metrics.py     # cross-platform via psutil
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── rules/
│   │       └── claude_projects.yml
│   ├── process_exporter/
│   │   └── config.yml            # (Linux only)
│   └── grafana/provisioning/
│       ├── datasources/prometheus.yml
│       └── dashboards/
│           ├── dashboards.yml
│           └── json/             # 3 dashboards
│
├── systemd/                    ← unidades Linux
│   ├── claude-teams.service      # boot automático dos teams
│   ├── claude-metrics.service    # coleta métricas
│   └── claude-metrics.timer      # 30s
│
├── launchd/                    ← agents macOS
│   ├── com.claude.teams.plist.tmpl
│   ├── com.claude.metrics.plist.tmpl
│   └── com.claude.rc-monitor.plist.tmpl
│
├── templates/                  ← templates de configuração
│   ├── teams.json.example        # configuração dos teams
│   └── .env.example              # variáveis de ambiente
│
└── docs/                       ← documentação detalhada
    ├── architecture.md
    ├── metrics.md
    ├── alerts.md
    ├── dashboards.md
    ├── whatsapp-alerting.md
    └── troubleshooting.md
```

---

## Quick start

### Instalação (Linux ou macOS)

```bash
cd .claude-ops
cp templates/.env.example .env
# edite .env com suas credenciais (Evolution API, OpenAI, Postgres, etc.)
bash install.sh
```

O `install.sh` cuida de tudo:
1. Detecta OS (Linux/Darwin)
2. Verifica `tmux`, `jq`, `docker`, `python3`, `git`, `node`
3. Instala `psutil`
4. Clona/atualiza `mcp-servers`
5. Builda todos os MCPs
6. Sobe Postgres pgvector em container
7. Copia scripts e skills pro `~/.claude/`
8. Instala systemd units (Linux) ou launchd plists (macOS)
9. Cria diretório textfile_collector
10. Sobe stack monitoring (Prometheus + Grafana + exporters)
11. Habilita timers/agents
12. Roda `doctor.sh` pra validar

### Uso diário

**Preparar projeto novo pra ter team:**
```bash
# No Claude Code, invocar skill team-setup:
/team-setup /caminho/do/projeto [tipo]
```

Tipos: `dev-fullstack | dev-web | dev-mobile | pdv | service | infra | issues`

**Subir um team:**
```bash
~/.claude/scripts/team.sh start <projeto> <team>
```

**Ver dashboards:**
- Grafana: http://localhost:3000 (admin / admin123)
- Prometheus: http://localhost:9090

**Diagnóstico:**
```bash
cd .claude-ops && bash doctor.sh
```

---

## Arquitetura (3 camadas)

```
┌──────────────────────────────────────────────────────────────┐
│  CAMADA 1 — Orquestração de teams                            │
│                                                              │
│  ~/.claude/teams.json                                        │
│         │                                                    │
│         ▼                                                    │
│  team.sh start <projeto> <team>                              │
│         │                                                    │
│         ▼                                                    │
│  tmux sessions (1 por agente)                                │
│  ├── <projeto>-<team>-orquestrador                           │
│  ├── <projeto>-<team>-team-dev-backend                       │
│  └── <projeto>-<team>-team-dev-frontend                      │
│         │                                                    │
│         ▼                                                    │
│  /team-protocol {orchestrator|agent}                         │
│  /remote-control <nome>  (só orquestrador)                   │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  CAMADA 2 — Vigília Remote Control + WhatsApp alerting       │
│                                                              │
│  remote-control-monitor.sh (cron-like, a cada 30min)         │
│         │                                                    │
│         ├─→ tmux capture-pane (orquestradores)               │
│         │                                                    │
│         ▼                                                    │
│  Classifica: ACTIVE | STUCK_CONNECTING | DISCONNECTED        │
│         │                                                    │
│         └─→ Reconecta + notifica via Evolution API WhatsApp  │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  CAMADA 3 — Métricas Prometheus + Grafana                    │
│                                                              │
│  claude-metrics.py (psutil, cross-platform)                  │
│         │                                                    │
│         ▼                                                    │
│  /var/lib/node_exporter/textfile_collector/                  │
│    claude_agents.prom                                        │
│         │                                                    │
│         ▼                                                    │
│  node_exporter → Prometheus (scrape 15s)                     │
│         │                                                    │
│         ▼                                                    │
│  Record rules + alertas                                      │
│         │                                                    │
│         ▼                                                    │
│  Grafana (3 dashboards: agents, machine, team-view)          │
└──────────────────────────────────────────────────────────────┘
```

---

## Cross-platform — Linux e macOS

| Ponto | Linux | macOS | Solução |
|-------|-------|-------|---------|
| Scheduler | systemd | launchd | Templates separados em `systemd/` e `launchd/` |
| Coleta de métricas | psutil | psutil | Cross-platform já nativo |
| Lock concorrente | `mkdir` | `mkdir` | POSIX em ambos |
| textfile_collector | `/var/lib/...` | `/usr/local/var/...` | Detectado em runtime |
| NVM/Claude bin | `command -v claude` | `command -v claude` | Resolução dinâmica |

---

## Dependências

- `tmux` ≥ 3.0
- `jq`
- `docker` + `docker compose`
- `python3` + `psutil`
- `git`
- `node` + `npm`
- `claude` (Anthropic CLI)

---

## Referências

- Documentação detalhada: `docs/`
- Passos manuais (caso `install.sh` falhe): `INSTALL.md`
- Skills individuais: `skills/<nome>/SKILL.md`
- Troubleshooting: `docs/troubleshooting.md`
