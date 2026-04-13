# SPEC.md — legacy backoffice automation (Lark-native backoffice system)

## コンセプト

**特定の外部SaaS名称を前面に出さずに、Lark（飛書）だけでバックオフィス機能を実現する。**

Lark の Base・フォーム・承認ワークフロー・Bot・lark-cli と、組み込みの Express サーバーを組み合わせ、
経費精算・請求書管理・稟議申請などの業務フローを Lark 上に構築する。

---

## 前提技術

### lark-cli（公式 CLI）
- リポジトリ: https://github.com/larksuite/cli
- 200+ コマンド・21 AI Agent Skills（Go製・npm配布）
- `legacy-backoffice` はこれをオーケストレートするラッパーとして実装

### legacy-backoffice サーバー（Express）
- Lark Webhook の受信・処理（Callback / OCR / Approval）を担う
- `tenant_access_token` の自動取得・90 分ごとのリフレッシュをプロセス内で管理
- 外部 API（freee 等）との連携もこのサーバーで処理

---

## 機能対応表（調査完了版）

| 対象バックオフィス機能 | Lark 代替方法 | 判定 | 実装難易度 |
|------------|------------|------|----------|
| 経費申請フォーム | Base Form（添付・条件分岐対応） | ✅ 可 | 低 |
| 多段階承認ワークフロー | Lark Approval（無制限ステップ） | ✅ 可 | 低 |
| 差し戻し・否決 | Approval tasks.reject（user token 必須） | ✅ 可 | 中 |
| Bot 承認通知（ボタン付き） | Interactive Card 2.0 + Callback Server | ✅ 可（要開発） | 高 |
| 支出分析ダッシュボード | Base Dashboard + グラフ（CLI 自動化可） | ✅ 可 | 低 |
| ワークフロー自動化（通知系） | Base Automation +workflow-create | ✅ 可 | 低 |
| 勤怠・工数管理 | lark-attendance Skill | ✅ 可 | 低 |
| フォーム CLI 自動作成 | +form-create / +form-questions-create | ✅ 可 | 低 |
| 領収書 OCR 自動入力 | Lark OCR API + Claude API（/ocr エンドポイント） | ✅ 実装済 | 中 |
| 会計ソフト連携（freee/MF） | Express サーバー経由 HTTP 連携 | ⚠️ 要開発 | 中 |
| Approval インスタンス作成 | Express /approval-create エンドポイント（lark-cli 未対応） | ✅ 実装済 | 中 |
| HTTP Request Automation 設定 | Base Automation から /approval-create を呼び出し | ✅ 可 | 低 |
| 電子帳簿保存法対応 | JIIMA 認証なし | ❌ 不可 | - |
| インボイス制度（番号検証） | 対応なし | ❌ 不可 | - |
| IC カード交通費自動取込 | 対応なし | ❌ 不可 | - |

---

## アーキテクチャ全体像

```
[申請者]
  │
  ├─ Lark フォーム（+form-create で CLI 自動作成）
  │     ↓ フォーム送信 → Base Automation（+workflow-create）
  ├─ Lark Base テーブル（データ蓄積）
  │     ↓ Automation → HTTP Request → legacy-backoffice サーバー
  │
  ├─ legacy-backoffice サーバー（Express / Node.js）
  │   ├─ tenant_access_token 取得・管理（プロセス内 setInterval）
  │   ├─ POST /approval-create — Approval インスタンス作成 + Card 送信
  │   ├─ POST /callback — Interactive Card 承認/却下処理
  │   ├─ POST /ocr — 領収書 OCR パイプライン（Lark OCR → Claude Haiku → Base）
  │   └─ POST /freee-sync — 承認済レコード → freee 連携（オプション）
  │     ↓
  ├─ Lark Approval（承認フロー管理）
  │   ├─ card.action.trigger 受信（3秒以内レスポンス必須）
  │   ├─ 承認者の user_access_token で tasks.approve/reject
  │   └─ Base レコード更新 + 申請者へ結果通知
  │
  └─ Base ダッシュボード（+dashboard-create で CLI 自動作成）

[legacy-backoffice CLI]
  └─ lark-cli コマンド群をオーケストレート
```

---

## 未実装機能の解決方法（詳細）

