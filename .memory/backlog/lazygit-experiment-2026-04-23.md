---
title: Backlog — experimentar Lazygit antes de comprar GitKraken
tags:
  - backlog
  - tools
  - git
  - developer-experience
date: '2026-04-23'
status: backlog
prioridade: baixa
---
# Backlog — experimentar Lazygit (vs GitKraken)

**Data**: 2026-04-23
**Motivação**: usuário considerou pagar GitKraken (~US$ 79/ano). Minha análise: perfil dele é 90% terminal (Claude Code + tmux + gh CLI), e Lazygit (TUI grátis, roda no tmux) provavelmente entrega 80% do valor do GitKraken sem fricção de contexto switching.

## Proposta

Testar **Lazygit** por 1-2 semanas antes de decidir sobre GitKraken.

### Instalação

```bash
# Ubuntu/Debian
sudo add-apt-repository ppa:lazygit-team/release
sudo apt update && sudo apt install lazygit

# OR via Go
go install github.com/jesseduffield/lazygit@latest

# OR via brew (macOS)
brew install lazygit
```

### Features-chave a avaliar

- Commit graph interativo (compare com GitKraken)
- Interactive rebase (drag keyboard)
- Stash management
- Branch fuzzy finder
- Multi-repo workspace (via config)
- Keyboard shortcuts (instalar cheat sheet na mente)
- Integração com `gh` CLI (abrir PR direto)

### Casos de uso a testar

1. **Commit cross-project** — roda lazygit em cada repo da frota (i9-team, mcp-servers, i9-smart-pdv, etc) pra comparar fluxo vs git CLI
2. **Rebase interativo** de hotfix que pegou 10 commits cruzados
3. **Visualização de branches** de `i9-service` (tem histórico mais complexo)
4. **Conflito de merge** visual vs `git mergetool`
5. **PR workflow** — criar branch, commit, push, abrir PR via `gh` integrado

### Critérios de decisão

| Se... | Decisão |
|---|---|
| Lazygit cobre 80%+ das dores | Fica com Lazygit — evita US$ 79/ano |
| Lazygit incomoda em 3+ casos de uso | Testa GitKraken 14d trial |
| Precisa de visualização MULTI-REPO simultânea (ver i9-team + i9-smart-pdv + i9-service lado a lado) | GitKraken ganha — Lazygit não faz |
| Quer onboarding de júniors via GUI | GitKraken ganha |

### Alternativas adicionais pra considerar

- **GitUI** (Rust, ainda mais rápido que Lazygit, keybinds diferentes)
- **GitLens** no VS Code (se usar Cursor/VS Code pra editar)
- **Magit** (Emacs — se já for emacs user)
- **Sourcetree** (grátis, Atlassian, só Mac/Win)

### Prioridade

**Baixa** — nada urgente. Se der 30 min qualquer hora, instala e experimenta. Nada bloqueia.

### Ação concreta quando retomar

1. `apt install lazygit` no servidor + máquina local
2. Tutorial inicial (https://github.com/jesseduffield/lazygit)
3. Usar 1 semana
4. Decidir GitKraken ou não
