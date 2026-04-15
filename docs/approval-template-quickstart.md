# Approval Template Quickstart

まだ Lark 側に承認テンプレートがない状態から、`larc approve` の live 確認に進むまでの最短手順です。

## 1. まず作るもの

最初は「最小の 1 本」で十分です。おすすめは経費申請のような単純なテンプレートです。

- テンプレート名: `Sandbox Expense Request`
- 入力項目:
  - `Title` または `用途`
  - `Amount`
  - `Date`
  - `Attachment` は任意
- 承認経路:
  - 作成者
  - 承認者 1 名

複数段承認や条件分岐は最初は不要です。`larc approve preview/create` の live 確認だけなら、単純な 1 段承認で十分です。

## 2. Lark 管理画面でやること

1. Lark / Feishu の管理画面で Approval を開く
2. 新しい承認テンプレートを作る
3. 入力項目を 2-4 個だけ追加する
4. 承認ノードを 1 つだけ置く
5. 保存して有効化する

このテンプレートが作られると、裏側で `approval_code` が付きます。

## 3. 必要になる値

live 実行に必要なのはこの 2 つです。

- `approval_code`
- 申請者の user id か open id

live 実行前に user open id を確認してください。

```text
ou_REPLACE_WITH_REQUESTER_OPEN_ID
```

## 4. approval_code を保存する

`~/.larc/config.env` を使う場合:

```bash
mkdir -p ~/.larc
cat > ~/.larc/config.env <<'EOF'
LARC_APPROVAL_CODE=REPLACE_ME
EOF
```

毎回引数で渡しても構いません。

## 5. 最短 live 手順

`approval_code` が取れたら、まず package を作るのが一番安全です。

```bash
larc approve scaffold-package --approval-code YOUR_APPROVAL_CODE --output-dir ./approval-work
```

生成されるもの:

- `approval-work/approval-definition.json`
- `approval-work/form.json`
- `approval-work/extra.json`
- `approval-work/README.md`

次に、`form.json` を必要最小限だけ埋めます。

そのあと dry-run:

```bash
scripts/approval-check.sh \
  --approval-code YOUR_APPROVAL_CODE \
  --user-id ou_REPLACE_WITH_REQUESTER_OPEN_ID
```

入力イメージが欲しい場合は [examples/approval/minimal](../examples/approval/minimal) や [examples/approval/purchase-request](../examples/approval/purchase-request) のサンプルも参照できます。

問題なければ live:

```bash
scripts/approval-check.sh \
  --approval-code YOUR_APPROVAL_CODE \
  --user-id ou_REPLACE_WITH_REQUESTER_OPEN_ID \
  --live
```

## 6. 詰まりやすい点

- `approval_code` が未作成
  - テンプレート自体がまだない状態です
- `form.json` の必須項目が空
  - `preview` で先に確認します
- 添付項目がある
  - `larc approve upload-file --path ./file.pdf --type attachment`
- 承認者指定ノードがある
  - `extra.json` の `node_approver_user_id_list` を埋めます

## 7. ここまで終われば確認完了

次が通れば、承認フローの MVP live 確認はほぼ完了です。

- `larc approve definition`
- `larc approve scaffold-package`
- `scripts/approval-check.sh` dry-run
- `scripts/approval-check.sh --live`
