#!/usr/bin/env python3
"""
claude-metrics.py — Gera métricas Prometheus por projeto e agente Claude.

Cross-platform (Linux + macOS) via psutil.

Lê processos `claude` ativos, extrai:
  - agent: valor do flag --agent
  - project: basename do cwd

Agrega por (project, agent) e escreve arquivo .prom para o
textfile_collector do node_exporter.

Executado a cada 30s via systemd timer (Linux) ou launchd plist (macOS).

Dependências:
    pip3 install --user psutil
"""
import os
import re
import sys
import time
from collections import defaultdict

try:
    import psutil
except ImportError:
    print("ERRO: psutil não instalado. Rode: pip3 install --user psutil", file=sys.stderr)
    sys.exit(1)


# ── Configuração ──────────────────────────────────────────────────────────────
def default_textfile_dir() -> str:
    """Resolve o diretório textfile_collector conforme OS."""
    # Override via env
    if env := os.environ.get("TEXTFILE_DIR"):
        return env
    # Linux: padrão node_exporter via apt/binário
    if os.path.isdir("/var/lib/node_exporter/textfile_collector"):
        return "/var/lib/node_exporter/textfile_collector"
    # macOS Homebrew
    for candidate in [
        "/usr/local/var/node_exporter/textfile_collector",
        "/opt/homebrew/var/node_exporter/textfile_collector",
    ]:
        if os.path.isdir(candidate):
            return candidate
    # Fallback: /tmp (docker-compose pode montar)
    return "/tmp/node_exporter_textfile"


TEXTFILE_DIR = default_textfile_dir()
OUTPUT_FILE  = os.path.join(TEXTFILE_DIR, "claude_agents.prom")
VERBOSE      = "--verbose" in sys.argv or "-v" in sys.argv


# ── Helpers ───────────────────────────────────────────────────────────────────

def extract_agent(cmdline: list[str]) -> str:
    """Extrai valor do --agent do cmdline."""
    joined = " ".join(cmdline)
    m = re.search(r"--agent\s+(\S+)", joined)
    return m.group(1) if m else "untagged"


def extract_project(cwd: str | None) -> str:
    if not cwd:
        return "unknown"
    return os.path.basename(cwd.rstrip("/"))


def escape_label(value: str) -> str:
    """Escapa para labels Prometheus."""
    return value.replace("\\", "\\\\").replace('"', '\\"')


def is_claude_process(cmdline: list[str]) -> bool:
    """Detecta processo claude (cmdline contém 'bin/claude')."""
    if not cmdline:
        return False
    joined = " ".join(cmdline)
    # Linux/Mac: caminhos típicos contém 'bin/claude'
    return "bin/claude" in joined or joined.endswith("claude") or "/claude " in joined


# ── Core ──────────────────────────────────────────────────────────────────────

def collect() -> dict:
    """Varre processos via psutil e agrega métricas por (project, agent)."""
    counts      = defaultdict(int)
    cpu_user    = defaultdict(float)
    cpu_system  = defaultdict(float)
    memory_rss  = defaultdict(int)

    for proc in psutil.process_iter(['pid', 'cmdline', 'cwd']):
        try:
            cmdline = proc.info['cmdline'] or []
            if not is_claude_process(cmdline):
                continue

            agent   = extract_agent(cmdline)
            project = extract_project(proc.info.get('cwd'))
            key     = (project, agent)

            counts[key] += 1

            # CPU times
            cpu = proc.cpu_times()
            cpu_user[key]   += cpu.user
            cpu_system[key] += cpu.system

            # Memory RSS em bytes
            mem = proc.memory_info()
            memory_rss[key] += mem.rss

            if VERBOSE:
                print(f"  pid={proc.info['pid']} project={project} agent={agent} rss={mem.rss}")

        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            continue

    return {
        "counts":     counts,
        "cpu_user":   cpu_user,
        "cpu_system": cpu_system,
        "memory_rss": memory_rss,
    }


def render(data: dict) -> str:
    """Gera conteúdo .prom a partir dos dados agregados."""
    if not data:
        return "# claude-metrics: sem dados\n"

    counts     = data["counts"]
    cpu_user   = data["cpu_user"]
    cpu_system = data["cpu_system"]
    memory_rss = data["memory_rss"]
    keys       = sorted(counts.keys())

    def lbl(project, agent):
        return f'project="{escape_label(project)}",agent="{escape_label(agent)}"'

    lines = []

    # ── count ──
    lines += [
        "# HELP claude_agent_count Número de processos Claude ativos por projeto e agente",
        "# TYPE claude_agent_count gauge",
    ]
    for (proj, ag) in keys:
        lines.append(f"claude_agent_count{{{lbl(proj, ag)}}} {counts[(proj, ag)]}")

    # ── cpu user ──
    lines += [
        "",
        "# HELP claude_agent_cpu_user_seconds_total Total de segundos de CPU em modo usuário por projeto e agente",
        "# TYPE claude_agent_cpu_user_seconds_total counter",
    ]
    for (proj, ag) in keys:
        v = cpu_user.get((proj, ag), 0.0)
        lines.append(f"claude_agent_cpu_user_seconds_total{{{lbl(proj, ag)}}} {v:.3f}")

    # ── cpu system ──
    lines += [
        "",
        "# HELP claude_agent_cpu_system_seconds_total Total de segundos de CPU em modo sistema por projeto e agente",
        "# TYPE claude_agent_cpu_system_seconds_total counter",
    ]
    for (proj, ag) in keys:
        v = cpu_system.get((proj, ag), 0.0)
        lines.append(f"claude_agent_cpu_system_seconds_total{{{lbl(proj, ag)}}} {v:.3f}")

    # ── memory rss ──
    lines += [
        "",
        "# HELP claude_agent_memory_rss_bytes RSS total em bytes dos processos Claude por projeto e agente",
        "# TYPE claude_agent_memory_rss_bytes gauge",
    ]
    for (proj, ag) in keys:
        v = memory_rss.get((proj, ag), 0)
        lines.append(f"claude_agent_memory_rss_bytes{{{lbl(proj, ag)}}} {v}")

    # ── info ──
    lines += [
        "",
        "# HELP claude_agent_info Label de identificação (sempre 1) — use para joins",
        "# TYPE claude_agent_info gauge",
    ]
    for (proj, ag) in keys:
        lines.append(f"claude_agent_info{{{lbl(proj, ag)}}} 1")

    # ── scrape timestamp ──
    lines += [
        "",
        "# HELP claude_metrics_last_scrape_timestamp_seconds Timestamp da última coleta",
        "# TYPE claude_metrics_last_scrape_timestamp_seconds gauge",
        f"claude_metrics_last_scrape_timestamp_seconds {time.time():.3f}",
    ]

    return "\n".join(lines) + "\n"


def write_atomically(path: str, content: str) -> None:
    """Escreve atomicamente (tmp + rename) para evitar leitura parcial."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write(content)
    os.replace(tmp, path)


# ── Entrypoint ────────────────────────────────────────────────────────────────

def main():
    t0 = time.monotonic()
    data = collect()
    content = render(data)
    write_atomically(OUTPUT_FILE, content)
    elapsed = (time.monotonic() - t0) * 1000

    total_procs = sum(data.get("counts", {}).values())
    groups = len(data.get("counts", {}))
    print(f"[claude-metrics] {groups} grupos | {total_procs} processos | {elapsed:.1f}ms → {OUTPUT_FILE}")

    if VERBOSE:
        print(content)


if __name__ == "__main__":
    main()
