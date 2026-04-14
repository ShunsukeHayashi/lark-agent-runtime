---
name: larc-runtime
description: OpenClaw Agent から LARC を使って、権限付きの Lark 業務実行フローを進める
triggers:
  - "larc"
  - "lark runtime"
  - "feishu runtime"
  - "governed lark task"
---

# larc-runtime

## 概要

OpenClaw Agent が Lark/Feishu 業務を扱うときに使う薄い統制スキルです。

- 思考・対話: OpenClaw Agent
- 業務統制: `larc`
- 原子的な Feishu 実行: 公式 `openclaw-lark` plugin

このスキルの目的は、OpenClaw Agent が直接雑に API を叩かず、LARC の queue / gate / lifecycle を通って動くことです。

## 基本原則

1. まず `larc ingress openclaw` で次アクション bundle を取る
2. approval / preview を勝手に飛ばさない
3. Feishu の実操作はできるだけ公式 `openclaw-lark` plugin で行う
4. 状態遷移は `larc ingress done|fail|followup` に戻す

## 基本フロー

### 1. 次の governed action を取得

```bash
bin/larc ingress openclaw --agent main --days 14
```

特定の queue item を指定するとき:

```bash
bin/larc ingress openclaw --queue-id <queue-id> --days 14
```

この出力に含まれるもの:

- `openclaw_command`
- `recommended_commands`
- `gate`
- `authority`
- `task_types`

### 2. OpenClaw へそのまま渡す

ローカル embedded agent:

```bash
bin/larc ingress openclaw --queue-id <queue-id> --execute
```

Gateway 経由:

```bash
bin/larc ingress openclaw --queue-id <queue-id> --gateway --execute
```

### 3. 実行前に文脈を読む

pending / preview item:

```bash
bin/larc ingress context --queue-id <queue-id> --days 14
```

delegated item:

```bash
bin/larc ingress handoff --queue-id <queue-id> --days 14
```

### 4. 実行と state 更新

実行計画:

```bash
bin/larc ingress execute-stub --queue-id <queue-id>
```

安全な adapter 実行:

```bash
bin/larc ingress execute-apply --queue-id <queue-id> --dry-run
```

完了:

```bash
bin/larc ingress done --queue-id <queue-id> --note "Completed by OpenClaw"
```

失敗:

```bash
bin/larc ingress fail --queue-id <queue-id> --note "Reason"
```

手動 follow-up が残るとき:

```bash
bin/larc ingress followup --queue-id <queue-id>
```

## 判断ルール

- `gate: approval`
  - approval が終わるまで実行しない
  - `larc ingress approve` と `larc ingress resume` を通す

- `gate: preview`
  - いきなり本実行せず、まず context / execute-stub を読む

- `authority: user`
  - 実ユーザー権限が必要な操作

- `authority: bot`
  - bot/tenant 側で閉じる操作

- `authority: user or bot`
  - compound task。bundle の flow に従って分割して扱う

## 実行面の役割分担

- LARC:
  - queue
  - permission
  - gate
  - delegation
  - memory retrieval
  - lifecycle

- official openclaw-lark plugin:
  - IM
  - Docs
  - Drive
  - Base
  - Wiki
  - Calendar
  - Task

## Addness ゴール管理との連携

OpenClaw Agent はコーディング作業を Addness ゴールと連動させる。
詳細: [`../addness/SKILL.md`](../addness/SKILL.md)

### 作業開始時

```bash
# git ブランチから自動検出
addness-cli work start

# ゴールID直接指定
addness-cli work start --goal <GOAL_ID>
```

### 作業中（進捗記録）

```bash
addness-cli progress --message "設計完了、実装着手"
```

### 作業完了時（LARC queue 完了と同時に必須）

```bash
# larc ingress done と合わせて実行する
bin/larc ingress done --queue-id <queue-id> --note "Completed by OpenClaw"
addness-cli work done --message "<完了内容>" --pr <PR_URL>
```

### サマリー確認

```bash
addness-cli summary --all
```

### 制約

- **banana org への書き込みは絶対禁止**（読み取り専用）
- ゴール ID 不明時: `addness-cli -- goal list --assigned-to me --json`

## やってはいけないこと

- approval が必要な item を直接実行する
- queue を更新せずに作業だけ終える
- Lark の正本データをローカルだけで完結させる
- LARC を飛ばして直接 API を乱用する
- banana org のゴールを作成・更新・削除する

