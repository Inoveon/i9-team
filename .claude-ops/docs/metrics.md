# Métricas expostas

## Métricas base (por agente)

Todas com labels `project` e `agent`.

### `claude_agent_count`
- **Tipo:** gauge
- **Descrição:** Número de processos Claude ativos para o par (projeto, agente)
- **Cardinalidade:** ~1 por par (só 1 processo por agente em sessão normal)

### `claude_agent_cpu_user_seconds_total`
- **Tipo:** counter
- **Descrição:** Segundos de CPU em modo usuário (cresce monotonicamente)
- **Uso:** `rate(...[1m])` pra CPU% por agente

### `claude_agent_cpu_system_seconds_total`
- **Tipo:** counter
- **Descrição:** Segundos de CPU em modo kernel
- **Uso:** juntar com user pra CPU total

### `claude_agent_memory_rss_bytes`
- **Tipo:** gauge
- **Descrição:** RSS (Resident Set Size) em bytes
- **Uso:** `/ 1024 / 1024` pra MiB

### `claude_agent_info`
- **Tipo:** gauge (sempre 1)
- **Descrição:** Label de identificação — usar em joins
- **Exemplo:** `claude_agent_info * on(project,agent) group_left ...`

## Métricas meta

### `claude_metrics_last_scrape_timestamp_seconds`
- **Tipo:** gauge
- **Descrição:** Timestamp Unix da última coleta
- **Uso:** alerta se `time() - <valor> > 60` → script parou

## Record rules (agregados)

Definidas em `prometheus/rules/claude_projects.yml`:

| Record | Expressão |
|--------|-----------|
| `claude_project:cpu_rate1m:sum` | `sum by (project) (rate(cpu_user_total[1m]) + rate(cpu_system_total[1m]))` |
| `claude_agent:cpu_rate1m` | `rate(cpu_user_total[1m]) + rate(cpu_system_total[1m])` |
| `claude_project:memory_rss_mib:sum` | `sum by (project) (memory_rss_bytes) / 1024 / 1024` |
| `claude_agent:memory_rss_mib` | `memory_rss_bytes / 1024 / 1024` |
| `claude_project:agent_count:sum` | `sum by (project) (claude_agent_count)` |

Usar sempre os records em dashboards — são pré-calculados a cada 30s.

## Queries úteis

### Top 5 agentes por CPU
```promql
topk(5, claude_agent:cpu_rate1m)
```

### Total RAM por projeto
```promql
claude_project:memory_rss_mib:sum
```

### Agentes órfãos (sem cwd reconhecido)
```promql
claude_agent_count{project="unknown"}
```

### Verificar se coleta está viva
```promql
time() - claude_metrics_last_scrape_timestamp_seconds < 60
```

## Process exporter (complementar, Linux only)

Expõe métricas adicionais por processo agrupando pelo nome do agente:

### `namedprocess_namegroup_cpu_seconds_total{groupname="<agent>"}`
CPU total do grupo de processos (pode ter múltiplos PIDs se houver fork).

### `namedprocess_namegroup_memory_bytes{groupname="<agent>",memtype="resident"}`
RAM residente.

### `namedprocess_namegroup_num_threads{groupname="<agent>"}`
Threads ativas.

Em macOS `process_exporter` não é suportado (lê /proc). O `claude-metrics.py` via psutil cobre.

## Exemplo de dashboard query

```promql
# CPU % por agente (últimos 5min, agregado em 1m)
claude_agent:cpu_rate1m * 100
```

```promql
# RAM em MiB por agente
claude_agent:memory_rss_mib
```

```promql
# Total de processos Claude no sistema
sum(claude_agent_count)
```
