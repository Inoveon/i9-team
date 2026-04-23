# i9-tools — Guia de Tokens e Credenciais

Guia único pra destravar todas as integrações do `i9-tools`. Todas as credenciais moram em **`~/.i9-tools/.env`** (chmod 600).

## Como as tools carregam as credenciais

Cada tool que precisa de auth lê do arquivo acima via `loadI9Env()` antes de executar. Se faltar qualquer variável obrigatória, a tool retorna **mensagem clara** dizendo exatamente qual var tá faltando e onde pegar.

**Nenhuma credencial commita no código** — o arquivo `.env` fica só no filesystem local, permissão 600.

---

## 1. 🎨 Geração de imagem (Gemini Nano Banana, Imagen)

Tools: `i9_tools_image_generate`, `i9_tools_avatar_create`, `i9_tools_avatar_list`, `i9_tools_avatar_delete`

### Variáveis

```env
GEMINI_API_KEY=AIza...
```

### Como pegar

1. **Habilitar billing** no Google Cloud pro projeto (obrigatório — free tier tem quota 0 pra modelos de imagem)
   - https://console.cloud.google.com/billing
   - Vincula conta de faturamento (aceita cartão Brasileiro)
   - Novos cadastros ganham **US$ 300 em créditos free por 90 dias**
2. Criar/confirmar a API key em https://aistudio.google.com/apikey
3. **ROTACIONAR** a key anterior (se já foi exposta em print/chat):
   - Delete a antiga → Create new → cola a nova em `~/.i9-tools/.env`

### Preço referência

- Imagen 4 Fast: ~US$ 0.02/imagem
- Nano Banana Pro Preview: ~US$ 0.03-0.05/imagem
- Texto (Gemini Flash) continua com free tier generoso

---

## 2. ☁️ Upload S3 / Cloudflare R2

Tool: `i9_tools_upload_s3`

### Variáveis (AWS S3)

```env
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=sa-east-1
AWS_S3_BUCKET=meu-bucket
```

### Variáveis (Cloudflare R2 — S3-compatible)

```env
AWS_ACCESS_KEY_ID=<r2-access-key-id>
AWS_SECRET_ACCESS_KEY=<r2-secret-access-key>
AWS_REGION=auto
AWS_S3_BUCKET=meu-bucket-r2
AWS_S3_ENDPOINT=https://<accountid>.r2.cloudflarestorage.com
```

### Como pegar (AWS)

1. Console AWS → IAM → Users → Create user → programmatic access
2. Attach policy: `AmazonS3FullAccess` (ou custom policy restrita ao bucket)
3. Copia `Access key ID` + `Secret access key`

### Como pegar (Cloudflare R2)

1. Cloudflare Dashboard → R2 → "Manage R2 API Tokens"
2. Create API token com permissões "Object Read & Write"
3. Copia Access Key ID + Secret Access Key (exibidos uma vez só)
4. Endpoint: em R2 → bucket → Settings → **S3 API endpoint**

### Dependência

- `aws` CLI instalado (geralmente já vem) — testa com `which aws`

### Inoveon — onde pode estar

O usuário mencionou que tem credenciais em `.crypt/` do i9-smart-pdv, mas o diretório está criptografado com `git-crypt`. Pra extrair, precisa da chave simétrica do `.git-crypt-key` (fora do repo).

---

## 3. 📁 Google Drive / Sheets / Gmail

Tools: `i9_tools_gdrive_upload`, `i9_tools_gsheets_append`, `i9_tools_gmail_send`

### Variáveis

```env
GOOGLE_CLIENT_ID=...apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-...
GOOGLE_REFRESH_TOKEN=1//...
```

### Setup OAuth (one-time, ~10 min)

1. **Cria projeto** em https://console.cloud.google.com (se não tiver)
2. **Habilita APIs** em "APIs & Services → Library":
   - Google Drive API
   - Google Sheets API
   - Gmail API
3. **OAuth consent screen**:
   - User type: External (ou Internal se Google Workspace)
   - Scopes: adiciona `drive.file`, `spreadsheets`, `gmail.send`
4. **Credentials → Create Credentials → OAuth client ID**:
   - Type: Desktop app
   - Copia `Client ID` + `Client Secret`
5. **Gerar refresh token** (one-time):
   - Usa OAuth Playground https://developers.google.com/oauthplayground
   - Settings (⚙️) → "Use your own OAuth credentials" → cola Client ID/Secret
   - Seleciona scopes: drive.file, spreadsheets, gmail.send
   - Authorize → login → Exchange authorization code for tokens
   - Copia o `Refresh token`
6. Salva os 3 em `~/.i9-tools/.env`

### Alternativa mais fácil: usar Service Account

Se o destino é pasta compartilhada de Drive, pode usar Service Account em vez de OAuth user:
1. IAM → Service Accounts → Create
2. Download JSON key
3. Compartilha a pasta Drive com o email da SA
4. Código diferente (posso adaptar se preferir)

---

## 4. 💬 Chat corporativo — **Mattermost** (futuro)

> Antes tinha seção Slack aqui. **Decisão 2026-04-23**: Inoveon vai usar Mattermost self-hosted no lugar. Issue rastreando: [i9-team#2](https://github.com/Inoveon/i9-team/issues/2). Tool `i9_tools_slack_send` existe no código mas está **desativada** (comentada no `index.ts`) — preservada como referência porque a API REST do Mattermost é ~80% compatível com Slack.

Sem credenciais necessárias até o Mattermost entrar em produção.

---

## 5. 🔑 Configuração final — arquivo `.env` completo

Quando tiver todas as credenciais, seu `~/.i9-tools/.env` fica assim:

```env
# i9-tools — secrets (chmod 600)
# NÃO commitar, NÃO logar em output.

# Geração de imagem
GEMINI_API_KEY=AIza...

# Upload S3/R2
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=sa-east-1
AWS_S3_BUCKET=inoveon-reports
# Se Cloudflare R2, descomente:
# AWS_S3_ENDPOINT=https://<accountid>.r2.cloudflarestorage.com

# Google Drive / Sheets / Gmail
GOOGLE_CLIENT_ID=....apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-...
GOOGLE_REFRESH_TOKEN=1//...

```

**Permissão obrigatória**: `chmod 600 ~/.i9-tools/.env`

---

## Checklist de ativação

- [ ] Gemini: billing habilitado + key rotacionada em `~/.i9-tools/.env`
- [ ] S3/R2: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_S3_BUCKET` no `.env` (+ `AWS_S3_ENDPOINT` se R2)
- [ ] Google: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN` no `.env` + APIs habilitadas

Com tudo preenchido, **14 tools adicionais** ficam funcionais (ou 37 total). Posso fazer smoke test de cada integração quando ativar.

---

## Rotacionar qualquer credencial exposta

Sempre que uma credencial aparecer em print/log/chat:

1. Na origem (AWS/Google/Slack/etc) → delete/disable a key antiga
2. Gera nova
3. Atualiza só o valor em `~/.i9-tools/.env`
4. Nenhum código precisa mudar — todas as tools recarregam via `loadI9Env()` a cada invocação
