# Instalação do Remote Control Monitor — Prompt pro Claude Code

> **Como usar**: copie TUDO a partir da linha marcada `===PROMPT-BEGIN===` até `===PROMPT-END===` e cole como mensagem no Claude Code da máquina onde quer instalar. Claude vai executar os passos automaticamente, perguntando o prefixo e outras decisões pontuais.

---

===PROMPT-BEGIN===

# Instale o Remote Control Monitor nesta máquina

Você é o Claude Code rodando na máquina local do Lee. Sua tarefa é instalar o Remote Control Monitor seguindo o padrão do projeto `i9-team`, usando os assets de referência já presentes em `docs/remote-control-monitor/` do repo.

## Contexto que você precisa saber

- **O monitor já roda** no servidor compartilhado (`ubuntu-claude-agents`) com `CLAUDE_ENV_PREFIX=cs`. Isso significa que no `claude.ai/code` todas as sessões do servidor aparecem como `cs-<project>-<team>-<orchestrator>`.
- **Esta máquina precisa** rodar o monitor com um prefixo **diferente** — senão as sessões colidem no `claude.ai/code` e um ambiente "rouba" a sessão do outro.
- **Doc conceitual completa**: `docs/REMOTE-CONTROL-MONITOR.md`
- **Assets pra copiar**: `docs/remote-control-monitor/`
  - `remote-control-monitor.sh` (script bash)
  - `remote-control-monitor.service` (systemd unit — template)
  - `remote-control-monitor.timer` (systemd timer)
  - `remote-control-monitor.env.example` (template do arquivo de env)

## Comportamento esperado

Pergunte o que for necessário, valide cada passo, reporte no fim. Não assuma — confirme com o usuário em pontos críticos (prefixo, WhatsApp habilitado, número do WhatsApp se mudar). Use o skill `/commit` pra qualquer commit que decidir fazer.

## Passo 1 — Detectar ambiente

Execute e mostre ao usuário:

```bash
uname -srm
command -v systemctl && echo "SYSTEMD_OK" || echo "SYSTEMD_MISSING"
command -v launchctl && echo "LAUNCHD_OK" || echo "LAUNCHD_MISSING"
for cmd in bash jq tmux curl; do
  command -v "$cmd" >/dev/null && echo "OK: $cmd" || echo "MISSING: $cmd"
done
[ -f ~/.claude/teams.json ] && echo "OK: teams.json" || echo "MISSING: teams.json"
tmux ls 2>/dev/null | grep -c orquestrador || echo "0 orquestradores tmux"
```

Se faltar `jq`, `tmux`, `curl`: instalar antes de continuar.
- Linux: `sudo apt install jq tmux curl` ou `sudo yum install jq tmux curl`
- macOS: `brew install jq tmux curl`

Se `teams.json` não existir: NÃO continuar. Avisar que precisa ter os teams configurados primeiro (ver `docs/TEAMS-SETUP.md` no repo).

Se 0 sessões orquestrador tmux: avisar. O monitor pode ser instalado mesmo assim, mas vai ficar reportando `NO_SESSION` até subir os teams.

## Passo 2 — Perguntar o prefixo de ambiente

Pergunte ao usuário:

> "Qual prefixo usar para este ambiente? (curto, minúsculo, sem hífen). Sugestões:
> - `mac` se for macOS
> - `wsl` se for WSL
> - `lin` se for Linux desktop
> - outro de sua escolha
> 
> O servidor compartilhado usa `cs` — **não use `cs` aqui**, senão as sessões vão colidir."

Guarde a resposta como variável `PREFIX`.

Valide: `PREFIX` deve ser `[a-z]+` (só letras minúsculas, sem espaços/hífen), diferente de `cs`, e ter no máximo 10 caracteres.

## Passo 3 — Perguntar sobre WhatsApp

Pergunte ao usuário:

> "Habilitar notificações WhatsApp quando o monitor reconectar algum orquestrador? (s/n)
> 
> Se sim: confirmar se é pra usar o número padrão `5583988710328` ou trocar."

Se habilitado e quiser trocar número: pedir o novo número no formato `E.164` sem `+` (ex: `5511987654321`).
Se habilitado: verificar se `~/.mcp.json` tem as credenciais Evolution API:
```bash
jq -e '.mcpServers."evolution-api".env.EVOLUTION_API_URL and
       .mcpServers."evolution-api".env.EVOLUTION_API_KEY and
       .mcpServers."evolution-api".env.EVOLUTION_DEFAULT_INSTANCE' ~/.mcp.json >/dev/null \
  && echo "EVO_CREDS_OK" || echo "EVO_CREDS_MISSING"
```
Se faltar: avisar e oferecer configurar depois (deixar `WHATSAPP_ENABLED=false` por enquanto).

## Passo 4 — Copiar o script

```bash
mkdir -p ~/.claude/scripts ~/.claude/logs
cp docs/remote-control-monitor/remote-control-monitor.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/remote-control-monitor.sh
```

Se o usuário trocou o número WhatsApp (Passo 3), editar a variável `WHATSAPP_NUMBER` no topo do script copiado:
```bash
sed -i.bak "s/^WHATSAPP_NUMBER=.*/WHATSAPP_NUMBER=\"<NOVO_NUMERO>\"/" ~/.claude/scripts/remote-control-monitor.sh
```
(no macOS o `sed -i` requer sufixo obrigatório, já está com `.bak`)

## Passo 5 — Criar arquivo de env