---

### 1. 領収書 OCR 自動入力

**問題**: Lark OCR API は `text_list`（文字列配列）を返すだけで構造化データ抽出不可。

**必要スコープ**: `im:message.file_link:readonly`（Bot が受信した画像をダウンロードするために必須）

**解決方法**: `POST /ocr` エンドポイント（`src/server/index.ts`）による 2 段階パイプライン

```
ユーザー → Lark Bot に領収書画像を送信
  ↓ im.message.receive_v1 Webhook → legacy-backoffice サーバー POST /ocr
  ↓ GET /im/v1/images/{image_key}（image_key を content から取得）
  ↓ POST /optical_char_recognition/v1/image/basic_recognize（base64 送信）
  ↓ text_list を Claude Haiku API に送信 → 構造化 JSON 抽出
     { vendor_name, date, total_amount, tax_amount }
  ↓ POST /bitable/v1/.../records → Base にレコード挿入
  ↓ Bot が「登録完了: 店名 / 日付 / ¥金額」を返信
```

**コスト試算**: Claude Haiku で 1 枚あたり $0.001 未満。

**高精度が必要な場合**: Azure Document Intelligence `prebuilt-receipt` モデル。
- 出力: `MerchantName` / `TransactionDate` / `Total` / `Tax` / `Items[]` を直接構造化出力
- コスト: $1.5 / 1,000 ページ

---

### 2. tenant_access_token 管理

**問題**: `tenant_access_token` は 2 時間で失効する。定期的な再取得が必要。

**解決方法**: `src/lark/auth.ts` の `startTokenRefresh()` でサーバー起動時にトークンを取得し、`setInterval` で 90 分ごとに自動リフレッシュする。

```typescript
// サーバー起動時に実行
await startTokenRefresh()

// 内部実装: 90分ごとに再取得
setInterval(async () => {
  _tenantToken = await fetchTenantToken()
}, 90 * 60 * 1000)
```

他のモジュールは `getTenantToken()` を呼び出すだけでよい（キャッシュ済みトークンを返す）。

---

### 3. Approval インスタンス自動作成（Blocker 修正済み）

**問題**: `lark-cli approval instances create` コマンドが存在しない。

**解決方法**: `POST /approval-create` エンドポイントが Approval API を直接呼び出す。

**前提条件: Approval テンプレートのフィールド構造**

Lark 管理画面で作成した「経費精算申請」テンプレートのフィールド ID を確認します。

```bash
# Lark API で Approval テンプレートのフィールド定義を取得
lark-cli api GET /open-apis/approval/v4/approvals \
  --params '{"approval_codes":["{{ $env.EXPENSE_APPROVAL_CODE }}"]}' \
  --as bot | jq '.data.approval_forms[].form_schema'
```

出力例:
```json
{
  "form_schema": [
    { "id": "input_1", "type": "input", "name": "金額", "required": true },
    { "id": "select_1", "type": "select", "name": "カテゴリ", "required": true },
    { "id": "textarea_1", "type": "textarea", "name": "用途", "required": true },
    { "id": "date_1", "type": "date", "name": "申請日", "required": true }
  ]
}
```

**重要**: このフィールド ID (`input_1`, `select_1`, ...) を `.env` に保存します。

```env
# Approval テンプレートのフィールド ID
APPROVAL_FIELD_AMOUNT=input_1
APPROVAL_FIELD_CATEGORY=select_1
APPROVAL_FIELD_PURPOSE=textarea_1
APPROVAL_FIELD_DATE=date_1
```

**`POST /approval-create` エンドポイント（`src/server/index.ts`）**

Base Automation の「HTTP Request」アクションから呼び出す:

```
Base Automation（フォーム送信トリガー）
  ↓ HTTP Request → legacy-backoffice サーバー POST /approval-create
  Body: { record_id, applicant_id, approver_id, subject, amount, category, form_json }
  ↓
createApprovalInstance() → POST /approval/v4/instances
  ↓
writeInstanceCode() → Base レコードに instance_code を保存
  ↓
sendApprovalCard() → 承認者の DM に Interactive Card 送信
```

