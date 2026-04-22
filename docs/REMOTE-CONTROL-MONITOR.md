# Remote Control Monitor — Setup Multi-Ambiente

Guia completo para instalar e operar o monitor automatizado do Remote Control em qualquer ambiente (servidor ou máquina local). Irmão deste doc: [`REMOTE-CONTROL.md`](./REMOTE-CONTROL.md) — explica o feature `/remote-control` em si.

## Visão geral

O **Remote Control Monitor** é um job periódico (systemd timer) que:

1. Lê todos os orquestradores registrados em `~/.claude/teams.json`
2. Inspeciona o rodapé da sessão tmux de cada um via `tmux capture-pane`
3. Classifica o estado (`ACTIVE`, `STUCK_CONNECTING`, `DISCONNECTED`, `NO_SESSION`)
4. Executa ação corretiva se necessário (disconnect + reconnect)
5. Envia alerta WhatsApp via Evolution API quando houve ação (opcional)

A cada 10 min o ciclo se repete. Idempotente: quando tudo está `ACTIVE`, é no-op.

### Arquivos envolvidos

| Path | Função |
|---|---|
| `/home/<user>/.claude/scripts/remote-control-monitor.sh` | script principal (bash) |
| `/home/<user>/.claude/remote-control-monitor.env` | variáveis de ambiente (configurável por usuário) |
| `/etc/systemd/system/remote-control-monitor.service` | systemd oneshot service |
| `/etc/systemd/system/remote-control-monitor.timer` | systemd timer (dispara a cada 10min) |
| `/home/<user>/.claude/logs/remote-control-monitor.log` | log de ticks |
| `/home/<user>/.claude/teams.json` | fonte da verdade dos orquestradores |
| `/home/<user>/.mcp.json` | credenciais Evolution API (pra WhatsApp) |

---

## Pré-requisitos

- Linux com `systemd` (Ubuntu 22.04+ / Debian 12+)
- `bash`, `jq`, `tmux`, `curl` instalados
- `~/.claude/teams.json` configurado com os projetos/teams
- Sessões tmux dos orquestradores criadas e com Claude Code rodando dentro
- (Opcional, pra WhatsApp) Evolution API acessível e configurada em `~/.mcp.json`

### Validar pré-requisitos

```bash
for cmd in bash jq tmux curl systemctl; do
  command -v "$cmd" >/dev/null && echo "OK: $cmd" || echo "MISSING: $cmd"
done

[ -f ~/.claude/teams.json ] && echo "OK: teams.json" || echo "MISSING: teams.json"
```

---

## Instalação passo a passo

### 1) Copiar o script

```bash
mkdir -p ~/.claude/scripts ~/.claude/logs
cp <origem>/remote-control-monitor.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/remote-control-monitor.sh
```

Se estiver replicando deste projeto:
```bash
scp ubuntu@<servidor>:~/.claude/scripts/remote-control-monitor.sh ~/.claude/scripts/
```

### 2) Criar o arquivo de variáveis

```bash
cat > ~/.claude/remote-control-monitor.env <<'EOF'
WHATSAPP_ENABLED=true
CLAUDE_ENV_PREFIX=cs
EOF
chmod 600 ~/.claude/remote-control-monitor.env
```

**Escolha um prefixo único** pro seu ambiente. Sugestões:

| Ambiente | Sugestão |
|---|---|
| Servidor compartilhado (ubuntu-claude-agents) | `cs` |
| Máquina local do Lee (MacBook) | `mac` |
| Laptop secundário | `lee` |
| Ambiente de teste | `dev` ou `lab` |

> **Regra de ouro**: prefixos distintos em cada ambiente — senão o `claude.ai/code` vê as sessões sobrepostas e um ambiente acaba "sobrescrevendo" o outro.

### 3) Criar os units systemd

```bash
sudo tee /etc/systemd/system/remote-control-monitor.service >/dev/null <<EOF
[Unit]
Description=Remote Control monitor dos orquestradores Claude Code
Documentation=file://$HOME/projects/i9-team/docs/REMOTE-CONTROL-MONITOR.md
After=network-online.target

[Service]
Type=oneshot
User=$USER
Group=$USER
Environment=HOME=$HOME
Environment=PATH=$(command -v node | xargs dirname):/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EnvironmentFile=-$HOME/.claude/remote-control-monitor.env
ExecStart=$HOME/.claude/scripts/remote-control-monitor.sh
TimeoutStartSec=5min
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/remote-control-monitor.timer >/dev/null <<EOF
[Unit]
Description=dispara monitor de Remote Control a cada 10min
Documentation=file://$HOME/projects/i9-team/docs/REMOTE-CONTROL-MONITOR.md

[Timer]
OnBootSec=1min
OnUnitActiveSec=10min
AccuracySec=30s
Unit=remote-control-monitor.service
Persistent=true

[Install]
WantedBy=timers.target
EOF
```

