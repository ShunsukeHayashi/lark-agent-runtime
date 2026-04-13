# LARC Parallel Execution Playbook

> 目的: 残タスクを「今すぐ並列化できるもの」と「一本で詰めるべきもの」に分け、最短で live 確認と MVP 到達へ進める。

## Current Goal

最短ゴールは 2 つです。

1. `MVP 実装確認`
2. `Approval 起票` を除いた `MVP 実装達成`

## Critical Path

以下は同じ Lark 資源を触るため、基本的に一本で進める。

1. `larc init`
2. `scripts/setup-workspace.sh` の live 実行
3. `larc bootstrap --agent main`
4. `larc memory pull/push`
5. `larc send`
6. `larc task create/done`

理由:
- 同じ `Drive folder` / `Base token` / `agents_registry` を共有する
- 失敗時の切り分けが直列の方が速い
- 並列で書き込むと原因が混ざる

## Parallel Lanes

### Lane A — Live Check Script

目的:
- 実トークンを入れたらそのまま実行できる確認手順を固定する

作業:
- `scripts/live-check.sh` を追加
- `init -> status -> bootstrap -> memory push/pull -> task create -> agent register -> send` の順を定義
- 各段階で fail-fast する

成果物:
- `scripts/live-check.sh`
- README の live check 節

現在地:
- 実装済み
- 次は実トークンで critical path を一本で流すだけ

依存:
- 低い

### Lane B — README / Docs Cleanup

目的:
- README / PLAYBOOK / 実装の呼び方を完全一致させる

作業:
- `approve` の現状を明確化
- `task create` / `agent register` の非対話引数を例に合わせる
- 「今どこまでできるか」を明文化

成果物:
- `README.md`
- `PLAYBOOK.md`

依存:
- 低い

### Lane C — Approval Spike

目的:
- `approval instance create` の現実ルートを確定する

作業:
- `lark-cli api` で Approval 起票 API を叩けるか検証
- 必要 scope と payload を記録
- raw API で行くか、局所フォークか判断

成果物:
- `docs/approval-spike.md` もしくは `PLAYBOOK.md` の更新

現在地:
- 実装済み
- raw API ルートは確認済み
- 次は helper 実装か live token での起票確認

依存:
- 低い
- MVP の live check とは独立

### Lane D — Multi-Agent Registration

目的:
- 複数エージェント登録を一括で回せるようにする

作業:
- `agents.yaml` フォーマットを確定
- `scripts/register-agents.sh` を追加

成果物:
- `agents.yaml.example`
- `scripts/register-agents.sh`

現在地:
- 実装済み
- 次は live token / real chat_id で実登録確認

依存:
- 中
- core MVP の後でもよい

## Recommended Execution Order

最短で成果を見るなら、この順です。

1. Lane A を先に作る
2. そのまま critical path の live 確認を一本で走らせる
3. 並行して Lane B を整える
4. MVP と独立で Lane C をスパイクする
5. 余力があれば Lane D

## What Can Run In Parallel Right Now

今すぐ並列化して良いのは次の 3 つです。

- `Lane A`: live-check スクリプト整備
- `Lane B`: README / PLAYBOOK 整合
- `Lane C`: Approval 起票スパイク

今はまだ並列化しない方が良いもの:

- `setup-workspace` の live 実行
- `bootstrap`
- `memory push/pull`
- `send`
- `task create/done`

## Definition of Done

### MVP 確認完了

- `scripts/smoke-check.sh` が通る
- `scripts/live-check.sh` が実トークンで最後まで通る

### MVP 実装達成

- `Approval 起票` を除く core command が live で確認済み
- README と実装の呼び方が一致
- 残課題が `Approval spike` に限定される
