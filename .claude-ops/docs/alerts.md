# Alertas Prometheus

Definidos em `prometheus/rules/claude_projects.yml`, grupo `claude_resource_alerts`.

## Alertas ativos

### `ClaudeAgentHighCPU`
- **Expressão:** `claude_agent:cpu_rate1m > 0.80`
- **For:** `2m`
- **Severity:** `warning`
- **Disparo:** um agente usando >80% de 1 core por mais de 2 minutos
- **Ação sugerida:** investigar o que o agente está fazendo (loop infinito? thinking demorado?)

### `ClaudeAgentHighMemory`
- **Expressão:** `claude_agent:memory_rss_mib > 1536`
- **For:** `5m`
- **Severity:** `warning`
- **Disparo:** um agente com >1.5 GiB RSS por 5 minutos
- **Ação sugerida:** reiniciar o agente (memória provavelmente com leak acumulado)

### `ClaudeProjectHighMemory`
- **Expressão:** `claude_project:memory_rss_mib:sum > 8192`
- **For:** `5m`
- **Severity:** `critical`
- **Disparo:** soma de todos os agentes de um projeto passando 8 GiB
- **Ação sugerida:** parar o team, investigar vazamentos, considerar downsize

## Notificação

Alertas Prometheus por si só não enviam — precisam de Alertmanager ou webhook. Este stack não inclui Alertmanager (fora de escopo MVP).

**Workaround atual:** o `remote-control-monitor.sh` envia alertas via WhatsApp (Evolution API) para eventos de **conectividade**. Métricas puras ficam só no Grafana.

## Customizar thresholds

Editar `prometheus/rules/claude_projects.yml`:

```yaml
- alert: ClaudeAgentHighMemory
  expr: claude_agent:memory_rss_mib > 2048  # novo threshold 2GiB
  for: 10m  # mais tolerante
```

Recarregar Prometheus:
```bash
curl -X POST http://localhost:9090/-/reload
```

## Adicionar alerta novo

```yaml
- name: custom_alerts
  rules:
    - alert: ClaudeUnknownProject
      expr: claude_agent_count{project="unknown"} > 0
      for: 1m
      labels:
        severity: info
      annotations:
        summary: "Agente Claude sem projeto identificado"
        description: "{{ $value }} processo(s) Claude sem cwd reconhecido — verificar"
```

Depois `curl -X POST http://localhost:9090/-/reload`.

## Integrar com Alertmanager (futuro)

Se quiser notificações automáticas por email/Slack/WhatsApp:

1. Adicionar service `alertmanager` no `docker-compose.yml`
2. Configurar `prometheus.yml`:
   ```yaml
   alerting:
     alertmanagers:
       - static_configs:
           - targets: ['alertmanager:9093']
   ```
3. Configurar `alertmanager.yml` com receivers (webhook, email, slack)
4. Alertmanager pode chamar Evolution API via webhook pra WhatsApp

Fora do escopo deste README — fica como roadmap.
