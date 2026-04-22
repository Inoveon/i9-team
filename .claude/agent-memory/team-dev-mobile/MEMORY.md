# team-dev-mobile — Memória Persistente

> Atualizado em 2026-04-22. Mantenho este arquivo pra recuperar contexto rápido em sessões futuras.
> Projeto: **i9-team Portal** — app mobile Flutter em `/home/ubuntu/projects/i9-team/mobile/`.

---

## 1. Stack canônica

| Camada | Pacote | Versão pubspec | Uso |
|--------|--------|----------------|-----|
| Framework | `flutter` SDK | `>=3.0.0 <4.0.0` | Null safety obrigatório |
| Estado | `flutter_riverpod` | `^2.4.0` | `StateNotifier`, `AsyncNotifier`, `AutoDisposeFamilyAsyncNotifier` |
| Codegen Riverpod | `riverpod_annotation` + `riverpod_generator` | `^2.3.0` | Disponível mas **não em uso** — providers escritos à mão |
| Navegação | `go_router` | `^12.0.0` | Rotas declarativas + queryParameters pra tabs |
| HTTP | `dio` | `^5.3.0` | Singleton com interceptor JWT + retry 401 |
| WebSocket | `web_socket_channel` | `^3.0.0` | **Raw WS** (não Socket.IO) em `/ws?token=...` |
| Storage seguro | `flutter_secure_storage` | `^9.0.0` | JWT + URL backend; fallback `shared_preferences` |
| Prefs simples | `shared_preferences` | `^2.2.0` | Fallback quando secure storage falha |
| Fontes | `google_fonts` | `^6.1.0` | Usado via `AppTextStyles` |
| Upload | `image_picker` + `pasteboard` | — | Feature `upload/` |
| Markdown | `flutter_markdown` | `^0.7.0` | Visualização de notas |
| Animações | `flutter_animate` | `^4.5.0` | Micro-interações |
| Testes | `integration_test` + `flutter_test` | — | `mobile/integration_test/app_test.dart` |

**⚠ Importante — que NÃO usamos:**
- ❌ `socket_io_client` (o CLAUDE.md de raiz ainda menciona — ignorar, backend é **raw WS**)
- ❌ `setState` em telas principais (só em widgets stateful pequenos tipo `MessageInput`)
- ❌ `freezed` / `json_serializable` — JSON manual em factories `fromJson`

---

## 2. Estrutura do projeto (lib/)

```
lib/
├── main.dart                       # ProviderScope + initialRoute (detecta localhost → /settings)
├── app.dart                        # GoRouter + MaterialApp.router + ToastStack global
├── core/
│   ├── config/
│   │   └── app_config.dart         # JWT, baseUrl, autoLogin (admin/i9team), ensureJwt()
│   ├── network/
│   │   ├── api_client.dart         # Dio singleton + interceptor Authorization + retry 401
│   │   └── raw_ws_client.dart      # WebSocket singleton por session (subscribe/input/select_option)
│   └── theme/
│       ├── app_colors.dart         # Paleta dark/neon
│       └── app_text_styles.dart    # Tipografia
├── shared/
│   └── widgets/
│       ├── glass_container.dart    # BackdropFilter blur(10) + border neonBlue 0.2
│       ├── glass_button.dart
│       ├── status_badge.dart
│       ├── empty_state.dart
│       └── toast_stack.dart        # Montado globalmente em App.builder
└── features/
    ├── home/          # HomeScreen + TeamCard + TeamsNotifier + HealthProvider
    ├── team/          # TeamScreen + ChatTimelineView + MessageInput + MessageStream
    ├── agent/         # AgentScreen + PlanApprovalCard + AgentDetailProvider
    ├── notes/         # NotesListScreen + Editor + Viewer + NotesRepository
    ├── config/        # ConfigScreen + ConfigRepository
    ├── settings/      # SettingsScreen (backend URL)
    └── upload/        # ImageUploadService + ImageUploadWidget + UploadResult
```

Padrão `features/<feat>/{screens,widgets,providers,models,repository}`.

---

## 3. Convenções — Riverpod

### Providers escritos à mão (sem codegen)

Três padrões em uso:

**a) `AutoDisposeAsyncNotifier<T>`** — lista global (ex: `TeamsNotifier`):
```dart
class TeamsNotifier extends AutoDisposeAsyncNotifier<List<TeamModel>> {
  @override
  Future<List<TeamModel>> build() => _fetch();
  Future<void> refresh() async { state = const AsyncLoading(); state = await AsyncValue.guard(_fetch); }
}

final teamsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<TeamsNotifier, List<TeamModel>>(TeamsNotifier.new);
```

