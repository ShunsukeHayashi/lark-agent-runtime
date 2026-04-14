# LARC × OpenClaw 実装プレイブック

> 全タスクを並列で実行するためのロードマップ。各フェーズは独立して実行可能。

## アーキテクチャ概要

```
[ローカル: larc CLI]
       │
       ├── bootstrap → Lark Drive / Wiki から SOUL/USER/MEMORY を読込
       ├── memory    → Lark Base と日次記憶を双方向同期
       ├── send      → Lark IM へメッセージ送信 (openclaw agent 相当)
       ├── task      → Lark Project タスク管理
       ├── approve   → Lark Approval フロー起動
       └── agent     → エージェント登録・管理

[Lark Drive: エージェントワークスペース]
       ├── SOUL.md         → アイデンティティ・原則
       ├── USER.md         → ユーザープロファイル
       ├── MEMORY.md       → 長期記憶
       ├── memory/日付.md  → 日次コンテキスト
       └── HEARTBEAT.md    → システム状態

[Lark Base: 構造化データ]
       ├── agents_registry  → エージェント登録テーブル
       ├── agent_memory     → 記憶テーブル
       ├── agent_heartbeat  → 状態ログテーブル
       └── agent_logs       → 監査ログテーブル
```

---

## Current Truth — 2026-04-14

### 実装方針（承認済み）
- `larc` は継続する
- ただし **現行 `lark-cli` の実コマンド体系へ寄せて再実装する**
- 足りない機能だけ `lark-cli` の **局所フォーク** または `lark-cli api` で補う
- 最初から全面フォークはしない

### この方針を採る理由
- `Drive` / `Task` / `Auth` は現行 `lark-cli` の shortcut でかなり高確率に実装できる
- `Base` も shortcut 群に寄せれば実装可能性が高い
- `Approval` の新規起票だけは現行 CLI に直接コマンドが見当たらず、raw API か局所フォークが必要
- よって、MVP を先に成立させてから不足機能だけをフォークで埋める方が最短

### 現行 `lark-cli` とのズレ（要修正）

| 現コードの想定 | 現行 CLI で現実的な置換先 | 状態 |
|---|---|---|
| `drive list` | `drive files list` | 要置換 |
| `drive download` | `drive +download` | 要置換 |
| `drive folder create` | `drive files create_folder` | 要置換 |
| `base tables list` | `base +table-list` | 要置換 |
| `base records list` | `base +record-list` | 要置換 |
| `base records create/update` | `base +record-upsert` | 要置換 |
| `task tasks create/patch` | `task +create` / `task +update` / `task +complete` | 要置換 |
| `approval instances create` | `lark-cli api` or local fork | 未解決 |

### MVP の範囲
- `bootstrap`
- `memory`
- `send`
- `agent registry`
- `task`
- `auth`

### MVP から外すもの
- `Approval` の新規起票
- `OpenClaw` 完全互換 CLI
- `MergeGate` 連携
- `Knowledge Graph`

### 実態ベースの位置づけ（2026-04-14）
- LARC はすでに「Lark 上で動くエージェントの土台」として必要な主要パーツを持つ
- ただし現段階では **自律エージェントそのもの** ではなく、**Claude Code などの上位エージェントが使う Lark runtime / CLI surface** である
- つまり現在の実行モデルは以下:

```
Claude Code / 上位エージェント
    ↓
LARC (Lark への runtime / governance interface)
    ↓
Lark (Drive / Base / IM / Wiki / Approval)
```

### live 検証済みの実行面
- `larc bootstrap --agent main`
- `larc memory pull --agent main`
- `larc memory push --agent main`
- `larc send "..."`
- `larc task list/create/done`
- `larc agent list/register`
- `larc auth suggest "<task>"`
- `larc approve gate <type>`
- `larc kg build / query / show`

