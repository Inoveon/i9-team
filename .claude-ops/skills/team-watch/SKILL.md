---
name: team-watch
description: Monitora todos os agentes do team atual em loop — faz team_check em todos os agentes ativos a cada 60s até todos concluírem ou o usuário interromper. Use como fallback quando o orquestrador parar de acompanhar, ou invoque manualmente para monitorar o progresso do team.
user-invocable: true
---

# Team Watch — Monitor de Agentes

Ao invocar `/team-watch`, inicie o loop de monitoramento imediatamente.

## Fluxo obrigatório

```
1. team_list_agents()                    # lista agentes ativos
2. Para cada agente (exceto orquestrador):
     team_check(agente, 100)             # captura output atual
     Avalia se concluiu ou está trabalhando
3. Bash("sleep 60")                      # aguarda 60s
4. Repete do passo 1 até todos concluírem
5. Ao detectar conclusão de um agente:
     team_note_write("progresso", "✓ {agente} concluiu: {resumo}", "append")
6. Quando TODOS concluírem:
     team_note_write("progresso", "## Todos os agentes concluíram", "append")
     Reporta resumo consolidado ao usuário
```

## Como detectar se um agente concluiu

O agente concluiu quando o output contém:
- "Aguardando instruções do orquestrador"
- "Protocolo de agente ativado"
- "concluído" / "finalizado" / "pronto"
- O prompt `❯` aparece sem atividade em andamento

O agente ainda está trabalhando quando o output contém:
- "Implementando..." / "Criando..." / "Analisando..."
- Ferramentas sendo executadas (⏺, ✶, ...)
- Texto sendo gerado

## Interrupção

Se o usuário enviar qualquer mensagem durante o watch, pare o loop e responda normalmente.

## Exemplo de saída durante o watch

```
[10:30] Verificando agentes...
  ✓ team-dev-backend — trabalhando (módulo auth em andamento)
  ✓ team-dev-frontend — concluiu dashboard
  ✓ team-dev-mobile — trabalhando (HomeScreen em andamento)

Próximo check em 60s...
```
