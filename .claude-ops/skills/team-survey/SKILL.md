---
name: team-survey
description: Padrão de levantamento → análise cruzada → confrontação técnica → decisão consolidada → issues GitHub para times multi-agente em tmux. Use quando o user reportar bugs/UX em múltiplos componentes, pedir investigação multi-camada (back+front+mobile), ou exigir planejamento antes de qualquer dev. Garante que nada vá pro código sem documentação e issue rastreável. Invoque com /team-survey <tema-curto>.
user-invocable: true
---

# Team Survey — Padrão de levantamento multi-agente

Aplique este protocolo SEMPRE que:
- O user reportar **3+ problemas** num mesmo subsistema (ex.: "tem vários bugs no chat")
- A solução exigir **mais de uma camada** (backend + frontend + mobile)
- O user pedir explicitamente "levantamento", "discussão", "planejar antes de implementar", "não assume como verdade"
- Houver risco de **decisão de produto** misturada com decisão técnica

**Regra de ouro:** nada vai pro código sem doc + issue. Confronte os agentes; não aceite o primeiro diagnóstico.

---

## Fluxo (por onda)

### 0. Briefing mestre (uma vez)

Antes de qualquer onda, crie a nota mestre:

```
team_note_write("briefing-<tema>-<YYYY-MM-DD>", ...)
```

Conteúdo mínimo:
- **Origem:** quem reportou e onde testou
- **Os N problemas (palavras do user)** — copie literal, numerado
- **Estratégia de execução em ondas:** tabela `Onda × Itens × Agentes × Foco`
- **Premissas inegociáveis** (ex.: "confrontar — se agente disser 'fácil', validar")
- **Status por onda** (checklist)

### 1. Disparar onda — levantamento paralelo

**Por onda**, agrupe itens **relacionados** (não despeje tudo de uma vez). Dispare `team_send` em **paralelo** para todos os agentes envolvidos.

Briefing pra cada agente deve ter:
- Contexto curto do que o user reportou
- Lista numerada do que ANALISAR (não implementar)
- Pedidos específicos:
  - Mapear caminho exato (ARQUIVO:LINHA — exigir Grep/Read, não invenção)
  - Formular **N hipóteses ranqueadas por probabilidade**
  - Listar **logs/observações necessárias pra comprovar**
  - Listar **fixes propostos com riscos e tradeoffs** (sem implementar)
- Salvar em `team_note_write("levantamento-onda<N>-<agente>-<YYYY-MM-DD>", ...)`
- **Bloqueio explícito:** "NÃO comece a corrigir. NÃO escreva código."

### 2. Análise cruzada (orquestrador)

Quando os agentes concluírem, leia **todas as notas** em paralelo e produza:

```
team_note_write("analise-cruzada-onda<N>-<YYYY-MM-DD>", ...)
```

Estrutura:
1. **Convergência total** — onde os agentes concordam (diagnóstico, ARQUIVO:LINHA)
2. **Divergências** — tabela `Ponto × Backend disse × Frontend disse × Veredito do orquestrador`
3. **Pontos abertos que exigem confrontação** — perguntas específicas com peso
4. **Plano consolidado proposto** — PRs sugeridos
5. **Ações imediatas** (checklist de confrontações + perguntas pro user)

**Se houver decisão de produto pendente**, marque-a aqui e pergunte ao user **separadamente** (não delegue UX pro agente).

### 3. Confrontação técnica (paralelo)

Mande perguntas pontuais pra cada agente desafiando os pontos frágeis. Pelo menos 4-5 perguntas por agente, incluindo:
- Pedir **sketch de pseudocódigo** pra fixes complexos
- Forçar **justificativa** de heurísticas/heartbeats
- Pedir **auditoria de regressões** em outras áreas do sistema
- Confrontar com a evidência de OUTRO agente quando houver divergência factual

Saída:
```
team_note_write("confrontacao-onda<N>-<agente>-<YYYY-MM-DD>", ...)
```