### 実装済みだが自律化されていない面
- IM 受信をトリガーに `larc` を自動起動する webhook / bot ingress
- `approve gate` / `approve create` 後に承認完了イベントで処理を再開する continuation
- Base をキューとして扱う agent task queue
- main から専門エージェントへ委任する routing / dispatch
- 過去 memory の横断検索

### フォークのトリガー条件
- `Approval` 起票を業務上どうしても MVP に入れたい
- 現行 `lark-cli` の shortcut では表現できない引数組み立てが継続的に必要
- `larc` 側で raw API ラップが増えすぎて、実質 `lark-cli` の再実装になり始める

---

## 実装戦略

### Strategy A — MVP First（採用）
1. `larc` を現行 `lark-cli` shortcut ベースに寄せる
2. `Drive` / `Base` / `Task` / `Auth` を通す
3. `Approval` は既存タスクの参照・処理だけを扱う
4. 起票だけ別スパイクで検証する

### Strategy B — 局所フォーク
- `approval instances create`
- `drive list`
- `base tables list`
- `base records list`

上記のような **`larc` が必要とする抽象だけ** を `lark-cli` 側に足す。

### Strategy C — 全面フォーク
- `lark-cli` 全体を自前 CLI として保守する
- 今回は採用しない
- 根拠: 保守コストが大きく、MVP の前進速度を落とすため

---

## 再定義したフェーズ

### PHASE 0 — CLI 整合化（最優先）
**目的**: 現行 `lark-cli` と `larc` 実装のコマンド差分を解消する

- [x] `bootstrap.sh` の `Drive` 呼び出しを `drive files list` / `drive +download` に寄せる
- [x] `setup-workspace.sh` の `Drive` 呼び出しを `drive files create_folder` / `drive +upload` に寄せる
- [x] `memory.sh` / `send.sh` / `heartbeat.sh` の `Base` 呼び出しを shortcut ベースへ寄せる
- [x] `task.sh` を `task +create` / `+update` / `+complete` ベースへ寄せる
- [x] `auth.sh` を `auth status` / `check` / `scopes` ベースへ寄せる

### PHASE 0.5 — Approval スパイク
**目的**: 新規承認起票の現実ルートを確定する

- [x] `lark-cli api` で Approval 起票 API を直接叩けるか確認
- [x] 必要スコープと payload 仕様を確定
- [x] raw API で十分か、局所フォークが必要か判断

補足:
- 詳細は `docs/approval-spike.md`
- 現時点の判断は「局所フォーク必須ではない。まず raw API helper で進める」

### PHASE 1 — MVP 成立
**完了条件**:
- `larc init`
- `larc bootstrap --agent main`
- `larc memory pull/push --agent main`
- `larc send --agent main`
- `larc task list/create/done`
- `larc auth check/login`
- `scripts/smoke-check.sh` が通る

**現在地（2026-04-14）**:
- `bootstrap` / `memory` / `send` / `task` の live path は確認済み
- `scripts/smoke-check.sh` は通過済み
- `scripts/live-check.sh` により OpenClaw → LARC → Lark IM の実動確認あり
- Phase A: 完了。runtime の全 live path が通った
- Phase B: 完了。`auth suggest` が 8件の現実タスクで期待スコープを返す。authority explanation 実装済み。
- Phase C: 完了。`larc agent list/register/show` が live Lark Base と連動。4エージェントを `agents.yaml` からバッチ登録済み。scopes フィールドをレジストリに保存。
- Phase D: 完了。`config/gate-policy.json` 導入（32 task types × none/preview/approval）。`larc approve gate` コマンド実装。`auth suggest` 出力に gate 警告セクションを追加。
- Phase E: 完了。`larc kg build/query/show/status` 実装。Lark Wiki を BFS 走査し 37 ノードをグラフ化。keyword query で親子・兄弟関係まで返す。
- 残課題: Workstream 6 — OSS リリース準備（repo cleanliness, release packaging, MergeGate integration）

---

