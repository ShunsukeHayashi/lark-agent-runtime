# OpenClaw Integration

LARC は OpenClaw の **governed runtime layer** として動作します。推奨構成では、公式 `openclaw-lark` プラグインと一緒に使います。

## アーキテクチャ

```
OpenClaw Agent
    ↓ official openclaw-lark plugin
Lark の原子的な操作
    ↓
LARC
    - auth suggest
    - approve gate
    - queue / delegation
    - memory / audit
    ↓
Lark tenant surfaces
```

## 役割分担

### OpenClaw + official openclaw-lark plugin

- メッセージ送信
- ドキュメント操作
- Base / Approval / Calendar などの原子的アクション
- LLM 実行主体

### LARC

- 必要権限の説明
- 実行ゲート判定
- queue lifecycle
- specialist delegation
- memory / audit / write-back

LARC は plugin の代替ではなく、OpenClaw の実行を Lark 業務フローに合わせて統制する layer です。

## OpenClaw 側セットアップ

```bash
bash scripts/install-openclaw-larc-runtime-skill.sh
openclaw skills list | rg larc-runtime
```

> このリポジトリは `larc-runtime` skill を提供します。
> Lark の原子的操作自体は official `openclaw-lark` plugin 側で扱う前提です。

## OpenClaw への bundle 設計

`larc ingress openclaw` が OpenClaw に渡す bundle には以下が含まれます：

- キューアイテムの詳細（queue_id, task_types, scopes, message）
- 次に安全に行うべき LARC コマンド
- done / fail / followup に戻すための lifecycle guidance
- memory / audit に戻すための guidance

## 実行フロー

```bash
# queue item を OpenClaw 向けに整形
larc ingress openclaw --queue-id <id> --agent main --days 14

# OpenClaw へ直接 dispatch する場合
larc ingress openclaw --queue-id <id> --execute
```

推奨運用は supervised / OpenClaw-assisted です。`larc daemon start` による IM 起点自動ループはまだ experimental とみなしてください。

## experimental IM loop について

LARC には daemon / IM poller / worker の経路もありますが、これは安定した主経路として案内しません。必要なときだけ検証用に使ってください。

```bash
larc daemon start --agent main --interval 30
larc daemon status
larc daemon logs
```

`LARC_ALLOW_FROM` などの絞り込みは補助的に使えますが、公開 onboarding では OpenClaw-assisted path を優先してください。