```bash
cat > ~/.claude/remote-control-monitor.env <<EOF
WHATSAPP_ENABLED=<true-ou-false-do-passo-3>
CLAUDE_ENV_PREFIX=<PREFIX-do-passo-2>
EOF
chmod 600 ~/.claude/remote-control-monitor.env
cat ~/.claude/remote-control-monitor.env
```

## Passo 6 — Instalar o agendador

### Se systemd (Linux)

```bash
# Ajusta o service unit pro usuário/PATH local
USER_HOME="$HOME"
USER_NAME="$(whoami)"
NODE_BIN_DIR="$(command -v node 2>/dev/null | xargs dirname 2>/dev/null || echo /usr/local/bin)"

sudo tee /etc/systemd/system/remote-control-monitor.service >/dev/null <<UNIT
[Unit]
Description=Remote Control monitor dos orquestradores Claude Code
Documentation=file://$USER_HOME/projects/i9-team/docs/REMOTE-CONTROL-MONITOR.md
After=network-online.target

[Service]
Type=oneshot
User=$USER_NAME
Group=$USER_NAME
Environment=HOME=$USER_HOME
Environment=PATH=$NODE_BIN_DIR:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EnvironmentFile=-$USER_HOME/.claude/remote-control-monitor.env
ExecStart=$USER_HOME/.claude/scripts/remote-control-monitor.sh
TimeoutStartSec=5min
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

sudo cp docs/remote-control-monitor/remote-control-monitor.timer /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable --now remote-control-monitor.timer
```

### Se launchd (macOS)

Criar um plist equivalente:

```bash
mkdir -p ~/Library/LaunchAgents
cat > ~/Library/LaunchAgents/com.i9team.remote-control-monitor.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.i9team.remote-control-monitor</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-lc</string>
    <string>source ~/.claude/remote-control-monitor.env 2>/dev/null; ~/.claude/scripts/remote-control-monitor.sh</string>
  </array>
  <key>StartInterval</key>
  <integer>600</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$HOME/.claude/logs/remote-control-monitor.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>$HOME/.claude/logs/remote-control-monitor.stderr.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key>
    <string>$HOME</string>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
</dict>
</plist>
PLIST

# Substitui $HOME literal pelo valor real
sed -i.bak "s|\$HOME|$HOME|g" ~/Library/LaunchAgents/com.i9team.remote-control-monitor.plist

launchctl unload ~/Library/LaunchAgents/com.i9team.remote-control-monitor.plist 2>/dev/null
launchctl load ~/Library/LaunchAgents/com.i9team.remote-control-monitor.plist
```

**Nota macOS**: se a primeira execução falhar com erro de permissão pra `tmux capture-pane`, macOS pode estar bloqueando o launchd de acessar terminais. Vai em `System Settings → Privacy & Security → Full Disk Access` e adicione `/bin/bash` ou o terminal que você usa.

## Passo 7 — Tick manual de validação

### Linux
```bash
sudo systemctl start remote-control-monitor.service
sleep 3
tail -20 ~/.claude/logs/remote-control-monitor.log
```

### macOS
```bash
launchctl kickstart -k gui/$UID/com.i9team.remote-control-monitor
sleep 3
tail -20 ~/.claude/logs/remote-control-monitor.log
```

**Validação esperada**: log deve começar com uma linha tipo:
```
[2026-MM-DDTHH:MM:SSZ] tick start (WHATSAPP_ENABLED=true, CLAUDE_ENV_PREFIX='<SEU_PREFIX>')
```

Se `CLAUDE_ENV_PREFIX` aparecer vazio (`''`), o env file não foi lido corretamente — debug:
- Verificar `cat ~/.claude/remote-control-monitor.env`
- No systemd: checar `EnvironmentFile=-` tem o `-` e o path está correto
- No launchd: a linha `source ~/.claude/remote-control-monitor.env` está no `ProgramArguments`

## Passo 8 — Reportar resultado ao usuário

Formato sugerido:

```
✅ Remote Control Monitor instalado nesta máquina

Ambiente: <PREFIX> (hostname: <hostname>)
WhatsApp: <habilitado|desabilitado>
Orquestradores detectados no teams.json: <N>
  - ACTIVE: <K>
  - DISCONNECTED: <L> (serão reconectados com prefixo <PREFIX> no próximo tick)
Agendamento: <systemd-timer a cada 10min | launchd a cada 600s>
Log: ~/.claude/logs/remote-control-monitor.log
```

## Operação pós-instalação

- **Ver log ao vivo**: `tail -f ~/.claude/logs/remote-control-monitor.log`
- **Tick manual**: `sudo systemctl start remote-control-monitor.service` (linux) ou `launchctl kickstart -k gui/$UID/com.i9team.remote-control-monitor` (macOS)
- **Desabilitar WhatsApp**: `sed -i.bak 's/^WHATSAPP_ENABLED=.*/WHATSAPP_ENABLED=false/' ~/.claude/remote-control-monitor.env`
- **Trocar prefixo**: edite `~/.claude/remote-control-monitor.env`. Próximo disconnect vai reconectar com o novo nome.

## Quando algo der errado

Consulte a seção **Troubleshooting** de `docs/REMOTE-CONTROL-MONITOR.md`. Casos comuns:

- Monitor reporta tudo `DISCONNECTED` infinito → texto do rodapé do Claude Code mudou, ajustar grep
- `STUCK_CONNECTING` infinito → sessão Claude com problema real, reiniciar manualmente
- WhatsApp não chega → checar env file e credenciais Evolution

===PROMPT-END===
