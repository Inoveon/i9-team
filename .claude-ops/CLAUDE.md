# Claude Ops — Instruções pra Claude

Este diretório (`.claude-ops/`) é **auto-contido**: tudo que você precisa para instalar e operar o ecossistema Claude Ops em qualquer ambiente Linux/macOS está aqui.

## Objetivo

Você deve conseguir, lendo apenas este diretório:
1. Instalar o sistema completo em ambiente novo
2. Configurar um projeto pra ter team funcionando
3. Diagnosticar problemas sem depender de informação externa

## Fluxo padrão

### Ambiente novo
```bash
cd .claude-ops
cp templates/.env.example .env && nano .env
bash install.sh
```

### Projeto novo dentro do ambiente configurado
```
/team-setup <nome> [tipo]
```

Se o usuário não especificar tipo: perguntar qual (`dev-fullstack | dev-web | dev-mobile | pdv | service | infra | issues`).

## O que está aqui

| Path | Função |
|------|--------|
| `install.sh` | Instala tudo em Linux/macOS — detecta OS |
| `uninstall.sh` | Remove unidades systemd/launchd + containers (preserva dados) |
| `sync-to-claude.sh` | Copia scripts/skills → ~/.claude/ |
| `sync-from-claude.sh` | Pull inverso — pra capturar edições em ~/.claude/ de volta no projeto |
| `doctor.sh` | Diagnóstico — roda depois de install |
| `scripts/` | 4 shell scripts (team.sh, team-boot.sh, team-tmux.sh, remote-control-monitor.sh) |
| `skills/` | 6 skills Claude (team-protocol, team-launch, team-watch, team-survey, mcp-setup, team-setup) |
| `monitoring/` | Stack Prometheus + Grafana + exporters + claude-metrics.py (psutil) |
| `systemd/` | Unidades Linux |
| `launchd/` | Templates .plist macOS |
| `templates/` | .env.example, teams.json.example |
| `docs/` | Documentação técnica detalhada |

## Quando editar o quê

### Atualizar skill
1. Editar `skills/<nome>/SKILL.md`
2. `bash sync-to-claude.sh` (copia pro Claude global)
3. Reiniciar sessão Claude

### Atualizar script shell
1. Editar `scripts/<nome>.sh`
2. `bash sync-to-claude.sh`
3. Se usado por systemd/launchd, reiniciar unidade

### Atualizar unidade systemd/launchd
1. Editar em `systemd/` ou `launchd/`
2. Re-rodar `bash install.sh` (regenera via sed substituindo vars) OU editar manualmente o instalado

### Atualizar dashboards Grafana
1. Editar `monitoring/grafana/provisioning/dashboards/json/*.json`
2. Grafana detecta via `updateIntervalSeconds: 30` — não precisa restart
3. OU `docker compose restart grafana`

### Mudar credenciais
1. Editar `.env` (NÃO committar — já ignorado)
2. Re-rodar `install.sh` pra re-renderizar plists/units

## Pull-mode (quando algo foi editado direto no ~/.claude/)

Se você (Claude) editou skills ou scripts direto no `~/.claude/` durante uma sessão, traga de volta:

```bash
cd .claude-ops
bash sync-from-claude.sh
git diff  # revisar
git add -A && git commit -m "chore(ops): sync skills/scripts do Claude global"
```

## Reproduzir em outro ambiente

Este diretório é tudo que precisa:

```bash
# Numa máquina nova
git clone <repo-do-projeto>
cd <projeto>/.claude-ops
cp templates/.env.example .env
nano .env  # ajustar paths do HOME, senhas, API keys, etc.
bash install.sh
```

Pronto. Ambiente completo operante em ~5min.

## Regras pra você (Claude) manter a integridade

- ❌ NUNCA editar `~/.claude/scripts/` ou `~/.claude/skills/` sem refletir no projeto
- ❌ NUNCA hardcode paths absolutos de uma máquina específica (use `$HOME`, `command -v`, detecção runtime)
- ❌ NUNCA commitar `.env` ou segredos
- ❌ NUNCA deletar `dist/` dos MCPs sem rebuildar
- ✅ SEMPRE rodar `doctor.sh` após mudanças significativas
- ✅ SEMPRE atualizar `docs/` quando adicionar feature nova
- ✅ SEMPRE testar `install.sh` em ambiente fresco após grandes mudanças
- ✅ SEMPRE versionar novas skills dentro de `skills/` antes de usar

## Verificar se está saudável

```bash
bash doctor.sh
```

Saída esperada tem ~30 linhas com quase todas ✅. Qualquer ❌ → corrigir ou ver `docs/troubleshooting.md`.
