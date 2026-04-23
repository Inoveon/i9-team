---
title: Benchmark v2 — Trio simétrico (team-claude vs team-gemini vs team-codex)
tags:
  - benchmark
  - multi-client
  - v2
date: '2026-04-23'
status: concluído
---
# Benchmark v2 — trio simétrico

Repetição das 4 tarefas do benchmark v1, agora com os 3 cobaia oficiais (agentes não-especializados, comparação mais justa).

## Tempos (segundos)

| Tarefa | team-claude | team-gemini | team-codex |
|---|---|---|---|
| T1 — Leitura | **11s** | 56s | 12s (retry) |
| T3 — Edit | **5s** | 21s | 25s |
| T5 — Refactor | **11s** | 13s | 37s |
| T7 — Doc | 11s | **7s** | 17s |
| **Total** | **38s** | 97s | 91s |

## Verificação no disco (correção funcional)

| Tarefa | Claude | Gemini | Codex |
|---|---|---|---|
| T1 — texto | ✅ 3 linhas exatas | ✅ 3 linhas exatas | ✅ 3 linhas exatas |
| T3 — priority? | ✅ | ✅ (path absoluto OK) | ✅ |
| T5 — session-names.ts | ✅ | ✅ | ✅ |
| T7 — parágrafo | ❌ estourou (~12 linhas) | ✅ ~7 linhas | ✅ ~5 linhas |

## Comparação bench1 vs bench2

**Melhoria dramática no bench2**:
- Claude cobaia (Opus 4.7 genérico) foi mais rápido que backend especializado
- Gemini e Codex reduziram tempo com path absoluto explícito + delay adaptativo MCP
- Codex ainda precisa Enter manual (meu orquestrador roda MCP antiga)

## Notas atualizadas

| Tarefa | Claude | Gemini | Codex | Vencedor bench2 |
|---|---|---|---|---|
| T1 | 5/5 | 5/5 | 5/5 | 🥇 empate triplo (Claude rápido) |
| T3 | 5/5 | 5/5 | 5/5 | 🥇 empate triplo |
| T5 | 5/5 | 5/5 | 4.5/5 | 🥇 Claude/Gemini |
| T7 | 4/5 (estourou) | 4.5/5 | 5/5 | 🥇 Codex |
| **Média** | **4.75** | **4.88** | **4.88** | 🥇 empate Gemini/Codex |

No bench2 a separação é menor — o upgrade da MCP e instruções mais claras nivelaram. Codex e Gemini dividem primeiro lugar.

## Tokens/custo estimado

Gemini ainda o mais barato (tier gratuito 1000 req/dia). Em T7, Claude usou ~10k tokens de output (verbose); Codex ~1.2k (minimal-diff style também na escrita).

**Vencedor de custo-benefício em volume**: **Gemini**.
**Vencedor de qualidade por tarefa**: **Codex** (4 vitórias no bench1 e 1 no bench2).
**Vencedor de velocidade**: **Claude** (total 38s no bench2).