## PHASE 1 — 基盤整備（並列実行可）

### 1A: larc CLI 完成 ✅
**担当**: Agent-CLI  
**状態**: 完了  
**成果物**: `bin/larc`, `lib/*.sh`

### 1B: Lark Drive ワークスペース初期化スクリプト
**担当**: Agent-Drive  
**ファイル**: `scripts/setup-workspace.sh`  
**タスク**:
- [x] Lark Drive に `agent-workspace/` フォルダ構造を自動作成
- [x] テンプレートファイル（SOUL/USER/MEMORY）をアップロード
- [x] agents_registry Base テーブルを自動プロビジョニング

**状態メモ**:
- 実装済み。現在は runtime sync の完全往復が次の論点
- 以後は `setup` の有無ではなく `hydrate / publish` の完成度で評価する

```bash
# 実行コマンド
./scripts/setup-workspace.sh --agent main --drive-folder <token>
```

### 1C: 権限マッピング定義
**担当**: Agent-Perms  
**ファイル**: `config/scope-map.json`  
**タスク**:
- [x] タスク種別 → 必要スコープのマスターマップ作成
- [x] `readonly` / `writer` / `admin` の3段階プロファイル定義
- [x] `larc auth suggest "<task>"` の初期実装
- [x] compound office tasks のスコープ推論: CRM / expense / drive / calendar 複合タスク対応（v0.2.0）
- [x] keyword matching の根本バグ3件修正（語順・ハイフン・bare keyword）
- [x] 検証ケース 8件を `docs/auth-suggest-cases.md` に期待値付きで固定
- [x] authority explanation の追加（user / tenant / bot の理由表示）
- [x] Case 7 の over-permission (1 scope) 解消: CRM+follow-up で IM が不要な場合の除外ロジック
- [x] `scripts/auth-suggest-check.sh` による回帰確認導線の追加
- [x] 三言語 README 初版 (`README.md` / `README.zh-CN.md` / `README.ja.md`) と OSS 準備ドキュメント追加

**状態メモ（2026-04-14）**:
- `auth suggest` は「存在する」段階を抜け、8件の現実タスクで期待スコープを返せる「信頼できる初期実装」段階に入った
- Playbook §14 マイルストーン「minimum likely scopes を説明できる」は達成
- authority path の説明は CLI 出力に追加済み
- 残る差別化: 最小権限化の精度向上、docs / tests / implementation の継続同期、private から三言語 OSS へ移るための衛生整備

### 1D: インストールスクリプト
**担当**: Agent-Install  
**ファイル**: `install.sh`  
**タスク**:
- [ ] `larc` を `/usr/local/bin/` にシンボリックリンク
- [ ] lark-cli インストール確認
- [ ] 初回設定ウィザード呼び出し

---

## PHASE 2 — エージェントテンプレート整備（並列実行可）

### 2A: バックオフィスエージェント定義
**担当**: Agent-BO  
**ファイル**: `agent-workspace/templates/backoffice/`  
**タスク**:
- [ ] 経費処理エージェント (SOUL.md)
- [ ] 議事録作成エージェント (SOUL.md)
- [ ] CRM更新エージェント (SOUL.md)
- [ ] 稟議起案エージェント (SOUL.md)
- [ ] 採用管理エージェント (SOUL.md)

各テンプレートに含めるもの:
- アイデンティティ・役割
- 必要権限スコープ（最小権限原則）
- 実行できる操作リスト
- 承認が必要な操作リスト

### 2B: ナレッジグラフ連携
**担当**: Agent-KG  
**ファイル**: `lib/knowledge-graph.sh`  
**タスク**:
- [x] Lark Wiki のリンク構造をエージェントコンテキストに取り込む
- [x] `larc kg build` — Wiki リンク構造をグラフとしてBase に記録
- [x] `larc kg query <concept>` — 概念に関連するドキュメントを検索
- [ ] OpenClaw の GitNexus 相当の「影響範囲分析」を Lark Wiki で実現

