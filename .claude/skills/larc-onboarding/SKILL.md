---
name: larc-onboarding
version: 1.0.0
description: "LARC のオンボーディング専用スキル。OpenClaw Feishu/Lark channel、official openclaw-lark plugin、LARC runtime、lark-cli 認証の役割を分離し、ユーザーが正しい chat app / bot に到達するまでの手順をガイドする。"
---

# LARC Onboarding — OpenClaw Channel First

**TRIGGER**: ユーザーが LARC の初期導入、接続確認、オンボーディング、テストユーザー案内、plugin/channel の役割整理を必要としているとき。

## このスキルの目的

オンボーディング時に次の混同を防ぐ:

- OpenClaw Feishu/Lark channel
- official `openclaw-lark` plugin
- LARC runtime
- `lark-cli` の App ID / App Secret

**原則**:

1. ユーザーが実際に話しかける入口は **OpenClaw Feishu/Lark channel が接続した bot / chat app**
2. official `openclaw-lark` plugin はその背後で原子的な Lark API 操作を行う
3. LARC は gate / queue / audit / memory を統制する
4. `lark-cli` のアプリ資格情報は runtime 認証用であり、別の会話入口ではない

## 役割分担

| 層 | 役割 | 典型コマンド |
|---|---|---|
| OpenClaw Feishu/Lark channel | ユーザー向け chat app / bot 接続、DM / group 入口、pairing | `openclaw channels login --channel feishu` |
| official `openclaw-lark` plugin | IM / Docs / Base / Calendar などの原子的操作 | OpenClaw plugin 側設定 |
| LARC | 権限説明、approve gate、queue、write-back、audit | `larc quickstart`, `larc ingress ...` |
| lark-cli auth | LARC runtime が tenant 資源へ接続するための認証 | `lark-cli config init`, `lark-cli auth login` |

## 標準オンボーディング順序

### Step 0. 会話入口を固定する

最初に次を明言する:

- テストユーザーが使うのは **OpenClaw channel 側の bot / chat app**
- LARC 用のアプリ資格情報は、ユーザーに追加案内する chat app ではない

### Step 1. OpenClaw を確認する

```bash
which openclaw
openclaw --version
```

未導入なら、LARC より先に OpenClaw の利用環境を整える。

### Step 2. OpenClaw Feishu/Lark channel を接続する

```bash
openclaw channels login --channel feishu
openclaw gateway restart
```

必要に応じて:

```bash
openclaw pairing list feishu
openclaw pairing approve feishu <CODE>
```

group 運用では `groupPolicy`、`groupAllowFrom`、`requireMention` を確認する。

**成功条件**:

- ユーザーに案内する bot / chat app が 1 つに確定している
- 「どの chat に話しかけるか」を説明できる

### Step 3. official `openclaw-lark` plugin を確認する

plugin は chat 入口ではなく、OpenClaw の背後で Lark API を叩く層であることを明言する。

確認内容:

- official `openclaw-lark` が利用可能か
- IM / Docs / Base などの atomic action が plugin 側で処理される構成か

### Step 4. LARC runtime skill を入れる

```bash
bash scripts/install-openclaw-larc-runtime-skill.sh
openclaw skills list | rg larc-runtime
```

### Step 5. LARC 本体と `lark-cli` 認証を整える

```bash
npm install -g @larksuite/cli
curl -fsSL https://raw.githubusercontent.com/ShunsukeHayashi/lark-agent-runtime/main/scripts/install.sh | bash
larc version
```

その後:

```bash
lark-cli config init --app-id <APP_ID> --app-secret-stdin --brand lark
lark-cli auth login
lark-cli auth status
```

### Step 6. LARC quickstart を実行する

```bash
larc quickstart --dry-run
larc quickstart
```

### Step 7. 動作確認を分離して行う

#### A. runtime 側確認

```bash
larc status
larc ingress enqueue --text "onboarding test" --agent main --source claude-code
larc ingress openclaw --agent main --days 14
```

#### B. chat 入口確認

- ユーザーは OpenClaw channel bot / chat app にメッセージを送る
- LARC auth 用アプリには送らせない

## エージェントが必ず明記すべきこと

- 「plugin を入れれば chat app が増える」わけではない
- 「会話入口」は OpenClaw channel 側
- `lark-cli` の App ID / App Secret は runtime 配管
- experimental IM daemon loop は主要オンボーディング導線ではない

## よくある失敗

| 失敗 | 原因 | 正しい案内 |
|---|---|---|
| 別アプリが立ち上がる | `lark-cli` の資格情報と会話入口を混同 | ユーザーは OpenClaw channel bot に話しかけると明記する |
| plugin 導入だけで chat できると思う | channel と plugin の役割混同 | 先に `openclaw channels login --channel feishu` |
| LARC daemon を主経路にしてしまう | experimental 経路を先に案内 | supervised / OpenClaw-assisted を先に案内 |
| queue は動くが chat が通らない | pairing / allowlist / mention 条件未確認 | OpenClaw channel 設定を確認する |

## 完了条件

オンボーディング完了とみなす条件:

1. ユーザーに案内する chat app / bot が 1 つに固定されている
2. OpenClaw channel と official plugin の役割を説明できる
3. `larc quickstart` が通る
4. `larc status` が通る
5. `larc ingress openclaw` で bundle を出せる
6. テストユーザーが正しい chat app / bot に送信できる

## 参照

- [docs/quickstart-ja.md](../../../docs/quickstart-ja.md)
- [docs/openclaw-integration.md](../../../docs/openclaw-integration.md)
- [references/onboarding-checklist.md](references/onboarding-checklist.md)
