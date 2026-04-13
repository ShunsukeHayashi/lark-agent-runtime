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

## Current Truth — 2026-04-13

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
- Phase B 着手: `auth suggest` が複合オフィスタスク（CRM+IM / expense+notify / drive+wiki / CRM+calendar）で正しいスコープを推論できるようになった
  - scope-map v0.2.0: `create_crm_record` / `send_crm_followup` / `update_base_record` を追加
  - keyword matching: 語順バグ・ハイフン語・bare keyword 欠落の3つの根本原因を修正
  - 検証ケース 8件を `docs/auth-suggest-cases.md` に期待値付きで固定
- 残課題: authority explanation (user/bot/tenant の理由表示) が未実装

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
- [ ] Lark Wiki の@メンション・リンク構造をエージェントコンテキストに取り込む
- [ ] `larc kg build` — Wiki リンク構造をグラフとしてBase に記録
- [ ] `larc kg query <concept>` — 概念に関連するドキュメントを検索
- [ ] OpenClaw の GitNexus 相当の「影響範囲分析」を Lark Wiki で実現

### 2C: OpenClaw 複数エージェント登録
**担当**: Agent-Multi  
**ファイル**: `scripts/register-agents.sh`  
**タスク**:
- [ ] `larc agent register` の一括実行スクリプト
- [ ] YAML定義ファイルから複数エージェントを一括登録
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
- [ ] 「このタスクをしたい」→ 必要スコープを即座に判定するロジック
- [ ] `larc auth suggest "<タスク説明>"` コマンド実装
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