**重要ポイント**:
1. **form フィールドは JSON 文字列として渡す**: `JSON.stringify(form)` した結果を `form_json` に設定
2. **フィールド ID は環境変数で管理**: Approval テンプレート作成時に確認した ID を `.env` に保存
3. **数値フィールドは文字列に変換**: 金額などの数値は `String()` で明示的に変換
4. **API レスポンスから instance_code を取得**: Base に保存して Callback で参照

**トラブルシューティング**:
| エラー | 原因 | 対処 |
|------|------|------|
| `400 invalid form` | フィールド ID が不一致 | Approval テンプレートの `form_schema` を再確認 |
| `400 form value invalid` | 値の型が不正 | 数値は `String()` で変換 |
| `401 unauthorized` | tenant_token が無効 | サーバーを再起動してトークンを再取得 |
| `403 forbidden` | 承認者 ID が不正 | Base Automation から渡された `承認者.id` を確認 |

---

### 4. Interactive Card 承認ボタン + Callback Server

**問題**: Approval の approve/reject は **`user_access_token` が必須**（Bot token では不可）。Callback には公開エンドポイントが必要。

**サーバーホスティング方針**:
- **推奨**: Google Cloud Functions（または AWS Lambda） — パブリック HTTPS エンドポイント、無料枠内で十分
- **開発時**: ngrok でローカルサーバーを公開（`CALLBACK_SERVER_URL` に ngrok URL を設定）

**Card JSON 2.0（承認依頼カード）**:
```json
{
  "schema": "2.0",
  "header": {
    "title": { "tag": "plain_text", "content": "💰 経費精算 承認依頼" }
  },
  "body": {
    "elements": [
      {
        "tag": "markdown",
        "content": "**申請者**: {{申請者名}}\n**金額**: ¥{{金額}}\n**用途**: {{用途}}\n**申請日**: {{日付}}"
      },
      {
        "tag": "button", "type": "primary",
        "text": { "tag": "plain_text", "content": "✅ 承認する" },
        "behaviors": [{"type": "callback", "value": {
          "action": "approve",
          "instance_code": "{{instance_code}}",
          "task_id": "{{task_id}}",
          "record_id": "{{record_id}}"
        }}]
      },
      {
        "tag": "button", "type": "danger",
        "text": { "tag": "plain_text", "content": "❌ 却下する" },
        "behaviors": [{"type": "callback", "value": {
          "action": "reject",
          "instance_code": "{{instance_code}}",
          "task_id": "{{task_id}}",
          "record_id": "{{record_id}}"
        }}]
      }
    ]
  }
}
```

**Callback Server 処理フロー**:
```
POST /callback（card.action.trigger）
  ↓ 3秒以内に { "code": 0 } を返す（非同期処理で遅延を回避）
  ↓ action.value から instance_code / task_id / record_id / action を取得
  ↓ operator.open_id から承認者を特定 → user_access_token を取得
  ↓ approve: POST /approval/v4/tasks/approve
     reject:  POST /approval/v4/tasks/reject（comment 付き）
  ↓ Base レコードのステータスを「承認済」or「却下」に更新
  ↓ 申請者に結果通知カードを送信
```

**user_access_token 管理（Blocker 修正済み）**:

承認者は初回のみブラウザ OAuth 認証が必要。

**トークン保存先**: Google Cloud Firestore（推奨）
- コレクション: `user_tokens`
- ドキュメント ID: ユーザーの `open_id`
- フィールド:
  ```typescript
  {
    open_id: string,           // ユーザー識別子
    access_token: string,      // 現在有効なアクセストークン
    refresh_token: string,     // リフレッシュトークン
    expires_at: number,        // access_token の有効期限（UNIX タイムスタンプ）
    updated_at: number         // 最終更新日時
  }
  ```

