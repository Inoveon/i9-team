# Remote Control Monitor — Pacote de Instalação

Assets prontos pra instalar o monitor de Remote Control em qualquer ambiente (servidor ou máquina local).

## Arquivos neste diretório

| Arquivo | Descrição |
|---|---|
| [`INSTALL-PROMPT.md`](./INSTALL-PROMPT.md) | **Prompt pronto pro Claude Code local executar** — cole no Claude da sua máquina e ele instala tudo |
| [`remote-control-monitor.sh`](./remote-control-monitor.sh) | Script bash — fonte da verdade, copiado do servidor rodando |
| [`remote-control-monitor.service`](./remote-control-monitor.service) | Unit systemd (service) — template (ajustar User/HOME/PATH) |
| [`remote-control-monitor.timer`](./remote-control-monitor.timer) | Unit systemd (timer) — padrão 10min, usa como está |
| [`remote-control-monitor.env.example`](./remote-control-monitor.env.example) | Template do arquivo de env — copiar pra `~/.claude/remote-control-monitor.env` e ajustar |

## Documentação conceitual

- [`../REMOTE-CONTROL-MONITOR.md`](../REMOTE-CONTROL-MONITOR.md) — Guia completo (arquitetura, variáveis, troubleshooting)
- [`../REMOTE-CONTROL.md`](../REMOTE-CONTROL.md) — Como funciona o feature `/remote-control` do Claude Code

## Quick start

Se você está no Claude Code da máquina onde quer instalar:

1. Abra o arquivo [`INSTALL-PROMPT.md`](./INSTALL-PROMPT.md)
2. Cole o conteúdo como mensagem/prompt pro Claude Code
3. Claude vai guiar a instalação passo a passo (incluindo escolher prefixo único)

## Regra de ouro

Cada ambiente que rodar este monitor **precisa ter `CLAUDE_ENV_PREFIX` diferente**. Sem isso, os nomes colidem no `claude.ai/code` e uma reconexão do ambiente A sobrescreve a sessão do ambiente B.

Prefixos sugeridos (decida o seu antes de instalar):

| Ambiente | Prefixo |
|---|---|
| Servidor compartilhado (ubuntu-claude-agents) | `cs` |
| MacBook do Lee | `mac` |
| WSL no Windows do Lee | `wsl` |
| Qualquer outra | defina um novo (curto, minúsculo, sem `-`) |
