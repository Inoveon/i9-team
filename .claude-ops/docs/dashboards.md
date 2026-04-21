# Dashboards Grafana

3 dashboards provisionados automaticamente via `grafana/provisioning/dashboards/json/`.

## claude-agents.json
Visão detalhada por agente.

**Painéis típicos:**
- Tabela de agentes ativos (count + CPU% + RAM MiB)
- Time series de CPU por agente (últimos 30min)
- Time series de RAM por agente
- Top 10 agentes por CPU

**Queries usadas:**
- `claude_agent_count` pra lista
- `claude_agent:cpu_rate1m * 100` pra CPU%
- `claude_agent:memory_rss_mib` pra RAM

## team-view.json
Visão consolidada por team (projeto).

**Painéis típicos:**
- Stat: total de agentes por projeto
- Stat: CPU% total por projeto
- Stat: RAM total por projeto
- Heatmap: CPU por agente × tempo

**Queries usadas:**
- `claude_project:agent_count:sum` pra contagem
- `claude_project:cpu_rate1m:sum * 100` pra CPU%
- `claude_project:memory_rss_mib:sum` pra RAM

## machine-overview.json
Saúde geral da máquina (Node Exporter + overview dos Claude).

**Painéis típicos:**
- CPU da máquina (node_cpu_seconds_total)
- RAM da máquina (node_memory_*)
- Disk I/O
- Load average
- Overlay do claude_*

## Customização

### Editar dashboard existente
1. Abrir em Grafana UI
2. Clicar "Save" — opção "Save JSON to file"
3. Copiar JSON pro `monitoring/grafana/provisioning/dashboards/json/<nome>.json`
4. Grafana detecta via `updateIntervalSeconds: 30` em `dashboards.yml`

### Adicionar dashboard novo
1. Criar via Grafana UI
2. Export JSON (Dashboard settings → JSON Model)
3. Salvar em `monitoring/grafana/provisioning/dashboards/json/<novo>.json`
4. Commit e deploy

### Variables úteis
Em dashboards que filtram por projeto/agente:

```json
{
  "name": "project",
  "type": "query",
  "query": "label_values(claude_agent_count, project)"
}
```

```json
{
  "name": "agent",
  "type": "query",
  "query": "label_values(claude_agent_count{project=\"$project\"}, agent)"
}
```

## Credenciais padrão

- URL: http://localhost:3000
- User: `admin`
- Password: valor de `GRAFANA_ADMIN_PASSWORD` do `.env` (default `admin123`)

Primeira coisa ao configurar em produção: **mudar a senha**.

## Alerting no Grafana (alternativa ao Alertmanager)

Grafana 8+ tem alerting built-in:
1. Criar alert rule direto no painel
2. Configurar contact point (email, webhook, Slack)
3. Definir notification policy

Vantagem: UI visual e gerenciamento por dashboard.
Desvantagem: não versionado via provisioning (a menos que use alerting provisioning no arquivo YAML).