**リフレッシュロジック**:
```typescript
// src/lark/auth.ts
import { Firestore } from '@google-cloud/firestore'

const db = new Firestore()
const COLLECTION_NAME = 'user_tokens'

/**
 * ユーザーのトークンを取得
 * - 有効期限内の場合: そのまま返す
 * - 有効期限切れの場合: refresh_token で更新して返す
 * - トークン未登録の場合: エラーを投げる
 */
export async function getUserToken(openId: string): Promise<string> {
  const doc = await db.collection(COLLECTION_NAME).doc(openId).get()
  
  if (!doc.exists) {
    throw new Error(`User token not found for ${openId}. Please authenticate first.`)
  }
  
  const data = doc.data()!
  const now = Math.floor(Date.now() / 1000)
  
  // 有効期限内の場合
  if (data.expires_at > now + 60) { // 60秒のマージンを含む
    console.log(`[auth] Using existing token for ${openId}`)
    return data.access_token
  }
  
  // 有効期限切れの場合: リフレッシュ
  console.log(`[auth] Token expired for ${openId}, refreshing...`)
  return await refreshToken(openId, data.refresh_token)
}

/**
 * refresh_token でアクセストークンを更新
 */
async function refreshToken(openId: string, refreshToken: string): Promise<string> {
  try {
    const response = await fetch('https://open.larksuite.com/open-apis/auth/v3/refresh_access_token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        grant_type: 'refresh_token',
        refresh_token: refreshToken
      })
    })
    
    if (!response.ok) {
      throw new Error(`Refresh token failed: ${response.status}`)
    }
    
    const json = await response.json()
    const { access_token, refresh_token: newRefreshToken, expires_in } = json.data
    
    // Firestore に更新
    const now = Math.floor(Date.now() / 1000)
    await db.collection(COLLECTION_NAME).doc(openId).set({
      open_id: openId,
      access_token: access_token,
      refresh_token: newRefreshToken,
      expires_at: now + expires_in,
      updated_at: now
    })
    
    console.log(`[auth] Token refreshed successfully for ${openId}`)
    return access_token
    
  } catch (err) {
    console.error(`[auth] Failed to refresh token for ${openId}:`, err)
    throw err
  }
}

/**
 * 初回認証: ユーザーに認証 URL を送信
 */
export async function initiateAuthFlow(openId: string, redirectUri: string): Promise<string> {
  // Lark Developer Console で事前に設定した redirect_uri を使用
  const authUrl = new URL('https://open.larksuite.com/open-apis/authen/v1/authorize')
  authUrl.searchParams.set('app_id', process.env.LARK_APP_ID!)
  authUrl.searchParams.set('redirect_uri', redirectUri)
  authUrl.searchParams.set('state', Buffer.from(JSON.stringify({ openId })).toString('base64'))
  authUrl.searchParams.set('scope', 'approval:task:write approval:task:read contact:user.base:readonly')
  
  return authUrl.toString()
}

/**
 * OAuth コールバックハンドラ
 * - 認証コードから access_token と refresh_token を取得
 * - Firestore に保存
 */
export async function handleAuthCallback(
  code: string,
  state: string
): Promise<void> {
  const { openId } = JSON.parse(Buffer.from(state, 'base64').toString())
  
  // アクセストークン取得
  const response = await fetch('https://open.larksuite.com/open-apis/auth/v3/oidc/access_token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      grant_type: 'authorization_code',
      client_id: process.env.LARK_APP_ID,
      client_secret: process.env.LARK_APP_SECRET,
      code: code,
      redirect_uri: process.env.LARK_REDIRECT_URI
    })
  })
  
  if (!response.ok) {
    throw new Error(`Failed to get access token: ${response.status}`)
  }
  
  const json = await response.json()
  const { access_token, refresh_token, expires_in } = json.data
  
  // Firestore に保存
  const now = Math.floor(Date.now() / 1000)
  await db.collection(COLLECTION_NAME).doc(openId).set({
    open_id: openId,
    access_token: access_token,
    refresh_token: refresh_token,
    expires_at: now + expires_in,
    updated_at: now
  })
  
  console.log(`[auth] User ${openId} authenticated successfully`)
}
```

