# Troubleshooting

Problemas conhecidos e soluções. Primeira coisa sempre: rodar `bash doctor.sh`.

## Instalação

### ❌ `Claude bin não encontrado`
```bash
# Instalar via npm global
npm install -g @anthropic-ai/claude-code

# Ou via NVM + reload do PATH
nvm use 24
export PATH="$HOME/.nvm/versions/node/v24.x/bin:$PATH"
```

Depois: re-rodar `install.sh`.

### ❌ systemd: "tmux server not found" no boot
**Causa:** systemd não carrega `.bashrc`, então NVM não está no PATH → claude não roda → tmux morre junto.

**Fix aplicado no `team-boot.sh`:**
```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
```

Se ainda falhar, editar unit e adicionar `Environment=PATH=...`:
```bash
sudo systemctl edit claude-teams.service
# adicionar:
# [Service]
# Environment="PATH=/home/ubuntu/.nvm/versions/node/v24.x/bin:/usr/bin:/bin"
```

### ❌ Load CPU > 160 no boot
**Causa:** todos os agentes iniciando em rajada (se 20+ projetos).

**Fix aplicado:** `START_ALL_DELAY=5` no `team.sh start-all` → espaça 5s entre agentes.

Se ainda alto, aumentar no `.env`:
```bash
START_ALL_DELAY=10
```

### ❌ `psutil` não instala (macOS)
```bash
# Se brew python3
brew install python@3.11
pip3 install --user psutil

# Ou via pipx
brew install pipx
pipx install psutil
```

## Monitoring

### ❌ Grafana vazio (sem dados)

1. Verificar se o `.prom` existe e é recente:
   ```bash
   ls -la /var/lib/node_exporter/textfile_collector/claude_agents.prom
   # Linux; no macOS: /usr/local/var/...
   ```

2. Se vazio ou inexistente:
   ```bash
   python3 .claude-ops/monitoring/scripts/claude-metrics.py -v
   ```

3. Se gera mas Prometheus não scrapea, conferir:
   ```bash
   curl http://localhost:9100/metrics | grep claude_
   ```

4. No Grafana, verificar datasource:
   - Settings → Data sources → Prometheus → Save & Test

### ❌ "Error loading textfile" no node_exporter
**Causa:** permissão no diretório textfile_collector.

```bash
sudo chown $USER:$USER /var/lib/node_exporter/textfile_collector
```

### ❌ Métricas param de atualizar
```bash
# Ver status do timer
systemctl status claude-metrics.timer  # Linux
launchctl list | grep com.claude       # macOS

# Rodar manualmente pra ver erro
python3 ~/monitoring/scripts/claude-metrics.py -v
```

### ❌ Grafana dashboard JSON com erro "datasource uid"
Dashboards referenciam `uid: prometheus-ds`. Se mudou:
1. Editar `grafana/provisioning/datasources/prometheus.yml`:
   ```yaml
   uid: prometheus-ds  # bate com os dashboards
   ```
2. `docker compose restart grafana`

## Teams tmux

### ❌ Sessão existe mas claude morreu
```bash
tmux attach -t <nome>
# Se mostra shell vazio: claude crashou
# Ver logs:
tmux capture-pane -t <nome> -p -S -500 | less
```

Provavelmente erro de MCP. Checar `.mcp.json` + builds.

### ❌ `/team-protocol` não foi aplicado
O `team.sh` injeta 2× com 10s de intervalo. Se nada carrega:

1. Garantir que a skill existe: `ls ~/.claude/skills/team-protocol/SKILL.md`
2. Garantir que o agente foi criado: `ls <projeto>/.claude/agents/`

### ❌ Múltiplas sessões mesmo team
```bash
~/.claude/scripts/team.sh stop <projeto> <team>
# Aguarda limpar, depois:
~/.claude/scripts/team.sh start <projeto> <team>
```

## MCPs

### ❌ MCP não aparece no Claude
- Reiniciar sessão (sair e abrir de novo no projeto)
- Verificar build: `ls ~/mcp-servers/<mcp>/dist/index.js`
- Se faltar: `cd ~/mcp-servers/<mcp> && npm install && npm run build`

### ❌ `i9-agent-memory` falha ao iniciar
**Causa mais comum:** Postgres não está acessível.

```bash
# Verificar container
docker ps | grep agent-memory-pg

# Se não rodando:
docker start agent-memory-pg

# Testar conexão:
psql "postgresql://agent:agent123@localhost:5432/agent_memory" -c '\dt'
```

### ❌ `evolution-api` 401 Unauthorized
API key errada no `.mcp.json`. Regenerar e atualizar.

## Remote Control

### ❌ Monitor trava em "connecting"
Conexão RC precisa 10s+. O monitor aguarda 15s e re-checa. Se ainda falha:

1. Entrar manualmente: `tmux attach -t <orquestrador>`
2. `/remote-control` → menu Disconnect
3. `/remote-control <nome>` → reconectar
4. Ver se dá erro no terminal

### ❌ WhatsApp não chega
Ver [docs/whatsapp-alerting.md](whatsapp-alerting.md) — seção troubleshooting.

## Limpeza

### Reset completo (apaga dados)
```bash
# 1. Parar tudo
cd .claude-ops && bash uninstall.sh

# 2. Remover dados Postgres
docker rm -f agent-memory-pg

# 3. Remover buildds MCP
rm -rf ~/mcp-servers/*/dist ~/mcp-servers/*/node_modules

# 4. Re-instalar do zero
bash install.sh
```

### Limpar logs velhos
```bash
# Linux
find /tmp -name "claude-*.log" -mtime +7 -delete
find $HOME/.claude/logs -name "*.log" -mtime +30 -delete

# macOS
find /tmp -name "claude-*.log" -mtime +7 -delete
```

## Coletar diagnóstico pra report de bug

```bash
{
  echo "=== doctor.sh ==="
  bash .claude-ops/doctor.sh
  echo "=== teams.json ==="
  jq . ~/.claude/teams.json
  echo "=== .mcp.json projeto atual ==="
  jq . .mcp.json
  echo "=== container ps ==="
  docker ps
  echo "=== tmux ls ==="
  tmux ls
  echo "=== últimas métricas ==="
  tail -30 /var/lib/node_exporter/textfile_collector/claude_agents.prom 2>/dev/null
} > /tmp/claude-ops-diag.txt

# Compartilhar /tmp/claude-ops-diag.txt (remover API keys antes!)
```