### 4. Decisão de produto (se aplicável)

Pergunte ao user **antes** de consolidar a decisão técnica. Salve:
```
team_note_write("decisoes-produto-onda<N>-<YYYY-MM-DD>", ...)
```
Inclua: pergunta literal + resposta literal do user + implicações técnicas + risco.

### 5. Decisão final consolidada

```
team_note_write("decisao-onda<N>-<YYYY-MM-DD>", ...)
```

Estrutura:
1. **Diagnóstico final acordado** (causa raiz por bug)
2. **Bugs latentes descobertos** (bônus)
3. **Plano de ataque consolidado em PRs** — tabela `Item × Mudança × Justificativa` por PR
4. **Ordem de merge sugerida**
5. **Fora do escopo (roadmap)**
6. **Issues GitHub a abrir** — tabela `# × Título × Repo × Refs`

### 6. Issues GitHub

Só depois da decisão final, abra issues via `gh issue create`. Cada issue:
- Cita a nota `decisao-onda<N>-<data>` no corpo
- Linka as notas de levantamento e confrontação
- Lista PR-items específicos com checkboxes
- Atribui repo correto (frontend/backend/mobile/raiz)

Salve a lista das issues abertas:
```
team_note_write("issues-onda<N>-<YYYY-MM-DD>", ...)
```

### 7. Autorização de dev

**Só depois das issues abertas**, peça ao user autorização explícita pra disparar implementação. Use `team_send` com referência à issue + decisão final.

---

## Tasks (TaskCreate)

No início, crie tasks no formato:
- 1 task por onda
- 1 task final: "Consolidar docs + abrir issues + autorizar dev"

Marque `in_progress` ao começar onda, `completed` ao concluir decisão.

---

## Padrão de nomes de notas

| Etapa | Nome |
|-------|------|
| Briefing mestre | `briefing-<tema>-<YYYY-MM-DD>` |
| Levantamento individual | `levantamento-onda<N>-<agente>-<YYYY-MM-DD>` |
| Análise cruzada | `analise-cruzada-onda<N>-<YYYY-MM-DD>` |
| Confrontação | `confrontacao-onda<N>-<agente>-<YYYY-MM-DD>` |
| Decisão de produto | `decisoes-produto-onda<N>-<YYYY-MM-DD>` |
| Decisão final | `decisao-onda<N>-<YYYY-MM-DD>` |
| Issues abertas | `issues-onda<N>-<YYYY-MM-DD>` |

---

## Regras absolutas

- ❌ NUNCA implementar antes de doc + issue
- ❌ NUNCA aceitar diagnóstico sem ARQUIVO:LINHA citado
- ❌ NUNCA decidir UX/produto sozinho — pergunte ao user
- ❌ NUNCA mandar a onda inteira de uma vez se forem >2 agentes em itens não relacionados
- ✅ SEMPRE confrontar — pelo menos 1 rodada de perguntas técnicas
- ✅ SEMPRE cruzar divergências factuais (um agente pode ter evidência que o outro perdeu)
- ✅ SEMPRE separar decisão de produto da decisão técnica
- ✅ SEMPRE salvar com `team_note_write` em cada etapa

---

## Sinal de qualidade

Você está fazendo certo se:
- Cada nota cita ARQUIVO:LINHA (não "no componente de chat")
- Cada hipótese tem probabilidade declarada
- Cada fix tem risco explícito
- Você descartou pelo menos 1 hipótese por evidência factual cruzada
- A decisão final tem ordem de merge e roadmap separados
- O user só foi acionado pra decisão de produto, nunca pra decisão técnica

---

## Confirmação de ativação

Ao invocar `/team-survey <tema>`, responda com:
1. "Iniciando survey de **<tema>**."
2. Lista as N etapas que vai cumprir
3. Cria as tasks
4. Salva o briefing inicial e dispara a Onda 1

E começa o trabalho — sem pedir autorização adicional pra fluxo, só pra decisões de produto.