**再認証が必要な場合の通知フロー**:
```typescript
// Callback Server 内でトークン未登録エラーを捕捉
if (err.message.includes('User token not found')) {
  const authUrl = await initiateAuthFlow(
    approverOpenId,
    `${process.env.CALLBACK_SERVER_URL}/auth/callback`
  )
  
  await sendAuthRequiredCard(approverOpenId, authUrl)
}

/**
 * 再認証要求カードを送信
 */
async function sendAuthRequiredCard(openId: string, authUrl: string): Promise<void> {
  const card = {
    schema: '2.0',
    header: {
      title: { tag: 'plain_text', content: '🔐 認証が必要です' },
      template: 'orange'
    },
    body: {
      elements: [
        {
          tag: 'markdown',
          content: '承認操作にはユーザー認証が必要です。以下のリンクから認証を完了してください。'
        },
        {
          tag: 'button',
          type: 'primary',
          text: { tag: 'plain_text', content: '認証する' },
          behaviors: [{ type: 'open_url', url: authUrl }]
        }
      ]
    }
  }
  
  await sendMessage(openId, 'interactive', JSON.stringify(card))
}
```

---

### 5. 会計ソフト連携（freee / MoneyForward）

**問題**: OAuth 2.0 トークン管理が複雑。freee は Enterprise/Professional プラン必須。

**解決方法**: `POST /freee-sync` エンドポイントで freee OAuth 2.0 フローを直接処理。

**freee 連携フロー**:
```
Base（承認済みレコード更新）
  ↓ Base Automation → legacy-backoffice サーバー POST /freee-sync
  ↓ POST https://api.freee.co.jp/api/1/expense_applications
     { "company_id": {{company_id}}, "title": "{{用途}}", "amount": {{金額}} }
  ↓ 成功 → Base レコードに freee_id を書き込み
  ↓ 失敗 → Bot でエラー通知
```

> **注意**: freee 経費申請 API は Enterprise / Professional プラン必須。

**MoneyForward Cloud 連携フロー**:
```
legacy-backoffice サーバー → POST https://expense.moneyforward.com/api/external/v1/expense_reports
```

---

## legacy-backoffice setup の自動化範囲

`legacy-backoffice setup` コマンドで自動化できる範囲（CLI で完結するもの）：

| 処理 | 自動化 | コマンド |
|------|-------|---------|
| Base（多維表格）作成 | ✅ 完全自動 | `lark-cli base +base-create` |
| テーブル + フィールド作成 | ✅ 完全自動 | `+table-create` + `+field-create` |
| フォーム作成 + 質問設定 | ✅ 完全自動 | `+form-create` + `+form-questions-create` |
| ワークフロー（通知系）作成・有効化 | ✅ 完全自動 | `+workflow-create` + `+workflow-enable` |
| ダッシュボード + グラフ作成 | ✅ 完全自動（直列実行） | `+dashboard-create` + `+dashboard-block-create` |
| HTTP Request Automation | ✅ サーバーエンドポイントへ委譲 | `/approval-create` 等を呼び出し |
| Approval テンプレート作成 | ⚠️ GUI 手動（Phase 0） | Lark 管理画面 → approval_code 取得 |
| freee / MF OAuth 設定 | ⚠️ サーバー手動設定 | `.env` にクレデンシャルを設定 |
| Callback Server デプロイ | ⚠️ 手動（初回のみ） | Cloud Functions deploy |

---

## P0: 経費精算フロー（詳細版・P1 修正済み）

### フロー概要

```
1. 申請者 → Lark フォームで入力
   （日付・金額・カテゴリ・用途・領収書添付）

2. Base Automation（+workflow-create 設定済み）
   → legacy-backoffice サーバー POST /approval-create に Webhook POST

3. legacy-backoffice サーバーが Approval インスタンス作成
   POST /approval/v4/instances → instance_code を Base に書き込み

4. legacy-backoffice サーバーが承認者へ Interactive Card 送信
   （承認する / 却下する ボタン付き）

5. 承認者がボタンをクリック
   → Callback Server（Cloud Functions）が受信
   → user_access_token で tasks.approve または tasks.reject を呼び出し

6. Callback Server が Base レコードを「承認済」に更新
   → 申請者に完了通知カードを送信

7. 月次バッチ（legacy-backoffice report monthly）
   → Base データを集計してレポートカードをチャンネルに投稿
   → （オプション）legacy-backoffice サーバー経由で freee に仕訳作成
```

### 2. Base Automation → `/approval-create` 設定

**Base Automation の HTTP Request ノード設定（Lark GUI で行う）**:

1. Lark Base → 該当のテーブルを開く
2. 右上「...」→「Automation（自动化）」をクリック
3. トリガー: 「レコード作成時（Record Created）」
4. アクション: 「HTTP Request」
   - リクエスト方法: `POST`
   - リクエストアドレス: `{CALLBACK_SERVER_URL}/approval-create`
   - リクエストヘッダー: `Content-Type: application/json`
   - リクエストボディ:
     ```json
     {
       "record_id": "{{record_id}}",
       "applicant_id": "{{申請者.open_id}}",
       "approver_id": "{{承認者.open_id}}",
       "subject": "{{件名}}",
       "amount": {{金額}},
       "category": "{{カテゴリ}}",
       "form_json": "{{form_json}}"
     }
     ```
5. 「テスト」→「公開」で有効化

**環境変数 (.env)**:

```env
# 承認者設定（固定値またはロジックで決定）
APPROVER_OPEN_ID_DEFAULT=ou_xxxxxxxxxx  # デフォルト承認者
APPROVER_OPEN_ID_MANAGER=ou_yyyyyyyyyy  # 部門長（10万円以上）
APPROVER_OPEN_ID_SUPERVISOR=ou_zzzzzzzzzz  # 上長（10万円未満）
```

### Lark Base スキーマ（経費テーブル）

| フィールド | 型 | 備考 |
|-----------|-----|------|
| 申請 ID | 自動採番 | - |
| 申請者 | ユーザー | Lark ユーザー |
| 申請日 | 日付 | - |
| 金額 | 数値（円） | - |
| カテゴリ | 単一選択 | 交通費/接待費/消耗品/その他 |
| 用途 | テキスト | - |
| 領収書 | 添付ファイル | 画像/PDF |
| ステータス | 単一選択 | 申請中/承認済/却下/支払済 |
| 承認者 | ユーザー | - |
| 承認日 | 日付 | - |
| 却下理由 | テキスト | - |
| 月 | 数式 | `YEAR(申請日) & "-" & TEXT(MONTH(申請日),"00")` |
| instance_code | テキスト | Approval インスタンス ID（内部用） |
| task_id | テキスト | Approval タスク ID（内部用） |

---

## P0: 稟議・申請フロー

| テンプレート | 承認ステップ | 条件 |
|------------|------------|------|
| 購買申請 | 上長 → 部門長 | - |
| 契約締結 | 法務 → 経営層 | - |
| 採用稟議 | HR マネージャー → 役員 | - |
| 高額経費 | 上長 → 部門長 → CFO | 金額 ≥ 10 万円 |

**lark-cli コマンド（すべて `--as user` 必須）**:
```bash
# 承認タスク一覧
lark-cli approval tasks query --as user

# 承認
lark-cli approval tasks approve --as user \
  --data '{"instance_code":"XXX","task_id":"YYY","comment":"承認します"}'

# 却下
lark-cli approval tasks reject --as user \
  --data '{"instance_code":"XXX","task_id":"YYY","comment":"却下理由"}'
```

---

## 実装ロードマップ

### Phase 0 — 事前設定（手動・初回のみ）
- [ ] Lark App 作成（Developer Console）
  - スコープ追加: `im:message`, `im:message.file_link:readonly`, `approval:instance:write`, `approval:task:write`, `bitable:app`
- [ ] Approval テンプレート作成（GUI）→ `approval_code` を `.env` に保存
- [ ] freee / MoneyForward OAuth クレデンシャルを `.env` に設定（オプション）
- [ ] legacy-backoffice サーバーデプロイ（Cloud Functions 等）+ Lark Developer Console に Callback URL 登録
- [ ] `lark-cli config init` + `lark-cli auth login`

### Phase 1 — 基盤構築（CLI 一括実行）
- [ ] `legacy-backoffice setup`: Base + テーブル + フィールド作成
- [ ] `legacy-backoffice setup`: フォーム + 質問作成
- [ ] `legacy-backoffice setup`: 通知用ワークフロー作成・有効化
- [ ] `legacy-backoffice setup`: ダッシュボード + グラフ作成（直列）
- [ ] `pnpm dev` → `[auth] tenant_access_token acquired` を確認

