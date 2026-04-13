# Approval Spike — 2026-04-13

目的は、`larc approve create` の実装可否を現行 `lark-cli` と公式 OpenAPI の両方から確定することです。

## 結論

- `lark-cli approval` には新規起票 shortcut はありません
- ただし、公式 OpenAPI には `POST /open-apis/approval/v4/instances` が存在します
- `lark-cli api` で raw API として組み立てることはできます
- したがって、`Approval` 起票の unblock 手段としては **局所フォーク必須ではありません**
- まずは raw API ベースで `larc` 側の helper を作る方が筋が良いです

## ローカル確認

### 1. 現行 CLI の registered command

```bash
lark-cli approval --help
lark-cli approval instances --help
```

確認できたもの:

- `instances.get`
- `instances.cancel`
- `instances.cc`
- `tasks.query`
- `tasks.approve`
- `tasks.reject`
- `tasks.transfer`

確認できなかったもの:

- `approval instances create`

### 2. schema 確認

```bash
lark-cli schema approval.instances.create
```

結果:

- `Unknown method: approval.instances.create`

つまり、**schema / shortcut の両方で create は未登録** です。

### 3. raw API dry-run

```bash
lark-cli api POST /open-apis/approval/v4/instances --dry-run --data '{
  "approval_code":"APPROVAL_CODE",
  "user_id":"USER_ID",
  "form":"[{\"id\":\"widget1\",\"type\":\"input\",\"value\":\"demo\"}]"
}'
```

dry-run では正常に request 形状が出力されました。`lark-cli api` で path と body をそのまま通せます。

## 公式ドキュメントで確認できたこと

### 新規起票 API

- HTTP: `POST`
- Path: `/open-apis/approval/v4/instances`
- 主要 scope:
  - `approval:approval`
  - `approval:instance`

必須パラメータ:

- `approval_code`
- `form`
- `user_id` または `open_id`

補助パラメータ:

- `department_id`
- `node_approver_user_id_list`
- `node_approver_open_id_list`
- `node_cc_user_id_list`
- `node_cc_open_id_list`
- `uuid`
- `allow_resubmit`
- `allow_submit_again`
- `forbid_revoke`
- `title`
- `i18n_resources`

補足:

- `form` は JSON 配列そのものではなく、**JSON を文字列化した値**として送ります
- 自選承認人や自選 CC がある場合、`approval get` の `node_list` から `node_id` / `custom_node_id` を引いて埋める必要があります

### 事前プレビュー API

- HTTP: `POST`
- Path: `/open-apis/approval/v4/instances/preview`
- 主 scope:
  - `approval:approval:readonly`

用途:

- 実起票前にフローを確認
- 自選ノードや後続ノードの見え方をチェック

### 定義取得 API

- HTTP: `GET`
- Path: `/open-apis/approval/v4/approvals/:approval_code`
- 主 scope:
  - `approval:approval`
  - `approval:approval:readonly`
  - `approval:definition`

用途:

- `form` の widget 構造確認
- 自選承認人ノードの `node_id` 取得
- `need_approver` / `custom_node_id` の確認

### ファイル upload

添付や画像のあるフォームでは先に upload が必要です。

公式ドキュメント:

- URL: `https://www.feishu.cn/approval/openapi/v2/file/upload`

注意:

- この endpoint は通常の `/open-apis/approval/v4/...` 系と別です
- `lark-cli api --file` の dry-run では `/open-apis/approval/openapi/v2/file/upload` として組めることは確認済みです
- ただし live 実行まではまだ見ていません

## 実装方針

### MVP / v1

- `larc approve list` は今のまま維持
- `larc approve create` は raw API helper に寄せる
- 最初は **JSON payload file を受け取る薄い wrapper** で十分

### 推奨フロー

1. `approval_code` を決める
2. `approval get` で form / node_list を取得する
3. 必要なら `preview` を叩く
4. `instances` create を叩く
5. 添付がある場合だけ file upload を先に行う

## 局所フォーク判断

現時点の判断:

- **局所フォークは必須ではない**
- `lark-cli api` で unblock できる
- ただし、フォーム構築を対話的にやりたい、添付 upload を一体化したい、definition から自動で widget 雛形を作りたい、という要件が強くなったら `larc` 側 helper 強化は必要

## 次に実装するとよいもの

1. `larc approve create --approval-code ... --user-id ... --form-file ... --dry-run`
2. `larc approve preview --approval-code ... --user-id ... --form-file ...`
3. `larc approve definition <approval_code>`
4. `larc approve scaffold-form --definition-file ... --output form.json`
5. `larc approve scaffold-payload --definition-file ... --output extra.json`
6. 添付が必要なら `larc approve upload-file`
7. 追加項目が必要なら `--payload-file extra.json`

追記:

- `larc approve upload-file --path ./file.pdf --type attachment --dry-run`
- `larc approve upload-file --path ./image.png --type image --dry-run`
- `larc approve scaffold-form --definition-file approval-definition.json --output form.json`
- `larc approve scaffold-payload --definition-file approval-definition.json --output extra.json`
- `larc approve create --approval-code ... --user-id ... --form-file form.json --payload-file extra.json --dry-run`

## 参照

- `https://open.feishu.cn/document/server-docs/approval-v4/instance/create.md`
- `https://open.feishu.cn/document/server-docs/approval-v4/instance/approval-preview.md`
- `https://open.feishu.cn/document/server-docs/approval-v4/approval/get.md`
- `https://open.feishu.cn/document/server-docs/approval-v4/file/upload-files.md`