**b) `AutoDisposeFamilyAsyncNotifier<T, ARG>`** — entidade por id (ex: `TeamNotifier`):
```dart
class TeamNotifier extends AutoDisposeFamilyAsyncNotifier<TeamDetailModel, String> {
  @override
  Future<TeamDetailModel> build(String arg) { teamId = arg; return _fetch(teamId); }
  late final String teamId;
}

final teamNotifierProvider =
    AsyncNotifierProvider.autoDispose.family<TeamNotifier, TeamDetailModel, String>(TeamNotifier.new);
```

**c) `StateNotifierProvider.family`** — stream WebSocket parametrizado (ex: `MessageStreamNotifier`):
```dart
final messageStreamProvider = StateNotifierProvider.family<
    MessageStreamNotifier, MessageStreamState, String>(
  (ref, session) => MessageStreamNotifier(session),
);
```

### Refresh pós-mutação

```dart
await dio.post(...);
ref.invalidateSelf();
await future;     // reexecuta build() e aguarda
```

Ou via `refresh()` custom que faz `AsyncLoading + AsyncValue.guard`.

### NUNCA

- ❌ `setState` em telas principais (`HomeScreen`, `TeamScreen`, `AgentScreen`, etc.)
- ✅ OK em widgets stateful triviais (`MessageInput` com controller local)

---

## 4. Convenções — Modelos

- **Sem codegen**: factory `fromJson(Map<String, dynamic>)` e `copyWith` manuais
- Sempre tolerantes: `(json['x'] as String?) ?? 'fallback'`
- Listas: `List<String>.from((json['outputLines'] as List?) ?? [])`
- Enums: parser explícito (`_parseType(raw)`) com fallback pro membro neutro (`system`)

Exemplo: `features/team/models/message_event.dart` deserializa o evento `message_stream` do WS com tipos:
`userInput | claudeText | toolCall | toolResult | thinking | system | interactiveMenu | planMode`.

**Detecção cliente-side de Plan Mode**: quando `tool_call` tem `name == 'ExitPlanMode'`, marco como `planMode`. O backend **não emite** evento dedicado — detecção é aqui.

---

## 5. Convenções — Rede

### REST (Dio)

- Singleton lazy via `ApiClient.getInstance()` — `dio` reconstruído quando `reset()` for chamado
- Interceptor em toda request: `AppConfig.ensureJwt()` e seta `Authorization: Bearer <token>`
- Em 401: limpa JWT, refaz `autoLogin()`, retry único da request original via `dio.fetch(opts)`
- Timeouts: `connect 10s` · `receive 30s`

### WebSocket raw em `/ws?token=<jwt>`

- **NUNCA** Socket.IO — backend usa WS cru
- Conexão singleton por `session` em `RawWsClient._channels`
- Conversão de URL: `http://` → `ws://`, `https://` → `wss://`
- Após conectar envia `{"type":"subscribe","session":"..."}`
- Recebe `{"type":"message_stream","events":[...]}` → broadcast via `StreamController` por session
- Envio de input: `{"type":"input","keys":"..."}` (equivale a tmux send-keys)
- Seleção de menu: `{"type":"select_option","session":"...","value":"2","currentIndex":1}`
- `disconnect()` / `disconnectAll()` fecham sinks e StreamControllers

### REST vs WS — regra importante

Envio de mensagem de usuário é via **REST `POST /teams/:id/message`** (resolve backend em `sendKeys(sessionName, content)`). Fiz essa migração **exatamente porque** o código anterior tentava `socket.emit('orchestrator_message',…)` que **não existe no backend**. Comentário do código em `team_provider.dart:105-112` preserva essa decisão.

---

## 6. Tema — Glass/Dark

### `AppColors` (lib/core/theme/app_colors.dart)

```dart
bg            = Color(0xFF080B14)   // fundo global
surface       = Color(0xFF0D1117)   // AppBar, barras
surfaceGlass  = Color(0x1A00D4FF)   // glass containers (10% neonBlue)
border        = Color(0xFF1E2A3A)
neonBlue      = Color(0xFF00D4FF)   // primary
neonGreen     = Color(0xFF00FF88)   // status ok
neonPurple    = Color(0xFF7C3AED)   // secondary
neonRed       = Color(0xFFFF4757)
neonYellow    = Color(0xFFFFD700)
text          = Color(0xFFE2E8F0)
textMuted     = Color(0xFF64748B)
```

### GlassContainer padrão

- `BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10))`
- `BoxDecoration(color: surfaceGlass, border: neonBlue @ 0.2, borderRadius: 16)`
- Padding default `EdgeInsets.all(16)`
- Clipado via `ClipRRect` por causa do blur

