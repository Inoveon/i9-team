---
name: mcp-setup
description: Instala/configura MCP servers em qualquer projeto Claude Code usando o repositório Inoveon/mcp-servers como fonte. Detecta MCPs ausentes, gera .mcp.json correto, cria .memory/, configura .gitignore. Usa templates pré-validados (essenciais + APIs por tipo de projeto). Invoque com /mcp-setup <projeto> [tipo] ou ao mencionar "configurar MCPs", "adicionar MCP", ".mcp.json", "instalar mcp-servers", "preparar projeto pra team".
user-invocable: true
---

# MCP Setup — provisionamento de MCPs em projetos

Aplique este procedimento sempre que precisar:
- Configurar MCPs num projeto novo
- Adicionar MCPs faltantes num projeto existente
- Instalar `mcp-servers` em ambiente novo (Linux/Mac)
- Reproduzir o setup de outro projeto

---

## Repositório fonte

```
git@github.com:Inoveon/mcp-servers.git → /home/ubuntu/mcp-servers (Linux)
                                       → ~/mcp-servers (Mac, sugestão)
```

9 MCPs disponíveis com `dist/index.js` buildado:
`evolution-api`, `i9-agent-memory`, `i9-cnpj`, `i9-dfe`, `i9-knowledge`, `i9-pdv`, `i9-smartpass`, `i9-team`, `i9-view`

---

## MCPs essenciais (todo projeto que terá team tmux)

Sempre incluir os 3 no `.mcp.json`:

| MCP | Função | Env obrigatório |
|-----|--------|-----------------|
| `i9-team` | Orquestração tmux (`team_send`, `team_check`, `team_note_*`) | — |
| `i9-agent-memory` | Vault de notas + busca semântica pgvector | `VAULT_NAME`, `VAULT_PATH`, `DATABASE_URL`, `OPENAI_API_KEY` |
| `evolution-api` | WhatsApp alerting (58 tools) | `EVOLUTION_API_URL`, `EVOLUTION_API_KEY`, `EVOLUTION_DEFAULT_INSTANCE` |

---

## MCPs adicionais por tipo de projeto

| Tipo | Adicionais |
|------|-----------|
| **dev** (web/mobile geral) | (nenhum extra) |
| **pdv** (Smart PDV completo) | i9-pdv, i9-cnpj, i9-dfe, i9-knowledge, i9-view |
| **service** (Smart Service) | i9-smartpass |
| **infra** (Proxmox/ops) | i9-cnpj, i9-dfe, i9-knowledge, i9-pdv, i9-smartpass, i9-view (todos) |
| **issues** (rastreamento) | (nenhum extra) |

---

## Procedimento — projeto existente

1. **Verificar repo `mcp-servers`**
   ```bash
   if [ ! -d ~/mcp-servers ] && [ ! -d /home/ubuntu/mcp-servers ]; then
     git clone git@github.com:Inoveon/mcp-servers.git ~/mcp-servers
     for d in ~/mcp-servers/*/; do
       [ -f "$d/package.json" ] && (cd "$d" && npm install && npm run build)
     done
   fi
   ```
   Resolver path real: `MCP_ROOT=$(test -d ~/mcp-servers && echo ~/mcp-servers || echo /home/ubuntu/mcp-servers)`

2. **Verificar Postgres do agent-memory** (necessário pra i9-agent-memory)
   ```bash
   psql -U agent -d agent_memory -c '\dt' || echo "Postgres não está pronto — ver troubleshooting"
   ```

3. **Auditar `.mcp.json` atual do projeto alvo**
   ```bash
   cd /caminho/do/projeto
   cat .mcp.json 2>/dev/null | jq -r '.mcpServers | keys[]' || echo "Sem .mcp.json"
   ```

4. **Decidir MCPs** — confirme com user qual tipo (dev / pdv / service / infra / issues)

5. **Gerar `.mcp.json`** usando o template (próxima seção)

6. **Criar `.memory/`** se ainda não existe
   ```bash
   mkdir -p /caminho/do/projeto/.memory
   ```

