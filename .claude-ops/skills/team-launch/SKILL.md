---
name: team-launch
description: "Gerencia teams de agentes Claude Code — sobe, para, abre no iTerm2 e mostra status. Executa team.sh e team-iterm.sh automaticamente. Use sempre que o usuário quiser iniciar, subir, abrir, parar ou ver o status de um team — mesmo que diga apenas 'sobe o team X', 'abre o team Y', 'para o team dev', 'status dos agentes', 'lança o team de infra', 'quero trabalhar no team Z'."
---

# team-launch

Gerencia teams de agentes Claude Code via tmux + iTerm2.

## Scripts disponíveis

- `~/.claude/scripts/team.sh` — gerencia sessões tmux (start / stop / list / status)
- `~/.claude/scripts/team-iterm.sh` — abre layout visual no iTerm2

---

## Passo 1 — Menu inicial (SEMPRE que não houver ação explícita)

Se o usuário chamou `/team-launch` sem especificar claramente o que quer fazer,
use `AskUserQuestion` com duas perguntas: **ação** e **projeto/team**.

Execute primeiro para ter os dados:
```bash
~/.claude/scripts/team.sh list
~/.claude/scripts/team.sh status
```

Então pergunte:

```
AskUserQuestion(
  questions: [
    {
      question: "O que você quer fazer com o team?",
      header: "Ação",
      multiSelect: false,
      options: [
        { label: "🚀 Subir + abrir no iTerm2", description: "Cria as sessões tmux e abre o layout visual" },
        { label: "🖥️ Só abrir no iTerm2", description: "Sessões já rodando — só abre a janela" },
        { label: "⏹️ Parar o team", description: "Encerra todas as sessões tmux do team" },
        { label: "📋 Ver status", description: "Lista as sessões tmux ativas" }
      ]
    },
    {
      question: "Qual projeto e team?",
      header: "Team",
      multiSelect: false,
      options: [
        // Monte as opções dinamicamente com base na saída de `team.sh list`
        // Formato: { label: "<projeto> › <team>", description: "<N> agentes" }
      ]
    }
  ]
)
```

> Monte as opções de team dinamicamente lendo a saída de `team.sh list`.
> Se houver apenas 1 team, pule essa segunda pergunta e use-o diretamente.

---

## Passo 2 — Executar a ação escolhida

### 🚀 Subir + abrir no iTerm2

```bash
~/.claude/scripts/team.sh start <projeto> <team>
sleep 5
~/.claude/scripts/team-iterm.sh <projeto> <team>
~/.claude/scripts/team.sh status
```

### 🖥️ Só abrir no iTerm2

```bash
~/.claude/scripts/team-iterm.sh <projeto> <team>
```

### ⏹️ Parar o team

```bash
~/.claude/scripts/team.sh stop <projeto> <team>
~/.claude/scripts/team.sh status
```

### 📋 Ver status

```bash
~/.claude/scripts/team.sh status
```

---

## Saída esperada

Ao final de qualquer ação, informe:
- ✅ O que foi feito
- 📋 Sessões ativas (resultado de `status`)
- 💡 Dica contextual (ex: `tmux attach -t <sessão>` para acessar pelo terminal)

---

## Erros comuns

| Erro | Solução |
|------|---------|
| Sessão já existe ao subir | Pergunte se quer parar + subir novamente ou só abrir no iTerm2 |
| Projeto não encontrado | Mostre `team.sh list` e pergunte qual escolher |
| iTerm2 não abriu | Verifique se iTerm2 está instalado; sugira `tmux attach` manual |
| Nenhuma sessão ativa ao abrir iTerm2 | Oriente a subir primeiro com a opção 🚀 |
