---
title: Backlog — MCP team-media-studio + skills de entrega profissional
tags:
  - backlog
  - mcp
  - arquitetura
  - skills
  - pdf
  - relatorio
  - apresentacao
  - remotion
date: '2026-04-23'
status: backlog
projeto: i9-team
prioridade: alta
---
# Backlog — MCP team-media-studio + skills de entrega profissional

## Motivação

Durante a Fase 0 Multi-Client (2026-04-23), geramos ad-hoc um PDF de benchmark via Puppeteer + HTML/CSS manual. Ficou bom, mas:
- Cada relatório futuro exige reinventar o processo (HTML + CSS + script Puppeteer)
- Sem padrão visual Inoveon consistente
- Agentes não-Claude (Gemini, Codex) não têm como gerar esse tipo de entrega sem replicar todo o setup

Valor de criar uma MCP reutilizável: **padroniza + acelera + democratiza** entregas profissionais pra todos os clientes da frota.

## Escopo proposto

### MCP nova: `team-media-studio`

Tools a expor:
- `media_pdf_from_html(html, options)` → gera PDF via Puppeteer/Chromium bundled
- `media_pdf_from_markdown(md, options)` → aplica template + converte pra PDF
- `media_report(title, sections, charts, metadata)` → monta relatório com template corporativo
- `media_chart(type, data, options)` → retorna HTML com Chart.js/D3 embutido
- `media_diagram(type, source)` → Mermaid / Excalidraw / PlantUML → PNG/SVG
- `media_html_landing(title, sections, theme)` → landing page HTML
- `media_deck(slides, theme)` → Reveal.js deck HTML ou PDF
- `media_video(composition, data, format)` → Remotion render (MP4/GIF)
- `media_upload(file_path, destination)` → upload pra S3/Cloudflare R2 e retorna URL pública (pra WhatsApp/email)

### Skills associadas

| Skill | Função |
|---|---|
| `/team-report <tema>` | Gera relatório com template corporativo baseado em dados coletados |
| `/team-deck <tema>` | Gera deck de apresentação (slides ou vídeo Remotion) |
| `/team-pdf <input>` | Converte qualquer input (HTML, MD, URL) em PDF profissional |
| `/team-chart <dados>` | Gera gráfico standalone HTML/PNG |
| `/team-diagram <descrição>` | Gera diagrama a partir de descrição natural |

### Stack técnica

- **PDF**: Puppeteer + Chromium bundled (já validado no benchmark)
- **Gráficos**: Chart.js (simples) + D3 (complexos)
- **Markdown → PDF**: md-to-pdf (já instalado) ou `@marp-team/marp-cli`
- **Diagramas**: Mermaid CLI + Excalidraw programmatic
- **Apresentações**:
  - **Reveal.js** pra slides HTML interativos
  - **Remotion** pra vídeo programático (React-based) → gera MP4 com animações, ideal pra briefings, onboarding, relatórios em vídeo
- **Identidade visual Inoveon**: tokens de design (cores, tipografia, espaçamentos) + templates pré-desenhados (letterhead, rodapé com logo, paleta corporativa)
- **Templates como código**: cada template é um HTML+CSS+JS versionado no repo da MCP, aceita variáveis

### Princípios

1. **Templates-first**: cada entrega tem template oficial; customização é extensão, não exceção
2. **Cross-client**: funciona igual no Claude, Gemini e Codex — é MCP padrão stdio
3. **Assets remotos**: logos, fontes, paletas em CDN interno ou Cloudflare R2
4. **Reproducibilidade**: input determinístico → output idêntico (pra versionamento)
5. **Dois modos de output**: arquivo local (path) OU URL pública (via upload automático)

## Apresentações com Remotion

**O que é**: framework React pra criar vídeos programáticos. Você escreve componentes React + timing + animações → renderiza MP4.

**Casos de uso no i9-team/Inoveon**:
- Vídeos de onboarding automáticos (ex: "novo funcionário + dados → vídeo de boas-vindas personalizado")
- Relatórios mensais em vídeo (4 slides animados + narração TTS)
- Explicação de features novas (release notes em vídeo curto)
- Compartilhamento em WhatsApp/LinkedIn (vídeo é mais engagement que texto/PDF)

**Complexidade**: alta mas isolável — pode ser a última fase de implementação da MCP.

## Integrações diretas com o que já temos

- **Evolution API** (WhatsApp): já temos `evolution_send_document` + `evolution_send_video` — o team-media-studio gera, Evolution entrega
- **Vault i9-agent-memory**: armazena notas que viram input do relatório (ex: `/team-report benchmarks/multi-client-...` lê a nota e gera PDF)
- **teams.json**: o relatório pode ser dirigido a um agente/team (ex: header fica "Relatório do team i9-team/dev")

## Roadmap sugerido (pra implementar depois)

1. **MVP MCP** com `media_pdf_from_html` e `media_pdf_from_markdown` — replicar o que fizemos hoje mas numa tool
2. **Template corporativo básico** (Inoveon brand — logo, paleta, tipografia)
3. **Skill `/team-report`** usando os 2 primeiros
4. **Gráficos via `media_chart`** embedados no template
5. **Diagramas** (Mermaid) e `/team-diagram`
6. **Deck Reveal.js** e `/team-deck` (slides HTML)
7. **Remotion video** como última fase (complexidade alta)

## Referências / estudos prévios

- [Puppeteer PDF docs](https://pptr.dev/api/puppeteer.page.pdf/)
- [Remotion](https://www.remotion.dev/)
- [Reveal.js](https://revealjs.com/)
- [Marp](https://marp.app/) — markdown → slides/PDF
- [Mermaid CLI](https://github.com/mermaid-js/mermaid-cli)
- Case: como a Linear gera relatórios de incidente automatizados

## Issue GitHub

Issue pública criada no repo `i9-team` em 2026-04-23 pra rastrear implementação.
