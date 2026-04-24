---
title: Cloudflare Tunnel — Plano Master Inoveon
tags:
  - arquitetura
  - cloudflare
  - tunnel
  - infraestrutura
  - inoveon
  - traefik
  - migracao
status: pre-voo-concluido
projetos:
  - i9-team
  - i9-smart-pdv
---
# Cloudflare Tunnel — Plano Master Infraestrutura Inoveon

**Data inicial:** 2026-04-22  
**Status:** Pré-voo concluído. Aguardando decisão final de Socket.IO path + início execução.  
**Origem:** Conversa orquestrador i9-team + levantamento cross-team com i9-smart-pdv.

---

## Índice de notas relacionadas

### Levantamentos (já feitos)
- `team-i9-team/infra-levantamento-cloudflare-tunnel` — inventário Proxmox + rotas Traefik atuais
- `team-i9-team/pdv-cloudflare-tunnel-pre-voo` — consolidado dos bloqueadores e decisões do PDV
- `team-i9-smart-pdv/migracao-cloudflare-tunnel-consolidado` — visão do orquestrador PDV
- `team-i9-smart-pdv/migracao-cloudflare-tunnel-backend` — detalhes técnicos backend
- `team-i9-smart-pdv/migracao-cloudflare-tunnel-frontend` — detalhes técnicos frontend

---

## Contexto da decisão

Substituir exposição atual via **Traefik + IP público + firewall porta 80/443** por **Cloudflare Tunnel** — sem exposição de IP, sem porta aberta, TLS no edge da Cloudflare.

## Status dos domínios

- `inoveon.com.br` — **já na Cloudflare** (houston + aspen ns)
- `ectm.esp.br` — **já na Cloudflare** (woz + adelaide ns)
- Zero trabalho de migração de NS

## Infraestrutura atual (Proxmox 10.0.10.2)

14 VMs rodando. Ingress central: **VM 103 `ubuntu-traefik` (10.0.10.5)** com Traefik v3.2 + Let's Encrypt, config gerada por Ansible (`/docker/traefik/`).

17 rotas HTTPS + 1 TCP. Maior concentração de serviços em:
- VM 100 (10.0.10.3) — PRD (ectm, officium, dfe, support, evolution, studio)
- VM 104 (10.0.10.6) — pdv-dev
- VM 105/106/107 — pdv demo/hml/tst
- VM 151 (10.0.10.13) — portal-cliente

## Estratégia escolhida

**Cenário C — Híbrido, incremental**:
1. Mantém Traefik interno pros próximos meses (fallback)
2. Instala cloudflared **por VM** começando pelo `pdv-dev` (VM 104) como cobaia
3. Unifica web+api no mesmo hostname via ingress rules (mata DNS `*-api`)
4. Replica por ambiente (dev → hml → demo → prd) e depois por produto

## Padrão de roteamento por produto

```
produto.inoveon.com.br/*            → Next       localhost:4000
produto.inoveon.com.br/api/*        → API        localhost:4001
produto.inoveon.com.br/socket.io/*  → WebSocket  localhost:4001
```

Elimina DNS de API separado, elimina CORS, simplifica cookies/auth.

## Bloqueadores PDV (fix antes do cutover)

| # | Issue | Fix |
|---|-------|-----|
| B1 | `trust proxy` não configurado | `app.set('trust proxy', true)` em `backend/src/app.ts:17` |
| B2 | Socket.IO path `/socket.io/`, não `/ws/` | **Decisão pendente**: A (tunnel mapeia) ou B (muda código) |
| B3 | CORS Socket.IO hardcoded `*` | Ajustar origem fixa |
| B4 | Upload 500 MB vs limite CF 100 MB | ✅ Decidido: reduzir pra 50 MB (CFD é imagem/vídeo pequeno) |

## Decisões tomadas

- ✅ **Upload**: reduzir limite pra 50 MB → Free plan Cloudflare resolve
- ✅ **DNS**: domínios já na Cloudflare, pode criar tunnel a qualquer hora
- ✅ **Estratégia**: cenário C híbrido incremental começando por pdv-dev
- ⏳ **Socket.IO path**: aguardando confirmação (recomendado: opção A — tunnel mapeia `/socket.io/*`)

## Config proposta do cloudflared (VM 104)

```yaml
tunnel: <tunnel-id>
credentials-file: /etc/cloudflared/cert.json

ingress:
  - hostname: pdv-dev.inoveon.com.br
    path: /socket.io/.*
    service: http://localhost:4001
  - hostname: pdv-dev.inoveon.com.br
    path: /api/.*
    service: http://localhost:4001
  - hostname: pdv-dev.inoveon.com.br
    service: http://localhost:4000
  - service: http_status:404
```

## Ajustes de env necessários

**Backend** (`.env`):
```
CORS_ORIGIN=https://pdv-dev.inoveon.com.br
APP_URL=https://pdv-dev.inoveon.com.br
```

**Frontend** (via docker-entrypoint):
```
NEXT_PUBLIC_WS_URL=wss://pdv-dev.inoveon.com.br
```

## Rotas a bloquear/proteger no tunnel

- `/debug-sentry` (app.ts:92)
- `/api/v1/sync/debug-api` (sync.routes.ts:386)
- `/docs`, `/docs.json` — avaliar Zero Trust em prd

## Próximos passos (quando retomar)

1. Confirmar Socket.IO path (opção A)
2. Abrir 4 issues no repo PDV (B1, B2, B3, B4-reduced)
3. Ajustar playbooks Ansible (localizar VM `ubuntu-inoveon-build` = 10.0.10.131)
4. Snapshot Proxmox da VM 104
5. Instalar cloudflared via Ansible na VM 104
6. Criar tunnel com hostname sandbox (`pdv-dev-tunnel.inoveon.com.br`)
7. Validar 24-48h paralelo ao Traefik
8. Cutover DNS
9. Remover rota Traefik + desativar DNS `pdv-dev-api`
10. Replicar pros demais ambientes e produtos

## Tech debts descobertos (não bloqueiam)

- **PDV tem 2 axios clients duplicados** (`shared/lib/api.ts` + `services/api.ts`) — consolidar em outro momento
- **VMs sem QEMU agent** (103, 104, 105, 106, 107, 108, 109, 150, 152) — instalar pra facilitar auditorias
- **Dashboard Traefik `:8080` insecure** — quando migrar pro tunnel, proteger via Cloudflare Access

## Riscos mapeados

- Playbooks Ansible sobrescrevem config manual no Traefik — toda mudança tem que ir via playbook
- DNS Cloudflare tem TTL 5min padrão — propagação rápida, mas planeje cutover fora do horário de pico
- Socket.IO `/cfd` serve tablets físicos em lojas — se quebrar no cutover, impacto em operação real
