# WhatsApp Alerting — Evolution API

## Como funciona

O `remote-control-monitor.sh` lê credenciais Evolution API diretamente do `~/.mcp.json` e envia mensagens via `curl` para a API REST.

## Pré-requisitos

1. Evolution API v2.3.7+ rodando em algum host acessível (https)
2. Instância conectada a WhatsApp (QR code escaneado)
3. API Key válida

## Configuração

### No `~/.mcp.json`
```json
{
  "mcpServers": {
    "evolution-api": {
      "command": "node",
      "args": [".../evolution-api/dist/index.js"],
      "env": {
        "EVOLUTION_API_URL": "https://evolution.inoveon.com.br",
        "EVOLUTION_API_KEY": "sua-api-key-aqui",
        "EVOLUTION_DEFAULT_INSTANCE": "LEE_65992905301_CLARO",
        "EVOLUTION_DEFAULT_DELAY": "1200",
        "EVOLUTION_TIMEOUT": "30000"
      }
    }
  }
}
```

### No script `remote-control-monitor.sh`
Linha 29:
```bash
WHATSAPP_NUMBER="5583988710328"  # formato: <país><ddd><número>
```

Pra trocar o número de destino:
```bash
# Edite a linha ou exporte a variável
export WHATSAPP_NUMBER="5511999999999"
bash ~/.claude/scripts/remote-control-monitor.sh
```

## Formato da mensagem

```
✅ Remote Control — ação executada

📍 i9-team / dev
🧭 team-orchestrator
⚠️ Estado anterior: DISCONNECTED
📌 Resultado: ACTIVE
🔗 https://claude.ai/code/session_abc123xyz
🏷️ i9-team-dev-team-orchestrator
⏰ 2026-04-21 14:30:45 UTC
```

Ícones dinâmicos:
- `✅` = reconectou com sucesso
- `❌` = falhou em reconectar (investigar logs)

## Quando notifica

Apenas quando o script executa **ação**:
- `ACTIVE` → nada (silêncio)
- `STUCK_CONNECTING` → notifica (reset + reconnect)
- `DISCONNECTED` → notifica (reconnect)
- `NO_SESSION` → nada (só loga warning)

## Testar manualmente

```bash
# Forçar notificação de teste:
curl -sS -X POST "https://evolution.inoveon.com.br/message/sendText/LEE_65992905301_CLARO" \
  -H "apikey: bf696d6c2fb3a301e0b45d475c2e26efc4607726bdbc8f3687950c47f51ba9c4" \
  -H "Content-Type: application/json" \
  -d '{"number":"5511999999999","text":"🧪 Teste Claude Ops"}'
```

Resposta esperada: `{"status":"PENDING",...}`.

## Troubleshooting

| Sintoma | Causa provável | Fix |
|---------|----------------|-----|
| "whatsapp_FAILED resp=..." no log | API Key errada | Verificar `EVOLUTION_API_KEY` |
| Status "PENDING" mas nada chega | Instância desconectada | Escanear QR code novamente na UI Evolution |
| Timeout | Host Evolution inacessível | Verificar DNS/firewall |
| "Evolution config ausente" | `~/.mcp.json` sem bloco evolution-api | Criar bloco ou editar variáveis |

## Log

`~/.claude/logs/remote-control-monitor.log`:

```
[2026-04-21T14:30:45Z] tick start
[2026-04-21T14:30:45Z] [i9-team/dev] session=i9-team-dev-orquestrador state=DISCONNECTED
[2026-04-21T14:30:45Z] [i9-team/dev] action=connect (as 'i9-team-dev-team-orchestrator')
[2026-04-21T14:30:55Z] [i9-team/dev] result=ACTIVE session_id=abc123xyz
[2026-04-21T14:30:55Z] whatsapp_sent to=5583988710328
[2026-04-21T14:30:55Z] tick end duration=10s orchestrators=5
```

## Customizar destinatário por projeto

Hoje o script manda sempre pro mesmo número. Se quiser notificação diferente por projeto:

```bash
# No script, substituir linha do WHATSAPP_NUMBER por:
case "$project" in
  i9-team)     WHATSAPP_NUMBER="5583988710328" ;;
  i9-smart-pdv) WHATSAPP_NUMBER="5511987654321" ;;
  *)           WHATSAPP_NUMBER="5583988710328" ;;  # default
esac
```

## Desabilitar notificações

Para silenciar sem mexer no script:

**Linux:**
```bash
sudo systemctl stop claude-rc-monitor.timer  # se criado
# ou remover do crontab
crontab -e  # comentar linha
```

**macOS:**
```bash
launchctl unload ~/Library/LaunchAgents/com.claude.rc-monitor.plist
```