> Ajuste o path do `PATH` conforme sua instalação de node (o script usa `curl` e `jq`, mas é bom ter node se houver extensões futuras).

### 4) Habilitar e iniciar

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now remote-control-monitor.timer
sudo systemctl start remote-control-monitor.service   # primeiro tick manual
```

### 5) Validar o primeiro tick

```bash
tail -20 ~/.claude/logs/remote-control-monitor.log
```

Saída esperada (todos ACTIVE se já existia `/remote-control` nas sessões):

```
[2026-04-22T16:47:08Z] tick start (WHATSAPP_ENABLED=true, CLAUDE_ENV_PREFIX='cs')
[2026-04-22T16:47:08Z] [i9-team/dev] session=i9-team-dev-orquestrador state=ACTIVE
...
[2026-04-22T16:47:08Z] tick end duration=0s orchestrators=7
```

---

## Variáveis de ambiente

Todas configuráveis via `~/.claude/remote-control-monitor.env`.

| Nome | Default | Descrição |
|---|---|---|
| `WHATSAPP_ENABLED` | `true` | `true`/`false` — controla envio de alertas WhatsApp quando o monitor executa ação de reconectar |
| `CLAUDE_ENV_PREFIX` | (vazio) | Prefixo adicionado ao nome do Remote Control. Ex: `cs` → `cs-i9-team-dev-team-orchestrator`. Vazio = sem prefixo |

Hardcoded no script (pra mudar, edita diretamente):

| Nome | Default | Descrição |
|---|---|---|
| `STUCK_RECHECK_SECONDS` | `15` | Intervalo entre o 1º e 2º check de "connecting" pra evitar falso positivo |
| `WHATSAPP_NUMBER` | `5583988710328` | Destinatário fixo dos alertas |

---

## Múltiplos ambientes — padrão de prefixo

### Problema

Hoje, sem prefixo, o nome do Remote Control é composto só por `<project>-<team>-<orchestrator>`. Se **mais de um ambiente** (servidor + máquina local, por exemplo) rodar o mesmo `teams.json`, todos disputam os mesmos nomes no `claude.ai/code`. Resultado:

1. Usuário abre `i9-team-dev-team-orchestrator` no app Claude
2. Não sabe se está olhando a sessão do servidor ou da máquina local
3. Reconexões do monitor de um ambiente "roubam" o session_id do outro

### Solução

Cada ambiente define seu `CLAUDE_ENV_PREFIX` único:

```
Servidor (ubuntu-claude-agents):     CLAUDE_ENV_PREFIX=cs
Máquina local (MacBook):              CLAUDE_ENV_PREFIX=mac
```

No `claude.ai/code` as sessões aparecem assim:

```
cs-i9-team-dev-team-orchestrator       ← servidor
cs-i9-smart-pdv-dev-team-orchestrator  ← servidor
mac-i9-team-dev-team-orchestrator      ← máquina local
mac-i9-smart-pdv-dev-team-orchestrator ← máquina local
```

Cada uma com seu próprio `session_id`, sem colisão.

### Migrando um ambiente existente

Se você já tinha o monitor rodando sem prefixo e acabou de adicionar um, as sessões **permanecem com o nome antigo** até haver uma reconexão. Duas opções:

**Opção A — Natural**: Deixa o tempo passar. Quando algum Remote Control desconectar naturalmente, o próximo tick reconecta com prefixo novo. Todos migram em alguns dias.

**Opção B — Forçar rollover**: Desconecta todos de uma vez e o próximo tick reconecta com prefixo.

```bash
# Pra cada sessão orquestrador do teams.json
for session in $(jq -r '.projects[] | .name as $p | .teams[] | "\($p)-\(.name)-orquestrador"' ~/.claude/teams.json); do
  echo "Desconectando $session..."
  tmux send-keys -t "$session" -l "/remote-control"
  tmux send-keys -t "$session" Enter
  sleep 2
  tmux send-keys -t "$session" Up
  sleep 0.3
  tmux send-keys -t "$session" Up
  sleep 0.3
  tmux send-keys -t "$session" Enter
  sleep 1
done