### 2C: OpenClaw 複数エージェント登録
**担当**: Agent-Multi  
**ファイル**: `scripts/register-agents.sh`  
**タスク**:
- [x] `larc agent register` の一括実行スクリプト
- [x] YAML定義ファイルから複数エージェントを一括登録
- [ ] openclaw agents list 形式との互換出力

```yaml
# agents.yaml の例
agents:
  - id: office-assistant
    name: オフィスアシスタント
    model: claude-sonnet-4-6
    scopes: [docs:doc:readonly, im:message:send_as_bot]
    workspace: general
  - id: expense-processor
    name: 経費処理エージェント
    model: claude-haiku-4-5
    scopes: [base:record:created, approval:approval:write]
    workspace: finance
  - id: crm-agent
    name: CRMエージェント
    model: claude-sonnet-4-6
    scopes: [base:record:created, base:record:readonly]
    workspace: sales
```

---

## PHASE 3 — 権限自動判定エンジン（最重要）

### 3A: スコープ推論エンジン
**担当**: Agent-Auth  
**ファイル**: `lib/auth.sh`, `config/scope-map.json`  
**タスク**:
- [x] 「このタスクをしたい」→ 必要スコープを即座に判定するロジック
- [x] `larc auth suggest "<タスク説明>"` コマンド実装
- [ ] lark-cli auth login --scope で承認URLを発行

```bash
# 使用例
larc auth suggest "経費申請を作成して承認を求める"
# → 推奨スコープ: base:record:created, approval:approval:write, im:message:send_as_bot
# → 承認URL: [lark-cli auth login --scope "..." がURLを発行]
```

### 3B: 権限チェックフック
**担当**: Agent-Hook  
**ファイル**: `lib/auth-hook.sh`  
**タスク**:
- [ ] 各コマンド実行前に権限を事前チェック
- [ ] 不足権限がある場合は自動で承認URL発行
- [ ] miyabi-lark-os の tool-policies.json パターンを適用

---

## PHASE 4 — OpenClaw エコシステム統合

### 4A: openclaw-lark プラグイン互換層
**担当**: Agent-OC  
**ファイル**: `lib/openclaw-compat.sh`  
**タスク**:
- [ ] `openclaw agent --agent main --json -m` → `larc send` への変換レイヤー
- [ ] openclaw agents list 出力形式との互換
- [ ] BOOTSTRAP.md 形式の自動生成

### 4B: MergeGate 統合
**担当**: Agent-MG  
**ファイル**: `lib/mergegate.sh`  
**タスク**:
- [ ] mergegate（ShunsukeHayashi/mergegate）との連携
- [ ] `larc approve` → mergegate review フロー
- [ ] 承認前のドキュメントをLark Approval に通す

---

## PHASE 5 — Agentic LARC MVP

**目的**: LARC を「人が叩く便利 CLI」から「OpenClaw の上で継続動作する Lark runtime」へ進める

**主経路**:
- `OpenClaw Agent -> official openclaw-lark plugin -> Lark`
- `LARC -> permission / gate / queue / delegation / memory`

**補足**:
- Lark IM / webhook bot ingress は便利な追加入口だが、現時点では primary path ではない
- 先に固めるべきなのは OpenClaw-first の supervised / semi-agentic runtime
- supervised test の first scope は 3 scenarios のみ:
  - CRM follow-up
  - expense approval
  - document update
- planning docs:
  - `docs/supervised-test-plan-2026-04-14.md`
  - `docs/adapter-schema-2026-04-14.md`

### 5A: OpenClaw-first ingress
**担当**: Agent-Loop  
**ファイル候補**: `lib/bot-ingress.sh`, `scripts/run-bot-loop.sh`

