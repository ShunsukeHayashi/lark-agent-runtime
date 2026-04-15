# OpenClaw Integration

LARC は OpenClaw の **governed runtime layer** として動作します。推奨構成では、OpenClaw の公式 Feishu/Lark channel と、公式 `openclaw-lark` プラグインを併用します。

> **会話入口は 1 つです。** ユーザーが話しかける相手は、OpenClaw の Feishu/Lark channel が接続した chat app / bot です。LARC 用の認証アプリや補助的な IM 経路を別の会話入口として案内しないでください。

## アーキテクチャ

```
OpenClaw Agent
    ↓ OpenClaw Feishu/Lark channel
Lark chat app / bot 接続
    ↓ official openclaw-lark plugin
Lark の原子的な操作（IM / Docs / Base / Calendar ...）
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

### OpenClaw Feishu/Lark channel

- bot / chat app の作成と接続
- DM / group chat の受信経路
- pairing / allowlist / mention requirement
- ユーザー向けの唯一の会話入口

### OpenClaw + official openclaw-lark plugin

- メッセージ送受信 API
- ドキュメント操作
- Base / Approval / Calendar などの原子的アクション
- LLM 実行主体

### LARC

- 必要権限の説明
- 実行ゲート判定
- queue lifecycle
- specialist delegation
- memory / audit / write-back

LARC は channel や plugin の代替ではなく、OpenClaw の実行を Lark 業務フローに合わせて統制する layer です。

## OpenClaw 側セットアップ

### 1. Feishu/Lark channel を接続する

まず、OpenClaw 側で Lark chat app / bot の接続を作ります。これは plugin の役割ではありません。

```bash
openclaw channels login --channel feishu
openclaw gateway restart
```

必要に応じて、pairing や group allowlist も OpenClaw channel 側で設定します。

```bash
openclaw pairing list feishu
openclaw pairing approve feishu <CODE>
```

### 2. official `openclaw-lark` plugin を使える状態にする

この plugin が、OpenClaw から Lark API への原子的操作を担当します。

```bash
bash scripts/install-openclaw-larc-runtime-skill.sh
openclaw skills list | rg larc-runtime
```

> このリポジトリは `larc-runtime` skill を提供します。
> Lark の原子的操作自体は official `openclaw-lark` plugin 側で扱う前提です。
> chat app / bot 接続そのものは OpenClaw の Feishu/Lark channel 側で行います。
> ユーザーには、この channel が作る chat app / bot を案内してください。

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
