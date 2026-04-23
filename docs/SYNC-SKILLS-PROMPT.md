# Prompt — Sincronizar Skills Locais com o Repo inoveon-skills

Cole o prompt abaixo no Claude Code da máquina local (Mac, WSL, ou qualquer outra). Ele clona o repo `Inoveon/inoveon-skills`, instala via symlinks, importa automaticamente todas as skills locais que ainda não estão versionadas, commita e faz push.

Depois de rodar uma vez, use `/team-skills-sync auto` periodicamente pra manter tudo sincronizado.

---

## 📋 Pré-requisitos

- SSH configurado com acesso ao GitHub `Inoveon/inoveon-skills`
- Git instalado
- Claude Code com permissão pra rodar Bash

---

## 🚀 Prompt para executar no Claude Code local

```
Preciso sincronizar minhas skills locais com o repositório versionado Inoveon/inoveon-skills. Execute os passos abaixo nesta ordem:

## 1. Clonar o repositório

Se ~/inoveon-skills ainda não existir:

    git clone git@github.com:Inoveon/inoveon-skills.git ~/inoveon-skills

Se já existir, faça pull:

    cd ~/inoveon-skills && git pull --rebase origin main

## 2. Ver o estado atual

Execute para ver o que já está linkado, o que é local, e o que está quebrado:

    bash ~/inoveon-skills/scripts/status.sh

Espera encontrar nesta máquina:
- ✅ linked — skills já versionadas (criadas no servidor Ubuntu)
- ⚠️ local-dir — skills que existem só localmente nesta máquina (candidatas a import)
- ⚠️ local-symlink / broken-symlink — links pra .agents/skills/ ou paths antigos

## 3. Rodar o auto-sync

Este é o comando principal. Ele faz tudo:
  1. git pull (se houver mudança remota)
  2. install.sh (cria symlinks dos que vieram do remote)
  3. Auto-import — detecta toda skill criada como dir local em ~/.claude/skills/
     e importa automaticamente pro repo
  4. git add + commit + push automáticos se houve mudança
  5. status final

Execute:

    bash ~/inoveon-skills/scripts/auto.sh

O commit gerado terá o hostname desta máquina pra identificar a origem.

## 4. Validar

Depois do auto, confirme rodando o status de novo:

    bash ~/inoveon-skills/scripts/status.sh

A ideia é ter o máximo de skills como ✅ linked. As que permanecerem como ⚠️ local-symlink são symlinks apontando pra fora do repo (ex: .agents/skills/ do Claude Code) e não devem ser mexidas.

## 5. Confirmação

Me reporte:
- Quantas skills foram importadas
- Se o push teve sucesso
- Lista de skills que ficaram como local-dir (não foram importadas automaticamente — pode ser colisão de nome ou dir vazio)

Se tudo der certo, qualquer skill que eu criar a partir de agora (em ~/inoveon-skills/skills/ ou em ~/.claude/skills/) pode ser sincronizada rodando de novo o mesmo comando bash ~/inoveon-skills/scripts/auto.sh.
```

---

## 🔄 Uso contínuo depois do setup

Uma vez que o repo está clonado e instalado, use a skill:

```
/team-skills-sync auto
```

Ou direto via bash:

```bash
~/inoveon-skills/scripts/auto.sh
```

O comando é idempotente — pode rodar quantas vezes quiser. Se não houver mudança, não faz nada. Se houver skill nova local, importa + commita + pusha.

---

## 🛠️ Comandos auxiliares

| Comando | O que faz |
|---------|-----------|
| `~/inoveon-skills/scripts/status.sh` | Mostra estado de cada skill |
| `~/inoveon-skills/scripts/install.sh` | Só cria symlinks (sem pull/commit) |
| `~/inoveon-skills/scripts/sync.sh` | pull + install + status (sem commit) |
| `~/inoveon-skills/scripts/auto.sh` | pull + install + import + commit + push |
| `~/inoveon-skills/scripts/import.sh <nome>` | Importa 1 skill específica |
| `~/inoveon-skills/scripts/uninstall.sh` | Remove symlinks (mantém dirs locais e backups) |

---

## ⚠️ Casos especiais

### Skill com colisão de nome (existe local E no repo)

O `auto.sh` detecta e pula, avisando na saída. Resolva manualmente:

```bash
# Comparar versões
diff -r ~/.claude/skills/<nome>/ ~/inoveon-skills/skills/<nome>/

# Se a sua versão local for mais recente, sobrescreva o repo:
rm -rf ~/inoveon-skills/skills/<nome>
cp -r ~/.claude/skills/<nome> ~/inoveon-skills/skills/<nome>
rm -rf ~/.claude/skills/<nome>
bash ~/inoveon-skills/scripts/install.sh
cd ~/inoveon-skills && git add skills/<nome> && git commit -m "chore(skills): atualiza <nome> da máquina local" && git push
```

### Symlinks broken apontando pra paths antigos (ex: .agents/skills/ ou Mac path no servidor)

São legacy — o `install.sh` faz backup automático deles em `~/.claude/skills-backup-<timestamp>/` quando precisa sobrescrever. Os demais ficam intactos.

### Desinstalar (manter só skills locais)

```bash
~/inoveon-skills/scripts/uninstall.sh
```

Remove apenas symlinks que apontam pro repo. Não toca em dirs locais nem em outros symlinks.

---

## 📖 Referências

- Repo: https://github.com/Inoveon/inoveon-skills
- Skill `team-skills-sync`: `~/inoveon-skills/skills/team-skills-sync/SKILL.md`
- README completo: `~/inoveon-skills/README.md`
