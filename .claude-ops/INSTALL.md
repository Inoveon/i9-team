# Instalação detalhada — Claude Ops

Passo-a-passo caso prefira instalar manualmente ou `install.sh` falhe.

---

## Pré-requisitos

### Linux (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install -y tmux jq docker.io docker-compose-plugin python3 python3-pip git
pip3 install --user psutil
```

### macOS (Homebrew)
```bash
brew install tmux jq docker python3 git node
pip3 install --user psutil
# Docker Desktop necessário — baixar em https://docker.com/products/docker-desktop
```

### Node + Claude Code
```bash
# NVM (opcional, mas recomendado)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
nvm install 24
nvm use 24

# Claude Code
npm install -g @anthropic-ai/claude-code
claude --version
```

---

## Instalação automatizada

```bash
cd .claude-ops
cp templates/.env.example .env
nano .env  # preencha suas credenciais
bash install.sh
```

---

## Instalação manual (passo a passo)

### 1. Clonar mcp-servers

```bash
git clone git@github.com:Inoveon/mcp-servers.git ~/mcp-servers
cd ~/mcp-servers
for d in */; do
  [ -f "$d/package.json" ] && (cd "$d" && npm install && npm run build)
done
```

### 2. Postgres pgvector

```bash
docker run -d --name agent-memory-pg \
  -e POSTGRES_USER=agent \
  -e POSTGRES_PASSWORD=agent123 \
  -e POSTGRES_DB=agent_memory \
  -p 5432:5432 \
  --restart unless-stopped \
  pgvector/pgvector:pg16
```

### 3. Copiar scripts e skills pro Claude global

```bash
cd .claude-ops
bash sync-to-claude.sh
```

### 4. Diretório textfile_collector

Linux:
```bash
sudo mkdir -p /var/lib/node_exporter/textfile_collector
sudo chown $USER:$USER /var/lib/node_exporter/textfile_collector
```

macOS:
```bash
mkdir -p /usr/local/var/node_exporter/textfile_collector
```

### 5. Systemd units (Linux)

```bash
cd .claude-ops
for unit in claude-teams.service claude-metrics.service claude-metrics.timer; do
  sed "s|{HOME}|$HOME|g" "systemd/$unit" | sudo tee "/etc/systemd/system/$unit" > /dev/null
done
sudo systemctl daemon-reload
sudo systemctl enable --now claude-teams.service
sudo systemctl enable --now claude-metrics.timer
```

### 6. Launchd agents (macOS)

```bash
cd .claude-ops
LA="$HOME/Library/LaunchAgents"
mkdir -p "$LA"
for tmpl in launchd/*.plist.tmpl; do
  name=$(basename "$tmpl" .tmpl)
  sed "s|{HOME}|$HOME|g" "$tmpl" > "$LA/$name"
  launchctl load "$LA/$name"
done
```

### 7. Stack monitoring

```bash
cd .claude-ops/monitoring
docker compose up -d
```

Aguarde ~30s pro Grafana subir. Acesse:
- http://localhost:3000 (admin / admin123)
- http://localhost:9090

### 8. teams.json

```bash
cp templates/teams.json.example ~/.claude/teams.json
nano ~/.claude/teams.json  # preencha com seus projetos
```

### 9. Validação

```bash
bash doctor.sh
```

Deve mostrar tudo ✅. Qualquer ❌ → ver `docs/troubleshooting.md`.

---

## Preparar um projeto pra team

Depois da instalação base, pra cada projeto que queira usar:

### Via skill (recomendado)

No Claude Code dentro do projeto:
```
/team-setup <nome> [tipo]
```

Tipos: `dev-fullstack | dev-web | dev-mobile | pdv | service | infra | issues`

### Manualmente

Seguir: `skills/team-setup/SKILL.md` seção "Procedimento — projeto existente".

---

## Desinstalação

```bash
cd .claude-ops
bash uninstall.sh
```

Remove: systemd units, launchd plists, containers monitoring.
**Preserva**: `~/.claude/scripts`, `~/.claude/skills`, `~/mcp-servers`, `agent-memory-pg`.

Para remover tudo completamente:
```bash
bash uninstall.sh
docker rm -f agent-memory-pg
rm -rf ~/mcp-servers ~/.claude/scripts ~/.claude/skills/{team-*,mcp-setup}
```

---

## Reinstalar (ambiente novo)

Basta copiar este diretório `.claude-ops/` pro novo ambiente e rodar:

```bash
cp .env.example .env  # se não tiver ainda
bash install.sh
```

Tudo que esteja no `.env` + repositórios + builds + containers são reconfigurados do zero.