# Aguarda o menu fechar e dispara monitor
sleep 15
sudo systemctl start remote-control-monitor.service
tail -30 ~/.claude/logs/remote-control-monitor.log
```

Você vai receber ~N alertas WhatsApp (um por orquestrador) confirmando a reconexão com o prefixo.

---

## Operação do dia a dia

### Disparar tick manual

```bash
sudo systemctl start remote-control-monitor.service
tail -20 ~/.claude/logs/remote-control-monitor.log
```

### Ver log em tempo real

```bash
tail -f ~/.claude/logs/remote-control-monitor.log
# ou via journald:
sudo journalctl -u remote-control-monitor.service -f
```

### Desativar WhatsApp temporariamente

```bash
sed -i 's/^WHATSAPP_ENABLED=.*/WHATSAPP_ENABLED=false/' ~/.claude/remote-control-monitor.env
# sem restart — próximo tick já lê
```

Reativar:
```bash
sed -i 's/^WHATSAPP_ENABLED=.*/WHATSAPP_ENABLED=true/' ~/.claude/remote-control-monitor.env
```

### Trocar o prefixo

```bash
sed -i 's/^CLAUDE_ENV_PREFIX=.*/CLAUDE_ENV_PREFIX=novoprefixo/' ~/.claude/remote-control-monitor.env
# Depois: rollover natural ou forçado (ver seção anterior)
```

### Pausar o timer

```bash
sudo systemctl stop remote-control-monitor.timer
# Pra retomar:
sudo systemctl start remote-control-monitor.timer
```

### Desinstalar

```bash
sudo systemctl disable --now remote-control-monitor.timer
sudo rm /etc/systemd/system/remote-control-monitor.{service,timer}
sudo systemctl daemon-reload
rm ~/.claude/scripts/remote-control-monitor.sh
rm ~/.claude/remote-control-monitor.env
```

---

## Troubleshooting

### Monitor reporta tudo como `DISCONNECTED` infinitamente

- **Causa**: texto do rodapé do Claude Code mudou entre versões (o script procura literal `Remote Control active`).
- **Diagnóstico**: `tmux capture-pane -t <sessão> -p | tail -5`
- **Solução**: atualizar os `grep` na função `classify_state` pro novo texto.

### Tudo aparece `STUCK_CONNECTING`, reconecta sem parar

- **Causa**: bug na sessão Claude Code ou sobrecarga de rede.
- **Diagnóstico**: entrar no tmux e executar `/remote-control` manual pra ver erro real.
- **Solução**: reiniciar a sessão Claude Code afetada (mantém tmux, só `/exit` + relançar).

### WhatsApp não chega

- **Diagnóstico**: `grep whatsapp ~/.claude/logs/remote-control-monitor.log | tail -5`
- **Possíveis causas**:
  - `WHATSAPP_ENABLED=false` (checar env)
  - Credenciais faltando no `~/.mcp.json` (`EVOLUTION_API_URL`, `EVOLUTION_API_KEY`, `EVOLUTION_DEFAULT_INSTANCE`)
  - Instância Evolution API desconectada
  - Número destinatário incorreto (hardcoded no script)

### Lock permanente em `/tmp/rc-monitor.lock`

- **Causa**: script morreu sem liberar o flock (raro — só acontece se kill -9).
- **Diagnóstico**: `lsof /tmp/rc-monitor.lock`
- **Solução**: `rm /tmp/rc-monitor.lock` (o script usa `flock -n`, não é problema real; o next tick vai criar de novo)

### Timer não dispara

- `sudo systemctl status remote-control-monitor.timer` — precisa estar `active (waiting)`
- `sudo journalctl -u remote-control-monitor.timer -n 30` — últimos eventos
- Se não estiver enabled: `sudo systemctl enable --now remote-control-monitor.timer`

---

## Arquitetura do classify

O coração do script é a função `classify_state`. Ela recebe um nome de sessão tmux e retorna um dos 4 estados:

```
        ┌────────────────┐
        │ capture-pane   │
        │    tail -5     │
        └────────┬───────┘
                 │
        ┌────────▼────────────────┐
        │ grep "Remote Control    │  → match → ACTIVE
        │       active"           │
        └────────┬────────────────┘
                 │ no match
        ┌────────▼────────────────┐
        │ grep "Remote Control    │  → no match → DISCONNECTED
        │       connecting…"      │
        └────────┬────────────────┘
                 │ match
        ┌────────▼────────────────┐
        │ sleep 15s + re-capture  │
        │ grep "active" de novo   │
        └───┬────────────┬────────┘
            │ match      │ no match
         ACTIVE      STUCK_CONNECTING
```

Isso elimina falso positivo quando a conexão **está sendo estabelecida** (demora alguns segundos entre `connecting…` e `active`).

---

## Segurança

- O arquivo `~/.claude/remote-control-monitor.env` deve ser **600** (só owner lê/escreve) — não contém secrets hoje, mas é boa prática caso futuramente passe a conter
- O número WhatsApp hoje é hardcoded no script — pra ambientes distintos com destinatários diferentes, mover pra env var é trivial (`WHATSAPP_NUMBER="${WHATSAPP_NUMBER:-5583988710328}"`)
- Evolution API `apikey` é lida via `jq` do `~/.mcp.json` — mesma credencial usada pelos MCPs da conta
- O flock em `/tmp/rc-monitor.lock` garante que ticks não se sobreponham (importante em ambientes com alta concorrência de cron/systemd)

---

## Referências

- Script: `~/.claude/scripts/remote-control-monitor.sh`
- Doc do feature `/remote-control`: [REMOTE-CONTROL.md](./REMOTE-CONTROL.md)
- Setup geral do servidor: [CLAUDE-SERVER-SETUP.md](./CLAUDE-SERVER-SETUP.md)
- Teams: [TEAMS-SETUP.md](./TEAMS-SETUP.md)
