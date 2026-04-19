# Claude Server Setup — Ubuntu 10.0.10.17

Playbook completo para configurar um servidor Ubuntu como host de teams Claude Code com MCPs.

---

## Especificações do Servidor

| Item | Valor |
|------|-------|
| IP | 10.0.10.17 |
| User | ubuntu |
| OS | Ubuntu 22.04 LTS |
| Rede | 10.0.10.0/24 (Main) |
| Acesso | SSH via chave `~/.ssh/id_rsa` |

---

## 1. Node.js via nvm

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install 24
nvm use 24
nvm alias default 24
node --version  # v24.x.x
```

> ⚠️ Sessões não-interativas (SSH, tmux, Claude) não carregam nvm automaticamente.
> Sempre usar path absoluto: `/home/ubuntu/.nvm/versions/node/v24.15.0/bin/node`

---

## 2. Claude Code CLI

```bash
/home/ubuntu/.nvm/versions/node/v24.15.0/bin/npm install -g @anthropic-ai/claude-code
claude --version
claude # fazer login interativo uma vez
```

---

## 3. GitHub CLI (gh)

```bash
# Instalar via binário (apt falha com Malformed entry)
cd /tmp
wget https://github.com/cli/cli/releases/download/v2.67.0/gh_2.67.0_linux_amd64.tar.gz
tar xzf gh_2.67.0_linux_amd64.tar.gz
sudo mv gh_2.67.0_linux_amd64/bin/gh /usr/local/bin/

# Autenticar com token
echo '<TOKEN>' | gh auth login --with-token
gh auth setup-git
```

---

## 4. Docker + pgvector

```bash
# Instalar Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu

# Subir pgvector
sudo docker run -d \
  --name pgvector \
  --restart unless-stopped \
  -e POSTGRES_DB=agent_memory \
  -e POSTGRES_USER=agent \
  -e POSTGRES_PASSWORD=agent123 \
  -p 5432:5432 \
  pgvector/pgvector:pg16

# Habilitar extensão
sleep 5
sudo docker exec pgvector psql -U agent -d agent_memory -c 'CREATE EXTENSION IF NOT EXISTS vector;'
```

---

## 5. MCP Servers

```bash
# Clonar repositório
cd /home/ubuntu
git clone git@github.com:Inoveon/mcp-servers.git mcp-servers

# Build dos MCPs necessários
cd mcp-servers
for mcp in i9-team i9-agent-memory evolution-api; do
  echo "Building $mcp..."
  cd $mcp && npm install && npm run build && cd ..
done
```

### Configuração `~/.mcp.json`

```json
{
  "mcpServers": {
    "i9-team": {
      "command": "/home/ubuntu/.nvm/versions/node/v24.15.0/bin/node",
      "args": ["/home/ubuntu/mcp-servers/i9-team/dist/index.js"]
    },
    "i9-agent-memory": {
      "command": "/home/ubuntu/.nvm/versions/node/v24.15.0/bin/node",
      "args": ["/home/ubuntu/mcp-servers/i9-agent-memory/dist/index.js"],
      "env": {
        "VAULT_NAME": "i9-smart-pdv",
        "VAULT_PATH": "/home/ubuntu/projects/i9-smart-pdv/.memory",
        "DATABASE_URL": "postgresql://agent:agent123@localhost:5432/agent_memory"
      }
    },
    "i9-agent-memory-team": {
      "command": "/home/ubuntu/.nvm/versions/node/v24.15.0/bin/node",
      "args": ["/home/ubuntu/mcp-servers/i9-agent-memory/dist/index.js"],
      "env": {
        "VAULT_NAME": "i9-team",
        "VAULT_PATH": "/home/ubuntu/projects/i9-team/.memory",
        "DATABASE_URL": "postgresql://agent:agent123@localhost:5432/agent_memory"
      }
    },
    "evolution-api": {
      "command": "/home/ubuntu/.nvm/versions/node/v24.15.0/bin/node",
      "args": ["/home/ubuntu/mcp-servers/evolution-api/dist/index.js"]
    }
  }
}
```

---

## 6. Configuração Claude (`~/.claude/`)

### `~/.claude/settings.json`

```json
{
  "permissions": {
    "defaultMode": "bypassPermissions",
    "allow": [
      "Bash", "Read", "Write", "Edit", "Glob", "Grep",
      "Skill", "WebSearch", "Agent", "TodoWrite",
      "mcp__i9-team__*",
      "mcp__i9-agent-memory__*",
      "mcp__evolution-api__*"
    ]
  }
}
```

### `~/.claude/teams.json`

Ver `docs/TEAMS-SETUP.md` para estrutura completa.

### Skills

```bash
# Copiar skills do Mac para o servidor
rsync -avz ~/.claude/skills/ ubuntu@10.0.10.17:~/.claude/skills/
```

### Scripts

```bash
# Copiar scripts de gerenciamento de teams
rsync -avz ~/.claude/scripts/ ubuntu@10.0.10.17:~/.claude/scripts/
chmod +x ~/.claude/scripts/*.sh
```

---

## 7. Projetos

```bash
mkdir -p /home/ubuntu/projects
cd /home/ubuntu/projects

# i9-team Portal
git clone https://github.com/Inoveon/i9-team.git i9-team

# i9-smart-pdv (com submódulos)
git clone --recurse-submodules https://github.com/Inoveon/i9_smart_pdv_web.git i9-smart-pdv
# Se já clonado sem submodules:
# cd i9-smart-pdv && git submodule update --init --recursive

# proxmox-infrastructure
git clone https://github.com/Inoveon/proxmox-infrastructure.git proxmox-infrastructure
```

---

## 8. Verificação Final

```bash
# Checar todas as sessões tmux
~/.claude/scripts/team.sh status

# Testar MCP i9-agent-memory
DATABASE_URL='postgresql://agent:agent123@localhost:5432/agent_memory' \
VAULT_NAME='i9-smart-pdv' \
VAULT_PATH='/home/ubuntu/projects/i9-smart-pdv/.memory' \
/home/ubuntu/.nvm/versions/node/v24.15.0/bin/node \
  /home/ubuntu/mcp-servers/i9-agent-memory/dist/index.js &
sleep 3 && kill %1

# Docker
sudo docker ps
```

---

## Acesso via Termius

| Label | Start Command |
|-------|--------------|
| `🤖 i9-team orquestrador` | `tmux attach -t i9-team-dev-orquestrador` |
| `🏪 i9-smart-pdv orquestrador` | `tmux attach -t i9-smart-pdv-dev-orquestrador` |
| `🖥️ proxmox orquestrador` | `tmux attach -t proxmox-infrastructure-infra-orquestrador` |

---

## Troubleshooting

| Problema | Solução |
|----------|---------|
| `node: command not found` no tmux | Usar path absoluto `/home/ubuntu/.nvm/versions/node/v24.15.0/bin/node` |
| Submodules clonando via HTTPS sem auth | `git config --global url.'git@github.com:'.insteadOf 'https://github.com/'` |
| Docker sem permissão | `sudo usermod -aG docker ubuntu` + nova sessão SSH |
| pgvector não conecta | `sudo docker ps` + checar se container `pgvector` está `Up` |
