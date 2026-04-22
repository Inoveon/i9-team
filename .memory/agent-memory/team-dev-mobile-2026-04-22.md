---
tags:
  - mobile
  - flutter
  - riverpod
  - i9-team
  - agent-memory
agent: team-dev-mobile
project: i9-team
date: '2026-04-22'
---
# team-dev-mobile — Snapshot de memória (2026-04-22)

Snapshot consolidado do domínio **i9-team Portal / mobile Flutter**. Complementa `.claude/agent-memory/team-dev-mobile/MEMORY.md` local do projeto com detalhes-chave que devem sobreviver entre sessões.

## Stack efetiva em produção

- Flutter SDK `>=3.0.0 <4.0.0` · null safety obrigatório
- **Riverpod 2.4** sem codegen (providers à mão — `riverpod_generator` instalado mas inativo)
- **Dio 5** singleton + interceptor JWT com retry único em 401
- **Raw WebSocket** (`web_socket_channel` 3.0) — **não** Socket.IO (o CLAUDE.md da raiz menciona Socket.IO por herança, mas projeto real usa `/ws?token=<jwt>`)
- `flutter_secure_storage` 9 + fallback `shared_preferences` pra JWT e backend URL
- `go_router` 12 com `?tab=` e `?note=` em `/team/:id`
- `flutter_markdown`, `flutter_animate`, `google_fonts`, `image_picker`, `pasteboard`

## Padrões de provider

| Caso | Tipo |
|------|------|
| Lista global (ex: teams) | `AutoDisposeAsyncNotifierProvider<N, List<T>>` |
| Entidade por id (ex: team por id) | `AsyncNotifierProvider.autoDispose.family<N, T, String>` |
| Stream WS parametrizado (ex: message_stream) | `StateNotifierProvider.family<N, S, String>` |

Após mutação: `ref.invalidateSelf(); await future;` ou `refresh()` custom com `AsyncLoading + AsyncValue.guard`.

## Decisões arquiteturais chave

1. **REST pra envio de mensagem do usuário** (`POST /teams/:id/message`) em vez de emit socket.io. Razão: backend **não expõe** socket.io — só `/ws` raw. Troca feita em `team_provider.dart:105-112` e comentário explicativo preservado.
2. **Detecção cliente-side de Plan Mode**: backend não emite evento dedicado; em `MessageEvent.fromJson`, se `type == 'tool_call' && name == 'ExitPlanMode'` marco como `planMode`.
3. **`initialRoute` no main.dart**: se backend URL salvo apontar pra `localhost`/`127.0.0.1`, força `/settings` antes de montar `App` — evita tela branca no primeiro boot em device real.
4. **`FlutterSecureStorage` com `resetOnError: true`** (Android) pra não crashar quando device não tem lockscreen; fallback pra `SharedPreferences` em tudo que lê/escreve URL.
5. **WebSocket singleton por session** em `RawWsClient._channels` + `StreamController` broadcast pra múltiplos listeners da mesma session.
6. **ToastStack global** montado em `MaterialApp.builder` via `Stack`, portanto toasts funcionam em qualquer rota sem precisar de Overlay manual.
7. **`GlassContainer`** é `ClipRRect + BackdropFilter.blur(10,10) + border neonBlue @ 0.2 + surfaceGlass (0x1A00D4FF)` — radius 16 default. Padrão do Smart Pass mobile mantido aqui.

## Paleta (AppColors)

`bg #080B14` · `surface #0D1117` · `surfaceGlass #1A00D4FF` · `border #1E2A3A` · neons `blue #00D4FF / green #00FF88 / purple #7C3AED / red #FF4757 / yellow #FFD700` · `text #E2E8F0 / muted #64748B`.

## Estrutura canônica `lib/`

```
lib/
├── main.dart                  ProviderScope + initialRoute
├── app.dart                   GoRouter + ThemeData M3 + ToastStack global
├── core/{config,network,theme}/
├── shared/widgets/            (glass_container, glass_button, status_badge, empty_state, toast_stack)
└── features/
    ├── home/                  TeamsNotifier + HealthProvider
    ├── team/                  ChatTimelineView + MessageStream (WS) + MessageInput + ImageUpload
    ├── agent/                 AgentDetailProvider + PlanApprovalCard
    ├── notes/                 lista/editor/viewer + markdown
    ├── config/                ConfigRepository
    ├── settings/              backend URL
    └── upload/                ImageUploadService
```

Cada feature segue `{screens,widgets,providers,models,repository}`.

## Regra inviolável

- ❌ **NUNCA** criar `.md` no filesystem pra notas do agente.
- ✅ Notas de progresso → `mcp__i9-team__team_note_write`
- ✅ Decisões persistentes → `mcp__i9-agent-memory__note_write(_caller: "team-dev-mobile")`
- ✅ Atualizar `.claude/agent-memory/team-dev-mobile/MEMORY.md` local quando houver mudança estrutural grande

## Event types do `message_stream` (WS backend)

`userInput · claudeText · toolCall · toolResult · thinking · system · interactiveMenu · planMode` (último sintetizado no cliente).

## Débitos conhecidos

- `README.md` do mobile ainda é boilerplate do Flutter
- `riverpod_generator` no pubspec sem uso — decidir adotar ou remover
- CLAUDE.md da raiz cita `socket_io_client` (incorreto) — atualizar quando puder
- Sem testes unitários/widget próprios — só `integration_test/app_test.dart`

## Comandos úteis

```bash
cd /home/ubuntu/projects/i9-team/mobile
flutter pub get
flutter run -d chrome
flutter analyze
flutter test integration_test/app_test.dart
flutter build apk --release
```

Linter rules: `avoid_print`, `prefer_const_constructors`, `prefer_final_fields`, `prefer_single_quotes`.

## Sessões recentes relevantes

- **2026-04-22 13:36 UTC** — executei restart do orquestrador i9-team (sessão externa) pra carregar MCP Bridge Protocol novo. Nota: `orquestrador-i9-team-reiniciado`.
- **2026-04-22 14:05 UTC** — executei rollout v2 dos 7 orquestradores cross-team (remoção de `team_bridge_inbox`). Nota: `mobile-restart-bridge-v2-progresso-2026-04-22`. Todos UP com Claude Code v2.1.117 + `/team-protocol orchestrator` ativado.

## Local path canônico

- Projeto: `/home/ubuntu/projects/i9-team/`
- Mobile: `/home/ubuntu/projects/i9-team/mobile/`
- Agent memory local: `/home/ubuntu/projects/i9-team/.claude/agent-memory/team-dev-mobile/MEMORY.md`
- Definição do agente: `/home/ubuntu/projects/i9-team/.claude/agents/team-dev-mobile.md`