**タスク**:
- [x] CLI-based ingress surface: `lib/ingress.sh` に `enqueue` / `list` 実装
- [x] `openclaw` bundle で OpenClaw agent 向けの次アクションを返す
- [x] `enqueue` 時に `larc auth suggest` 相当の scope inference と gate evaluation を内蔵
- [ ] Lark IM / webhook 受信イベントから task intent を直接取り出す（optional ingress）

### 5B: Queue / continuation
**担当**: Agent-Queue  
**ファイル候補**: `lib/queue.sh`

**タスク**:
- [x] Local queue ledger を最小実装（Base は補助書き込み）
- [x] `pending / pending_preview / blocked_approval / approved / delegated / in_progress / done / failed / partial` 状態を持つ
- [x] `approve` / `resume` で blocked task の continuation を実装
- [ ] approval 完了イベントを受けて自動再開する

### 5C: Delegation
**担当**: Agent-Dispatch  
**ファイル候補**: `lib/delegate.sh`

**タスク**:
- [x] main が `expense-processor` / `crm-agent` / `doc-agent` へ委任する routing
- [x] `agents.yaml` の scopes と workspace を見て最適 agent を選ぶ
- [ ] Base registry を source-of-truth にした委任へ昇格
- [ ] 実行ログと memory push を agent 単位で残す

### 5D: Searchable memory
**担当**: Agent-Memory  
**ファイル候補**: `lib/memory-search.sh`

**タスク**:
- [x] Base 上の過去 memory を日付範囲・キーワードで検索
- [x] retrieval hook を `context` / `handoff` / `run-once` bundle に統合
- [x] queue / delegation の文脈復元に使う

### 5E: Worker loop
**担当**: Agent-Worker
**ファイル候補**: `lib/ingress.sh`

**タスク**:
- [x] `next` で agent ごとの次タスクを pull
- [x] `run-once` で queue item を `in_progress` に claim
- [x] `execute-stub` で task type ごとの placeholder 実行計画を生成
- [x] `execute-apply` で安全な adapter のみ限定実行
- [x] `followup` で `partial` item を回収
- [ ] task type ごとの本実行 adapter を拡張
- [ ] worker の常駐ループ化

### 成功条件
- [x] IM 相当の依頼文が queue に入る
- [x] 実行前に scope / gate が自動判定される
- [x] approval が必要な処理は blocked になり、承認後に resumed される
- [x] main agent が専門 agent に委任できる
- [x] worker が task を pull / claim / stub-execute できる
- [x] `partial` follow-up を別レーンで見られる
- [x] OpenClaw agent が queue item の次アクション bundle を取得できる
- [ ] IM webhook 経由で Lark 内から自動起動する（optional）
- [ ] 完了後に memory と audit trail が自動で残る

---

## 並列実行マトリクス

```
時間軸 →

Phase 1: [1A✅][1B  ][1C  ][1D  ]  ← 全部並列
Phase 2:      [2A  ][2B  ][2C  ]   ← Phase1完了後，全部並列
Phase 3:           [3A  ][3B  ]    ← Phase2完了後，並列
Phase 4:                [4A  ][4B] ← Phase3完了後，並列
```

---

## エージェントチーム割り当て

| エージェント | 担当フェーズ | 優先タスク |
|---|---|---|
| Agent-CLI   | 1A ✅       | `bin/larc` 完成 |
| Agent-Drive | 1B, 2A, 2C  | Driveワークスペース + エージェントテンプレート |
| Agent-Perms | 1C, 3A, 3B  | 権限マッピング + スコープ推論 |
| Agent-KG    | 2B          | Larkナレッジグラフ連携 |
| Agent-OC    | 4A, 4B      | OpenClaw互換 + MergeGate |

---

## 次の即時アクション

```bash
# 1. larc をPATHに追加
export PATH="$PATH:/Users/shunsukehayashi/study/larc-openclaw-coding-agent/bin"

# 2. 初期化
larc init

# 3. ブートストラップテスト
larc bootstrap --agent main

# 4. エージェント登録テスト
larc agent register
```
