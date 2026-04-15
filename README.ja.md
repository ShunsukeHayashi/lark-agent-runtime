# LARC — Lark Agent Runtime

> Lark の中で仕事をする AI エージェントのための、権限管理付き実行環境

[![version](https://img.shields.io/badge/version-0.2.0-blue)](bin/larc)
[![CI](https://github.com/ShunsukeHayashi/lark-agent-runtime/actions/workflows/ci.yml/badge.svg)](https://github.com/ShunsukeHayashi/lark-agent-runtime/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-green)](#ライセンス)
[![lark-cli](https://img.shields.io/badge/requires-lark--cli-orange)](https://github.com/larksuite/cli)

[English](README.md) | [简体中文](README.zh-CN.md) | 日本語

正式名: `Lark Agent Runtime`
略称: `LARC`

---

## LARC とは

**LARC** は、Lark の中で仕事をする AI エージェントのための、権限管理付きランタイムです。

Claude Code がコーディングエージェントの実行環境の一部だとすれば、LARC は Lark の中で働く一般業務エージェントの実行環境です。

狙いは「Lark に接続する CLI」を作ることではありません。狙いは、Lark 自体をエージェントの実行面にすることです。

- Drive を disclosure chain の保存先として使う
- Base を memory / registry として使う
- IM をアクションと調整の面として使う
- Approval を実行制御として使う
- Wiki をナレッジ面として使う

---

## なぜ必要か

開発業務では AI エージェントが広がっていますが、一般的なバックオフィス業務ではまだ弱いままです。大きな理由は、モデル性能ではなく次の3点です。

- どの権限が必要か分かりにくい
- 誰の権限として動くのかが曖昧になりやすい
- ローカルファイル前提の設計が多く、業務ツール中心の運用に合いにくい

LARC はこのギャップに対して、`permission-first` の設計で入ります。

実際の流れは次の通りです。

1. タスクが届く
2. `larc auth suggest` が必要権限と authority を説明する
3. `larc approve gate` が、そのまま実行できるか、preview が必要か、approval が必要かを決める
4. 実行は Lark IM / Base / Drive / Wiki / Approval 上で行う
5. `larc memory` が実行内容を Lark に記録する

---

## 主な機能

| 機能 | 説明 |
|------|------|
| `larc bootstrap` | Drive 上の `SOUL.md → USER.md → MEMORY.md → HEARTBEAT.md` をまとめて取り込む |
| `larc auth suggest` | 自然文タスクから必要 scope と authority を推定する |
| `larc approve gate` | 実行前に none / preview / approval のゲート要件を確認する |
| `larc agent register` | Lark Base にエージェントを登録し、YAML バッチ登録にも対応する |
| `larc kg build` / `larc kg query` | Lark Wiki ノードグラフを索引化し、近傍ノード付きで概念検索する |
| `larc memory` | Base と日次メモリを同期する |
| `larc ingress` | enqueue、approve/resume、delegate、worker loop などのキュー処理面を提供する |
| `larc send` / `larc task` | IM 送信や業務タスク操作の基本経路を提供する |
| Approval 対応 | 承認インスタンス生成と承認タスク実行を分けて扱う |
| Claude Code skills | `.claude/skills/` に Lark 系スキル群を同梱する |

---

## クイックスタート

```bash
# 1. lark-cli をインストール
npm install -g @larksuite/cli

# 2. LARC をインストール（~/.larc/runtime/ に自動配置されます）
curl -fsSL https://raw.githubusercontent.com/ShunsukeHayashi/lark-agent-runtime/main/scripts/install.sh | bash

# 3. Lark アプリ認証情報を登録
lark-cli config init \
  --app-id   <App ID> \
  --app-secret-stdin \
  --brand    lark

# 4. Lark アカウントでログイン
lark-cli auth login

# 5. 1コマンドで環境構築（Drive フォルダ・Base テーブル・エージェント登録）
larc quickstart
```

> **注意**: LARC は `~/.larc/runtime/` に自動インストールされます。このディレクトリ内のファイルは直接編集しないでください。更新は `larc update` で行ってください。

→ 詳細ガイド: [docs/quickstart-ja.md](docs/quickstart-ja.md)  
→ Lark アプリ設定（担当者向け）: [docs/lark-app-setup.md](docs/lark-app-setup.md)

---

## 現在の状態

5つの基盤フェーズが完了し、実際の Lark テナントで動作確認済みです。

| フェーズ | 証明された内容 |
|---|---|
| A — ランタイム | `bootstrap`・`memory`・`send`・`task`・`agent` がすべて実際の Lark API と連動 |
| B — 権限インテリジェンス | `auth suggest` が 8種の複合業務タスクで最小権限を推論・権限主体を説明 |
| C — エージェント管理 | 4エージェントを Lark Base レジストリに登録；YAML バッチ登録対応；スコープ保存 |
| D — 承認と実行制御 | ゲートポリシー（32 タスク種別 × none/preview/approval）；`larc approve gate` |
| E — ナレッジグラフ | Wiki BFS 走査；37 ノードをインデックス化；keyword query で隣接ノードまで返す |

現在も実験中または今後の予定：
- MergeGate 統合（実行審査ゲート）
- OpenClaw CLI 完全互換レイヤー
- ドキュメント本文からのリンク抽出（現在は階層構造ベース）
- 中国市場向けのナレッジグラフ事例整備

重要な補足：

- LARC はすでに、Lark ベースの agent work を支える runtime surface としては動いています
- ただし現時点では、Claude Code などの上位エージェントが使う supervised runtime です
- 現時点の主経路は `OpenClaw Agent -> official openclaw-lark plugin + LARC` です
- Lark IM / webhook bot ingress は将来の追加入口であり、必須の中核経路ではありません

詳しくは以下を参照してください。

- [PLAYBOOK.md](PLAYBOOK.md)
- [docs/agentic-larc-mvp-2026-04-14.md](docs/agentic-larc-mvp-2026-04-14.md)
- [docs/larc-vs-lark-cli-and-openclaw.md](docs/larc-vs-lark-cli-and-openclaw.md)
- [docs/goal-aligned-playbook.md](docs/goal-aligned-playbook.md)
- [docs/permission-model.md](docs/permission-model.md)
- [docs/auth-suggest-cases.md](docs/auth-suggest-cases.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [docs/terminology-glossary.ja.md](docs/terminology-glossary.ja.md)

---

## 検証

PR を出す前の軽量なローカル検証:

```bash
# エントリポイントと補助スクリプトの構文確認
bash -n bin/larc scripts/install.sh scripts/auth-suggest-check.sh

# permission-intelligence の回帰チェック
bash scripts/auth-suggest-check.sh --verify
```

これらは GitHub Actions でも実行されます。

---

## ライセンス

MIT
