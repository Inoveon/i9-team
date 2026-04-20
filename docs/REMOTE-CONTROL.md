# Remote Control — Claude Code

Registro do que foi observado em 2026-04-19 ao investigar o recurso **Remote Control** do Claude Code a partir de uma sessão Claude rodando em tmux no servidor (`i9-team-dev-team-dev-mobile`).

## O que é

Remote Control é um recurso nativo do Claude Code (CLI oficial da Anthropic) que expõe a sessão Claude local através da URL `https://claude.ai/code/session_<id>`. Com isso, o usuário pode continuar interagindo com a mesma sessão a partir do navegador (desktop ou mobile) sem precisar ter acesso direto ao terminal.

A sessão original continua rodando localmente; o Remote Control apenas estabelece um canal de espelhamento entre ela e o claude.ai.

## Slash command

`/remote-control` — slash command nativo do Claude Code. É o único comando envolvido, e tem **comportamento dependente do estado atual**:

- **Primeira execução (desconectado)** — conecta e exibe:
  ```
  ⎿  Remote Control connecting…

  /remote-control is active · Code in CLI or at
  https://claude.ai/code/session_01YQ5iWxSAoHSy1mD6LWCufB
  ```
  A status bar do rodapé passa a exibir `Remote Control active`.

- **Execução subsequente (já conectado)** — abre um menu interativo com 3 opções:
  ```
  Remote Control

  This session is available via Remote Control at
  https://claude.ai/code/session_01YQ5iWxSAoHSy1mD6LWCufB.

    Disconnect this session
    Show QR code
  ❯ Continue

  Enter to select · Esc to continue
  ```
  - **Disconnect this session** — desliga o canal de Remote Control
  - **Show QR code** — gera QR pra abrir a URL da sessão em outro dispositivo
  - **Continue** — mantém ativo e sai do menu (default)

## Navegação do menu via tmux

O menu é um picker do Claude Code (não é input de texto). Para automatizar via `tmux send-keys`:

| Ação | Tecla |
|---|---|
| Mover seleção pra cima | `Up` |
| Mover seleção pra baixo | `Down` |
| Confirmar opção | `Enter` |
| Sair sem selecionar | `Escape` |

**Exemplo — desconectar do servidor sem acesso ao terminal:**
```bash
# 1. Abrir menu
tmux send-keys -t <sessão> -l "/remote-control"
tmux send-keys -t <sessão> Enter

# 2. Navegar até "Disconnect this session"
#    (a partir do default "Continue": precisa 2x seta pra cima)
sleep 2
tmux send-keys -t <sessão> Up
tmux send-keys -t <sessão> Up

# 3. Confirmar
tmux send-keys -t <sessão> Enter

# 4. Validar
tmux capture-pane -t <sessão> -p | tail -5
# deve mostrar: ⎿  Remote Control disconnected.
```

O prompt de saída após desconexão:
```
❯ /remote-control
  ⎿  Remote Control disconnected.
```

A status bar perde o indicador `Remote Control active`.

## Bug observado em produção

O usuário relatou que **em sessões longas** o Remote Control oficial da Anthropic acaba **travando em modo "reconnecting"** e não volta sozinho. Quando isso acontece, o canal claude.ai/code/session_\<id\> deixa de responder mas a sessão local segue saudável.

**Workaround validado** — matar o canal manualmente pelo menu:

1. Executar `/remote-control` no terminal local (ou via `tmux send-keys`)
2. Selecionar `Disconnect this session`
3. Confirmar no menu → mensagem `Remote Control disconnected.`
4. Executar `/remote-control` de novo para reativar (nova URL/session_id)

Isso quebra o reconnect travado sem precisar derrubar a sessão Claude inteira.

## Como reconhecer o estado sem abrir o terminal

Olhando qualquer frame do terminal (ex: `tmux capture-pane`):

| Indicador | Estado |
|---|---|
| Rodapé com `Remote Control active` | Conectado e operacional |
| `Remote Control connecting…` como última linha de output | Em estabelecimento ou preso tentando reconectar |
| Rodapé sem qualquer indicador | Desconectado |

Se `Remote Control connecting…` aparece e fica lá por mais de alguns segundos sem virar `is active`, provavelmente está no estado travado e precisa do workaround acima.

## Integração com o i9-team Portal

A arquitetura de agentes do i9-team (cada agente em uma sessão tmux dedicada) permite usar esse workaround programaticamente — o orquestrador consegue:

1. Ler o estado do Remote Control de qualquer agente via `tmux capture-pane` (ou via MCP `team_check`)
2. Executar o desconecta/reconecta via `tmux send-keys` (ou `team_send` + `team_select_option`)

Isso pode virar uma **tool de manutenção** a ser exposta pelo backend Fastify — por exemplo `POST /teams/:id/agents/:agentId/remote-control/reset` — que dispara a sequência disconnect + reconnect automaticamente.

## Observações práticas

- A URL da sessão **muda a cada reconexão** — o session_id novo não é igual ao anterior. Quem for ler o QR precisa fazer isso depois de conectar, não antes.
- O Remote Control **não salva histórico** — é só um espelho do terminal local. Se a sessão Claude for encerrada, o link morre.
- `/remote-control` funciona em qualquer agente Claude Code, independente de `--agent` especializado.
- Em teams orquestrados, cada agente tem seu próprio Remote Control (session_ids distintos por agente).