### Phase 2 — 承認フロー
- [ ] legacy-backoffice サーバー `POST /approval-create` 実装済み（`src/server/index.ts`）
- [ ] Base Automation → `/approval-create` 呼び出し設定
- [ ] Callback Server `POST /callback`: tasks.approve / reject 実装済み
- [ ] user_access_token 管理（refresh_token 保管）
- [ ] Base レコード更新 + 結果通知（実装済み）

### Phase 3 — OCR・領収書処理
- [ ] legacy-backoffice サーバー `POST /ocr` 実装済み（`src/server/index.ts`）
- [ ] Bot 有効化 + `im.message.receive_v1` を `/ocr` に登録

### Phase 4 — 会計ソフト連携
- [ ] `legacy-backoffice auth freee` で OAuth トークンを取得・保存
- [ ] `POST /freee-sync` 実装済み（`src/server/index.ts` + `src/lark/freee.ts`）
- [ ] Base Automation → `/freee-sync` 呼び出し設定（承認済トリガー）
- [ ] （オプション）MoneyForward 連携

### Phase 5 — レポート・分析
- [ ] `legacy-backoffice report monthly`: Base 集計 → Bot チャンネル投稿
- [ ] Base ダッシュボード: カテゴリ別・月別グラフ

---

## CLI ツール（legacy-backoffice）コマンド設計

```bash
# セットアップ（Phase 1 を一括実行）
legacy-backoffice setup [--base-token TOKEN]

# 経費精算（expense コマンドに統一）
legacy-backoffice expense list    [--month 2026-04] [--status 申請中]
legacy-backoffice expense create  --amount 3500 --category 交通費 --purpose "東京-大阪"
legacy-backoffice expense approve <record-id>   # Approval tasks.approve を呼び出し
legacy-backoffice expense reject  <record-id> --reason "理由"
legacy-backoffice expense status  <record-id>   # Approval インスタンスの現在ステータス

# 稟議・申請（汎用 approval コマンド）
legacy-backoffice approval list                 # 自分の承認待ちタスク一覧
legacy-backoffice approval approve <instance-code>
legacy-backoffice approval reject  <instance-code> --reason "理由"

# レポート
legacy-backoffice report monthly [--month 2026-04] [--post-to <chat-id>]

# 認証
legacy-backoffice auth            # lark-cli 認証状態確認
legacy-backoffice auth login      # ユーザー OAuth 認証（user_access_token 取得）
```

> **expense vs approval の使い分け**:
> `expense` は経費精算専用（Base レコード ID で操作）。
> `approval` は汎用承認（Approval instance_code で操作）。稟議・購買申請等に使用。

### 技術スタック

| 項目 | 採用技術 |
|------|---------|
| 言語 | TypeScript (Node.js 20+, ESM, strict) |
| パッケージ管理 | pnpm |
| CLI フレームワーク | commander.js |
| lark-cli 呼び出し | `execa`（シェル実行） |
| Lark 直接 API | `@larksuite/node-sdk` |
| Callback Server | Express.js on Cloud Functions |
| LLM（OCR 抽出） | `@anthropic-ai/sdk`（Claude Haiku） |

---

## 制約・注意事項

### Lark プラン要件

| 機能 | 必要プラン |
|------|-----------|
| Base Automation（月 5 万回） | Pro 以上 |
| ファイルストレージ大容量 | Pro 以上推奨 |
| 承認ワークフロー | 全プラン |

### 認証要件

| 操作 | 必要トークン | 備考 |
|------|------------|------|
| Approval 承認/却下 | **user_access_token 必須** | Bot token では不可 |
| Approval インスタンス作成 | tenant_access_token 可 | startTokenRefresh() で自動管理 |
| Base レコード CRUD | tenant_access_token 可 | 同上 |
| Bot メッセージ送信 | tenant_access_token 可 | 同上 |
| Bot 受信画像ダウンロード | tenant_access_token + `im:message.file_link:readonly` スコープ | スコープ設定必須 |

### 法令対応の免責

本システムは **電子帳簿保存法・インボイス制度の法的要件を満たさない**。

- ✅ 社内申請・承認フロー管理
- ✅ 費用データの集計・可視化
- ✅ 会計ソフトへのデータ転送補助
- ❌ 法的な電子帳簿保存（JIIMA 認証が必要）
- ❌ 適格請求書の発行・受取の法的要件充足

---

## P1 残課題の詳細仕様（修正済み）