7. **Verificar gitignore**
   ```bash
   git check-ignore .mcp.json && {
     # Está ignorado — gerar também .mcp.json.example versionável
     cp .mcp.json .mcp.json.example
     git add .mcp.json.example
   } || {
     # Não ignorado — versionar direto
     git add .mcp.json
   }
   ```

8. **Commit + push** (perguntar antes ao user)
   ```bash
   git commit -m "chore(mcp): adiciona .mcp.json com N MCPs"
   git push origin main
   ```

9. **Avisar restart das sessões Claude** — MCPs novas só carregam em sessão nova

---

## Template `.mcp.json`

Substitua `{PROJECT_NAME}`, `{PROJECT_ROOT}`, `{MCP_ROOT}` pelos valores reais.

```json
{
  "mcpServers": {
    "i9-team": {
      "command": "node",
      "args": ["{MCP_ROOT}/i9-team/dist/index.js"]
    },
    "i9-agent-memory": {
      "command": "node",
      "args": ["{MCP_ROOT}/i9-agent-memory/dist/index.js"],
      "env": {
        "VAULT_NAME": "{PROJECT_NAME}",
        "VAULT_PATH": "{PROJECT_ROOT}/.memory",
        "VAULT_IGNORE_PATTERNS": ".obsidian/**,.smart-env/**,*.canvas",
        "DATABASE_URL": "postgresql://agent:agent123@localhost:5432/agent_memory",
        "EMBEDDING_PROVIDER": "openai",
        "OPENAI_API_KEY": "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",
        "EMBEDDING_BASE_URL": "https://openrouter.ai/api/v1",
        "EMBEDDING_MODEL": "text-embedding-3-small",
        "EMBEDDING_DIMENSIONS": "1536"
      }
    },
    "evolution-api": {
      "command": "node",
      "args": ["{MCP_ROOT}/evolution-api/dist/index.js"],
      "env": {
        "EVOLUTION_API_URL": "https://evolution.inoveon.com.br",
        "EVOLUTION_API_KEY": "bf696d6c2fb3a301e0b45d475c2e26efc4607726bdbc8f3687950c47f51ba9c4",
        "EVOLUTION_DEFAULT_INSTANCE": "LEE_65992905301_CLARO",
        "EVOLUTION_DEFAULT_DELAY": "1200",
        "EVOLUTION_TIMEOUT": "30000",
        "EVOLUTION_RETRY_ATTEMPTS": "3",
        "EVOLUTION_RETRY_DELAY": "1000"
      }
    }
  }
}
```

### Adicionar MCPs por tipo

**PDV** — adicionar ao `mcpServers`:
```json
"i9-pdv": {
  "command": "node",
  "args": ["{MCP_ROOT}/i9-pdv/dist/index.js"],
  "env": {
    "PDV_API_URL": "http://10.0.10.3:4001",
    "PDV_EMAIL": "admin@inoveon.com.br",
    "PDV_PASSWORD": "inoveon@159753"
  }
},
"i9-cnpj": {
  "command": "node",
  "args": ["{MCP_ROOT}/i9-cnpj/dist/index.js"],
  "env": {
    "CNPJ_API_URL": "http://10.0.10.3:4006",
    "CNPJ_API_KEY": ""
  }
},
"i9-dfe": {
  "command": "node",
  "args": ["{MCP_ROOT}/i9-dfe/dist/index.js"],
  "env": {
    "DFE_API_URL": "http://10.0.10.3:4003",
    "DFE_API_KEY": ""
  }
},
"i9-knowledge": {
  "command": "node",
  "args": ["{MCP_ROOT}/i9-knowledge/dist/index.js"],
  "env": {
    "KNOWLEDGE_API_URL": "http://10.0.10.16:3500",
    "KNOWLEDGE_TOKEN": ""
  }
},
"i9-view": {
  "command": "node",
  "args": ["{MCP_ROOT}/i9-view/dist/index.js"],
  "env": {
    "VIEW_API_URL": "http://10.0.10.3:4011",
    "VIEW_EMAIL": "admin@inoveon.com.br",
    "VIEW_PASSWORD": "inoveon@159753"
  }
}
```

