# LARC — Lark Agent Runtime

> Lark（飛書）ネイティブな一般業務エージェントのための permission-first runtime

[English](README.md) | [简体中文](README.zh-CN.md) | 日本語

正式名: `Lark Agent Runtime`
略称: `LARC`

---

## LARC とは

**LARC** は、[OpenClaw](https://github.com/BerriAI/OpenClaw) スタイルのエージェント運用を、Lark 上の一般業務へ持ち込むためのランタイムです。

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

---

## 主な機能

| 機能 | 説明 |
|------|------|
| `larc bootstrap` | Drive 上の `SOUL.md → USER.md → MEMORY.md → HEARTBEAT.md` をまとめて取り込む |
| `larc auth suggest` | 自然文タスクから必要 scope と authority を推定する |
| `larc memory` | Base と日次メモリを同期する |
| `larc send` / `larc task` | IM 送信や業務タスク操作の基本経路を提供する |
| Approval 対応 | 承認インスタンス生成と承認タスク実行を分けて扱う |
| Claude Code skills | `.claude/skills/` に Lark 系スキル群を同梱する |

---

## クイックスタート

```bash
npm install -g @larksuite/cli
git clone https://github.com/ShunsukeHayashi/larc-openclaw-coding-agent
cd larc-openclaw-coding-agent
chmod +x bin/larc
export PATH="$PWD/bin:$PATH"
larc init
larc bootstrap
```

---

## 現在の状態

このプロジェクトはまだ incubation 段階です。ただし、次の部分はすでに前進しています。

- bootstrap / memory / send / task の基本経路
- `auth suggest` の初期実装と回帰ケース
- approval モデルのスパイク
- OpenClaw 的 disclosure chain を Lark 上で再現する方向性

詳しくは以下を参照してください。

- [PLAYBOOK.md](PLAYBOOK.md)
- [docs/goal-aligned-playbook.md](docs/goal-aligned-playbook.md)
- [docs/permission-model.md](docs/permission-model.md)
- [docs/open-source-trilingual-plan.md](docs/open-source-trilingual-plan.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [docs/terminology-glossary.ja.md](docs/terminology-glossary.ja.md)
- [docs/release-checklist.md](docs/release-checklist.md)
- [docs/release-readiness-2026-04-14.md](docs/release-readiness-2026-04-14.md)
- [docs/public-release-bundle-2026-04-14.md](docs/public-release-bundle-2026-04-14.md)
- [docs/bundle-a-readiness-2026-04-14.md](docs/bundle-a-readiness-2026-04-14.md)

---

## ライセンス

MIT