### MaterialApp

- `useMaterial3: true`
- `ColorScheme.dark(surface, primary=neonBlue, secondary=neonPurple)`
- `scaffoldBackgroundColor: bg`
- `debugShowCheckedModeBanner: false`
- `builder:` envolve child em `Stack` com `ToastStack` global (pra toasts flutuantes em qualquer rota)

---

## 7. Navegação — GoRouter

Rotas em `lib/app.dart`:

| Path | Screen |
|------|--------|
| `/` | `HomeScreen` |
| `/team/:id` | `TeamScreen(teamId, initialTab?, initialNote?)` — query `?tab=` e `?note=` |
| `/team/:id/notes` | redirect → `/team/:id?tab=notes` (backcompat) |
| `/settings` | `SettingsScreen` (backend URL) |
| `/config` | `ConfigScreen` |

**Regra de `initialRoute` em `main.dart`**: se backend apontar pra `localhost`/`127.0.0.1`, joga direto em `/settings`. Evita tela branca no primeiro boot em devices reais.

---

## 8. Auth + Storage

- `AppConfig._storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true), iOptions: IOSOptions(accessibility: first_unlock))`
  - `resetOnError: true` evita crash em Android sem lockscreen
- Chaves: `backend_url`, `jwt_token`
- Fallback pra `shared_preferences` em todas as leituras/escritas de URL (defensivo)
- Timeout `3s` em reads do secure storage pra não travar UI
- Credenciais default: `admin / i9team` (espelham `.env` do backend) — usadas em `autoLogin()`
- URL default: `http://localhost:4020`

---

## 9. Protocolo do agente (team-dev-mobile)

Ao receber uma tarefa do orquestrador (via `mcp__i9-team__team_send`):

1. Responder **"Entendido. Iniciando implementação de [feature]."**
2. Implementar respeitando as convenções acima
3. **NUNCA** criar `.md` no filesystem — todas as notas via MCP:
   - `mcp__i9-team__team_note_write(name, content)` — progresso/resultado pro orquestrador
   - `mcp__i9-agent-memory__note_write(path, content, _caller: "team-dev-mobile")` — decisões persistentes
4. **NUNCA** delegar pra outros agentes (não uso `Agent` tool)
5. Finalizar com resumo + como rodar no emulador (`flutter run`, `flutter build apk`)

Permissões em `.claude/settings.json` já liberam: `Bash`, `Edit`, `Read`, `Write`, `Glob`, `Grep`, `mcp__i9-team__*`, `mcp__i9-agent-memory__*`, `mcp__evolution-api__*`, `mcp__db-manager__*`, `mcp__plugin_context-mode_*`, `mcp__plugin_telegram_*`.

---

## 10. Tasks já entregues / em uso

- ✅ Estrutura `core/` (config/theme/network) — completa
- ✅ `GlassContainer` + `AppColors` + `AppTextStyles` — base visual
- ✅ Auth JWT com autoLogin + retry 401
- ✅ WebSocket `message_stream` tipado com 8 tipos de evento
- ✅ Tela Home + TeamCard + criar/start/stop/delete team
- ✅ TeamScreen com tabs (chat, notas) + MessageInput + ImageUpload
- ✅ AgentScreen com PlanApprovalCard
- ✅ Feature de Notas (list/editor/viewer + markdown)
- ✅ Detecção cliente-side de Plan Mode via `ExitPlanMode`
- ✅ ToastStack global em Stack do builder

## 11. Débitos técnicos conhecidos

- `README.md` do mobile é o boilerplate do Flutter — reescrever quando sobrar tempo
- `riverpod_generator` está no pubspec mas **não usado** — decidir: adotar codegen ou remover
- CLAUDE.md da raiz menciona `socket_io_client` mas projeto usa **raw WS** — atualizar doc de raiz quando puder
- Sem testes de widget próprios — só `integration_test/app_test.dart` (ver skill `mobile-integration-tests`)

---

## 12. Comandos úteis pro futuro-eu

```bash
# Rodar no emulador/web
cd /home/ubuntu/projects/i9-team/mobile
flutter pub get
flutter run -d chrome            # web
flutter run -d <android-id>      # android

# Lint estrito (definido em analysis_options.yaml)
flutter analyze

# Integration test
flutter test integration_test/app_test.dart

# Build release
flutter build apk --release
flutter build web
```

Linter rules ativas (`analysis_options.yaml`):
`avoid_print`, `prefer_const_constructors`, `prefer_final_fields`, `prefer_single_quotes`.