**Service** — adicionar:
```json
"i9-smartpass": {
  "command": "node",
  "args": ["{MCP_ROOT}/i9-smartpass/dist/index.js"],
  "env": {
    "SMARTPASS_API_URL": "http://10.0.10.3:4014",
    "SMARTPASS_CNPJ": "",
    "SMARTPASS_EMAIL": "",
    "SMARTPASS_PASSWORD": ""
  }
}
```

---

## Procedimento — ambiente novo (Linux ou Mac)

1. **Clone do repo**
   ```bash
   git clone git@github.com:Inoveon/mcp-servers.git ~/mcp-servers
   ```

2. **Build de todos os MCPs**
   ```bash
   cd ~/mcp-servers
   for d in */; do
     [ -f "$d/package.json" ] && (cd "$d" && npm install && npm run build)
   done
   ```

3. **Postgres + pgvector pra i9-agent-memory**
   ```bash
   docker run -d --name agent-memory-pg \
     -e POSTGRES_USER=agent \
     -e POSTGRES_PASSWORD=agent123 \
     -e POSTGRES_DB=agent_memory \
     -p 5432:5432 \
     pgvector/pgvector:pg16
   ```

4. **MCPs globais** (`~/.mcp.json` ou `~/.claude.json`)
   - Sempre i9-team + i9-agent-memory + evolution-api globais (fallback se projeto sem .mcp.json)

5. **Para cada projeto**: aplicar procedimento "projeto existente" acima

---

## Validação após setup

```bash
# 1. Sintaxe do JSON
cat .mcp.json | jq . > /dev/null && echo "✅ JSON válido"

# 2. Builds existem
for srv in $(jq -r '.mcpServers[] | .args[0]' .mcp.json); do
  [ -f "$srv" ] && echo "✅ $srv" || echo "❌ FALTA: $srv"
done

# 3. Postgres acessível (se i9-agent-memory configurado)
psql "postgresql://agent:agent123@localhost:5432/agent_memory" -c '\dt' && echo "✅ Postgres OK"

# 4. .memory/ existe
[ -d .memory ] && echo "✅ .memory/" || mkdir -p .memory

# 5. Reiniciar sessão Claude e verificar
# Comandos disponíveis no Claude após restart: mcp__i9-team__*, mcp__i9-agent-memory__*, mcp__evolution-api__*
```

---

## Troubleshooting

| Sintoma | Causa | Fix |
|---------|-------|-----|
| MCP não aparece no Claude | Sessão não foi reiniciada | Saia e abra Claude no projeto |
| `Cannot find module` no log | Build não rodou | `cd ~/mcp-servers/<mcp> && npm install && npm run build` |
| `i9-agent-memory` falha ao iniciar | Postgres não pronto / vault path inválido | Validar Docker UP + `mkdir -p $VAULT_PATH` |
| `evolution-api` 401 | API key errada | Conferir `EVOLUTION_API_KEY` no `.mcp.json` |
| `i9-team` MCP sem teams | `~/.claude/teams.json` ausente | Instalar via `team-survey` skill ou criar manualmente |

---

## Regras absolutas

- ❌ NUNCA commitar `.mcp.json` se já estiver no `.gitignore` — gere `.mcp.json.example`
- ❌ NUNCA hardcode credenciais em código (usar sempre `env` no JSON)
- ❌ NUNCA inventar MCP que não existe no repo (`github-stats` é exemplo de bug atual)
- ✅ SEMPRE criar `.memory/` antes de configurar i9-agent-memory
- ✅ SEMPRE validar JSON com `jq .` antes de commitar
- ✅ SEMPRE perguntar tipo do projeto se não óbvio (dev/pdv/service/infra/issues)
- ✅ SEMPRE reusar credenciais Inoveon dos templates (consistência entre projetos)
- ✅ SEMPRE avisar user pra reiniciar sessão Claude após mudança no `.mcp.json`

---

## Referências

- Padrão completo no vault: `padrao-mcp-servers-projetos`
- Skill complementar: `team-survey` (planejamento multi-camada com agentes)
- Skill complementar: `team-protocol` (orquestrador/agent definitions)
