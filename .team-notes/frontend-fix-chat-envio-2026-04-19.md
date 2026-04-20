# Fix — fluxo de envio de mensagem na aba CHAT — 2026-04-19

## Causa mais provável do bug

O `<form onSubmit>` original usava três padrões que quebram de forma silenciosa no mobile:

1. **`new FormData(e.currentTarget)` + `e.currentTarget.reset()` após callback async**
   No Safari iOS (e alguns Chromium Android) o `e.currentTarget` pode virar `null` no turn do event loop seguinte (event target pooling / GC). Como `onSendMessage` era assinada `(m: string) => void`, o TypeScript não forçava `await`, e o `reset()` rodava imediatamente após um callback assíncrono — potencialmente em um form já descartado.

2. **Dependência exclusiva de `type="submit"` + Enter do teclado virtual**
   O botão "Enter" visível no AgentView tinha `type="submit"` mas era estilizado como decoração. Em vários teclados virtuais Android, o tap no botão "ir / send" do teclado não dispara `submit` confiavelmente no iframe. Sem um botão Send explícito tocável, o tap no "Enter" simplesmente fechava o teclado sem enviar.

3. **Guard silencioso `if (!activeTeam || !orchestrator) return;`**
   Se o `fetchTeam` ainda não tivesse resolvido (ou se `setActiveTeam(data)` sem unwrap como antes do fix anterior deixasse `activeTeam.agents` indefinido), o handler engolia o evento sem log — o usuário via a mensagem "sumir" ao enviar.

Somados, esses três fatores explicam exatamente o sintoma: **backend sem nenhum POST registrado, UI sem feedback nenhum**.

## Arquivos editados

### 1. `src/hooks/useMessageStream.ts`
Exposto `appendLocal(type, text, extras?)` para permitir feedback otimista na timeline:

```ts
const appendLocal = useCallback((type, text, extras?) => {
  setEvents(prev => [...prev, { id: nextId(), type, text, timestamp: Date.now(), ...extras }]);
}, []);
// retorno passou de { events, clear } para { events, clear, appendLocal }
```

### 2. `src/components/AgentView.tsx`
Reescrito o form em controlled input + onKeyDown + botão Send explícito:

- `useState<string>` para `draft` + `sending` — **sem mais FormData**
- `onKeyDown: Enter → handleSend` (ignora Shift+Enter para futuras multiline)
- Botão tangível `<button type="button" onClick={() => void handleSend()}>Send</button>` sempre visível
- **Feedback otimista**: chama `appendLocal("user_input", msg)` antes do await — o user vê a mensagem no chat imediatamente
- Limpa `draft` antes do await → input pronto para próxima mensagem
- Erros no envio viram `appendLocal("system", "Falha ao enviar: ...")` na própria timeline
- Atributos mobile: `inputMode="text"`, `enterKeyHint="send"`, `autoCorrect="off"`, `autoCapitalize="sentences"`, `fontSize: 14` (evita zoom iOS)
- Logs estruturados: `[AgentView] enviando mensagem {session, msg}` → `OK` ou `FAIL`

### 3. `src/components/AgentPanel.tsx`
Mesma modernização para o fallback (quando o agente não tem `sessionId`):

- Removido `<form onSubmit>` + FormData
- `useState + onKeyDown + onClick` no botão Send
- Logs `[AgentPanel]`
- Mesmos atributos mobile

### 4. `src/app/team/[project]/[team]/page.tsx`
`handleSendMessage` com logs explícitos em cada passo e **lança erro** em vez de return silencioso — assim o `AgentView` consegue mostrar o erro no chat via `appendLocal("system", ...)`:

```ts
console.log("[TeamPage] POST /teams/:id/message", {teamId, agentName, agentId, message});
try {
  const resp = await api.post(`/teams/${activeTeam.id}/message`, payload);
  console.log("[TeamPage] POST /message OK", resp);
} catch (err) {
  console.error("[TeamPage] POST /message FAIL", err);
  throw err; // repassa p/ AgentView mostrar no chat
}
```

Guards agora lançam mensagem útil em vez de retornar vazio:
- `!activeTeam` → `throw new Error("Team ainda não carregado — aguarde.")`
- `!orchestrator` → `throw new Error("Nenhum orquestrador configurado neste team.")`

## Validação backend (reconfirmada)

```
POST /teams/cmo5orcto000a41lxf2dsrf33/message
body: {"agentId":"cmo5orctu000b41lxaanfxgxv","message":"teste do orquestrador via curl"}
→ HTTP 200 {"ok":true,"session":"proxmox-infrastructure-infra-orquestrador","agent":"team-orchestrator"}
```

Endpoint OK, problema era 100% frontend.

## Bônus detectado (e descartado)

Na inspeção anterior reportei que `role` vinha como `"agent"` do endpoint `/teams/:project/:team`. Reverificando agora com curl:

```
team-orchestrator → role=orchestrator
team-infra        → role=worker
team-ops          → role=worker
team-dev-backend  → role=worker
team-dev-service  → role=worker
```

Backend já retorna `worker` correto — inconsistência anterior sumiu (ou vi errado). **Nenhuma ação adicional necessária.**

## Compile & hot reload

```
✓ Compiled in 696ms (1887 modules)
GET /team/proxmox-infrastructure/infra 200
GET /team/i9-team/dev 200
npx tsc --noEmit → 0 erros (após limpar .next/types/app/teams stale)
```

**Não foi necessário reiniciar o frontend** — hot reload do Next aplicou tudo sozinho.
Limpei apenas `.next/types/app/teams/` que era cache stale referenciando a rota `/teams/[id]` deletada na tarefa anterior.

## Como testar no celular agora

1. Abrir `http://10.0.10.17:4021/team/proxmox-infrastructure/infra`
2. No painel do orquestrador, clicar na aba **CHAT**
3. Digitar qualquer mensagem → Enter no teclado OU tocar no botão **Send**
4. Esperado:
   - Mensagem aparece **imediatamente** no chat como user_input (feedback otimista)
   - Input limpa
   - Botão vira "..." durante o envio
   - Log no console: `[AgentView] enviando` → `[TeamPage] POST /teams/:id/message` → `OK`
   - Backend loga o POST em `i9team-svc-backend`
   - Terminal do orquestrador recebe a mensagem no tmux
