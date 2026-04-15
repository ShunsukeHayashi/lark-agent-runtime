# LARC — Lark Agent Runtime

> OpenClaw エージェントのための Lark 実行・ガバナンス層

[![version](https://img.shields.io/badge/version-0.2.0-blue)](bin/larc)
[![CI](https://github.com/ShunsukeHayashi/lark-agent-runtime/actions/workflows/ci.yml/badge.svg)](https://github.com/ShunsukeHayashi/lark-agent-runtime/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-green)](#ライセンス)
[![lark-cli](https://img.shields.io/badge/requires-lark--cli-orange)](https://github.com/larksuite/cli)

[English](README.md) | [简体中文](README.zh-CN.md) | 日本語

---

## LARC とは

**LARC** は、[OpenClaw](https://openclaw.dev) エージェントのための Lark 実行・ガバナンス層です。

OpenClaw がエージェントの頭脳（LLM 実行エンジン）であり、LARC は OpenClaw に Lark の企業サーフェスへの安全でガバナンスされたアクセスを提供します。

```
OpenClaw エージェント（LLM 実行）
    ↓  larc ingress openclaw
LARC（権限 · キュー · 監査 · 文脈取得）
    ↓  lark-cli
Lark API — Drive / Base / IM / Approval / Wiki
```

OpenClaw がエージェントなら、LARC はガードレールです。実行ゲートを適用し、権限を追跡し、タスクキューを管理し、すべての結果を Lark に記録します。

---

## なぜ必要か

AI エージェントは開発業務では強力ですが、一般的なバックオフィス業務ではまだ弱いままです。障壁はモデル性能ではなく、次の3点です。

- どの権限が必要か分かりにくい
- 誰の権限として動くのかが曖昧になりやすい
- ローカルファイル前提の設計が、業務ツール中心の運用に合いにくい

LARC は `permission-first` で設計されています。何かに触れる前に必要なスコープを説明し、Lark のネイティブサーフェスを経由してルーティングし、すべての操作を Base に記録します。

---

## 主な機能

| 機能 | 説明 |
|---|---|
| `larc bootstrap` | Lark Drive から `SOUL → USER → MEMORY → HEARTBEAT` をエージェントコンテキストに読み込む |
| `larc auth suggest` | 自然言語のタスク説明から必要な最小スコープと実行権限を推定 |
| `larc approve gate` | タスク実行前に実行ゲートポリシー（none / preview / approval）を確認 |
| `larc ingress openclaw` | OpenClaw への次のガバナンスアクションバンドルを構築・ディスパッチ |
| `larc ingress recover` | ワーカークラッシュ後の停滞した in_progress アイテムをリセット |
| `larc agent register` | 宣言されたスコープとともにエージェントを Lark Base に登録（YAML バッチ登録対応） |
| `larc memory` | Lark Base との日次メモリ同期（完全ページネーション・キーワード検索対応） |
| `larc status` | Base 接続性・OpenClaw インストール状態・デーモン状態・キュー統計を一覧表示 |
| `larc kg build` / `larc kg query` | Lark Wiki ノードグラフをインデックスし、隣接コンテキスト付きでキーワード検索 |
| Claude Code スキル | `.claude/skills/` に 24 の Lark 向けスキルを同梱 |

---

## クイックスタート

### 前提条件

```bash
which openclaw    # OpenClaw — エージェント実行エンジン
which lark-cli    # lark-cli — npm install -g @larksuite/cli
which python3     # Python 3.8 以上
```

> **最初に OpenClaw を用意してください。** LARC はスタンドアロンのエージェントではなく、OpenClaw エージェントのランタイム層です。  
> OpenClaw に LARC ランタイムスキルをインストールしてから始めてください: `bash scripts/install-openclaw-larc-runtime-skill.sh`

### LARC インストール

```bash
# LARC インストール（~/.larc/runtime/ にダウンロード）
curl -fsSL https://raw.githubusercontent.com/ShunsukeHayashi/lark-agent-runtime/main/scripts/install.sh | bash

# lark-cli に Lark アプリ情報を設定
lark-cli config init --app-id <App ID> --app-secret-stdin --brand lark
lark-cli auth login

# ワークスペースのセットアップ（1コマンド）
larc quickstart

# すべての状態を確認
larc status
```

→ 詳細ガイド: [docs/quickstart-ja.md](docs/quickstart-ja.md)
→ OpenClaw 統合: [docs/openclaw-integration.md](docs/openclaw-integration.md)
→ Lark アプリ設定（テスト担当者向け）: [docs/lark-app-setup.md](docs/lark-app-setup.md)

---

## 実行モード

| モード | 動作 | 状態 |
|---|---|---|
| **Supervised** | OpenClaw + Claude Code が手動で `larc ingress run-once` を呼ぶ | ✅ 安定 |
| **OpenClaw-assisted autonomous** | OpenClaw が `larc ingress openclaw --execute` を呼ぶ。公式 `openclaw-lark` が原子的な Lark 操作を行い、LARC がゲート・キュー・監査を担当 | ✅ 安定 |
| **Experimental IM loop** | `larc daemon start` — IM ポーラーがメッセージをエンキューし、worker が OpenClaw に自動ディスパッチ | 🧪 実験的 |

> **IM デーモンループは実験段階です。** 本番ワークフローには supervised または OpenClaw-assisted モードを使用してください。主要オンボーディング導線としては案内しません。

---

## 現在の状態

### 安定・検証済み

| 領域 | 確認内容 |
|---|---|
| 権限インテリジェンス | 32 タスクタイプの最小スコープ推論・権限モデルのドキュメント化 |
| 承認ゲート | 実行前に none/preview/approval ポリシーを適用 |
| キューライフサイクル | `enqueue → openclaw → done/fail/partial/followup` の全サイクル確認済み |
| エージェントレジストリ | YAML バッチ登録・エージェントごとのスコープを Lark Base に保存 |
| メモリ同期 | ライブ Lark Base に対してページネーション対応の pull/push/search を検証 |
| ナレッジグラフ | Wiki BFS トラバーサル・隣接コンテキスト付きキーワードクエリ |
| ステータスダッシュボード | `larc status` が Base・OpenClaw・デーモン・キュー状態を一括表示 |

### 実験的

- IM デーモンループ（`larc daemon start`）— echo loop と再起動の安定性を現在改善中
- bot token による `larc send` 通知 — 修正済み（2026-04-15）
- OpenClaw の plugin / runtime 組み合わせは環境ごとの確認がまだ必要。ただし推奨経路は `official openclaw-lark plugin + LARC`

---

## リポジトリ構成

```text
bin/larc                       # メイン CLI エントリポイント
lib/
  bootstrap.sh                 # Lark Drive からの disclosure chain 読み込み
  memory.sh                    # Lark Base との日次メモリ同期（ページネーション対応）
  send.sh                      # IM メッセージ送信（--as bot）
  ingress.sh                   # キュー・OpenClaw バンドル・委任・ワーカーループ
  daemon.sh                    # IM ポーラー + キューワーカーのサブプロセス管理
  worker.sh                    # キューワーカー（OpenClaw ディスパッチまたは supervised フォールバック）
  runtime-common.sh            # サブプロセスモジュール共通ヘルパー
  agent.sh                     # エージェント登録・管理
  auth.sh                      # スコープ推論・認可
  approve.sh                   # 承認フロー・実行ゲート確認
  knowledge-graph.sh           # Wiki ノードグラフ構築・クエリ
config/
  scope-map.json               # 32 タスクタイプ × 必要スコープ × 権限タイプ
  gate-policy.json             # 32 タスクタイプ × リスクレベル × 実行ゲート
.claude/skills/lark-*/         # 24 の Lark 向け Claude Code スキル
docs/
  quickstart-ja.md             # 詳細オンボーディングガイド
  openclaw-integration.md      # LARC と OpenClaw の接続方法
  permission-model.md          # スコープ・権限モデル
```

---

## 検証

```bash
bash -n bin/larc scripts/install.sh scripts/auth-suggest-check.sh
bash scripts/auth-suggest-check.sh --verify
```

---

## ライセンス

MIT