> 詳細な実装コードとエラーハンドリングは `SPEC_P1_ENHANCEMENT.md` を参照

### 1. OCR パイプラインのエラーハンドリング

**環境変数 (.env)**:
```env
# Claude Haiku コスト管理
CLAUDE_HAIKU_MONTHLY_LIMIT_USD=5.0  # 月次上限: $5
CLAUDE_HAIKU_DAILY_LIMIT_COUNT=50    # 日次上限: 50枚
```

**`POST /ocr` エンドポイント**（`src/server/index.ts`）の処理フロー:

```
POST /ocr（Lark im.message.receive_v1）
  ↓ message_type == "image" のみ処理
  ↓ image_key を content から取得
  ↓ GET /im/v1/images/{image_key} — 画像ダウンロード - RETRY x3
  ↓ POST /ocr/v1/image/basic_recognize — Lark OCR - RETRY x3
  ↓ POST /v1/messages（Claude Haiku 構造化抽出）- RETRY x3
  ↓ POST /bitable/v1/.../records — Base レコード挿入 - RETRY x3
  ↓ sendMessage() — Bot 返信: 登録完了
```

**リトライポリシー（指数バックオフ）**:
| ステップ | リトライ回数 | 遅延時間 |
|---------|------------|---------|
| 画像ダウンロード | 3回 | 1秒 → 2秒 → 4秒 |
| Lark OCR | 3回 | 1秒 → 2秒 → 4秒 |
| Claude API | 3回 | 2秒 → 4秒 → 8秒 |
| Base レコード挿入 | 3回 | 1秒 → 2秒 → 4秒 |

**コスト管理**: Claude Haiku で 1 枚あたり $0.00025（512 tokens）。

### 2. freee/MoneyForward 連携のエラーハンドリング

**`POST /freee-sync` エンドポイント**の処理フロー:

```
POST /freee-sync（Base Automation: 承認済レコード更新）
  ↓ freee 連携フィルター（ステータス == 承認済 のみ処理）
  ↓ POST https://api.freee.co.jp/api/1/expense_applications - RETRY x3
  ↓ 400+ エラー → Bot エラー通知
  ↓ PUT Base レコード（freee_id を書き込み）- RETRY x3
  ↓ Bot 返信: 連携完了
```

**リトライポリシー（freee API）**:
| ステップ | リトライ回数 | 遅延時間 |
|---------|------------|---------|
| freee API 呼び出し | 3回 | 2秒 → 4秒 → 8秒 |
| Base レコード更新 | 3回 | 1秒 → 2秒 → 4秒 |

**レート制限への対応**:
| ステータスコード | エラー種類 | 対処 |
|-------------|---------|------|
| 429 | rate_limit | retry-after ヘッダーの秒数待機 |
| 401 | auth_error | freee OAuth トークンを再取得 |
| 422 | validation_error | 手動連携依頼 |
| 500 | server_error | 自動リトライ |

### 3. legacy-backoffice setup コマンド実装

**コマンド構造**:
```bash
legacy-backoffice setup [--force] [--skip-form] [--skip-dashboard]
```

**実装内容**:
- ✅ lark-cli オーケストレーション
- ✅ Base 作成（または既存確認）
- ✅ テーブル作成
- ✅ フィールド作成（14フィールド）
- ✅ フォーム作成（スキップ可能）
- ✅ ワークフロー作成・有効化
- ✅ ダッシュボード作成（スキップ可能）
- ✅ .env 更新
- ✅ 進捗表示

**エラーハンドリング**:
| ステップ | エラー | 対処 |
|---------|------|------|
| Base 作成 | app_token 取得失敗 | App ID / Secret 確認 |
| テーブル作成 | table_id 取得失敗 | Base 権限確認 |
| フィールド作成 | フィールド重複 | --force で再作成 |
| フォーム作成 | 質問追加失敗 | フィールド ID 確認 |
| ワークフロー作成 | HTTP URL 未設定 | `CALLBACK_SERVER_URL` を `.env` で確認 |
| ダッシュボード作成 | グラフ作成失敗 | データ確認 |

> 詳細な実装コード（TypeScript）は `SPEC_P1_ENHANCEMENT.md` を参照
