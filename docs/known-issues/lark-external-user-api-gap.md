# 既知課題: Lark 外部ユーザーのAPI参照不可

> 発見日: 2026-04-15  
> 優先度: Medium  
> 対象コンポーネント: `larc auth`, `lark-contact` skill, Wiki メンバー管理

---

## 問題

Lark APIでは、**同一テナント内の内部ユーザー**しか一覧・検索できない。  
外部テナントのユーザー（別会社・別組織のLarkアカウント）は以下の制約がある：

### 制約一覧

| 操作 | 内部ユーザー | 外部ユーザー（別テナント） |
|------|------------|--------------------------|
| 一覧取得 `GET /contact/v3/users` | ✅ 可能 | ❌ 返らない |
| メール検索 `POST /contact/v3/users/batch_get_id` | ✅ open_id返る | ❌ user_idなし（空） |
| 名前検索 `GET /search/v1/user` | ✅ 可能 | ❌ 対象外 |
| Wiki メンバー追加 `POST /wiki/v2/spaces/{id}/members` by email | ✅ 可能 | ❌ `131005: identity not found` |
| 外部コラボレーター一覧API | - | ❌ エンドポイント存在しない |

### 再現手順

```bash
# 外部ユーザーのメールでwikiメンバー追加 → エラー
lark-cli wiki members create \
  --params '{"space_id":"<space_id>"}' \
  --data '{"member_id":"external@gmail.com","member_type":"email","member_role":"member"}'
# → [131005] not found: identity not found by email external@gmail.com

# メールでopen_id検索 → user_idが返らない
lark-cli api POST "/open-apis/contact/v3/users/batch_get_id" --as bot \
  --data '{"emails":["external@gmail.com"]}'
# → {"user_list":[{"email":"external@gmail.com"}]} ← open_id/user_idが含まれない
```

---

## テナントトークン（bot）での検証結果

2026-04-15 に bot identity（テナントアクセストークン）でも同様に確認：

| API | bot結果 |
|-----|--------|
| `GET /contact/v3/users` | 内部ユーザーのみ返る |
| `POST /contact/v3/users/batch_get_id` | 外部emailに対しuser_id未返却 |
| `GET /contact/v3/scopes` | 内部ユーザーのみ |
| `GET /im/v1/chats/{外部chat}/members` | `232033` エラー（外部チャット管理権限なし） |

→ **ユーザートークン・テナントトークンいずれでも外部ユーザーの参照は不可。Larkの仕様として確定。**

## 根本原因

Larkの設計上、**外部テナントユーザーはAPIで一覧・検索できない**。  
外部ユーザーをWikiやドキュメントに追加するには：

1. そのユーザーが **このテナントにゲストとして招待済み**（管理コンソールから）  
2. または **Wiki の open_sharing を変更**してリンク共有を使う

---

## 回避策（現時点）

### Option A: open_sharing でリンク公開（Larkアカウント不要）

```bash
lark-cli api PUT /open-apis/wiki/v2/spaces/<space_id>/setting \
  --data '{"open_sharing":"anyone_readable"}'
```

→ URLを知っていれば誰でも閲覧可能（Larkアカウント不要）

### Option B: 管理コンソールでゲスト招待

Lark管理コンソール（admin.larksuite.com）→ 外部協力者 → 招待  
招待完了後、そのユーザーのopen_idが発行され、API経由でWikiメンバーに追加できる

### Option C: 外部ユーザーのopen_idを直接入力

ユーザー自身にopen_idを確認してもらう → `member_type: "openid"` で追加

```bash
lark-cli wiki members create \
  --params '{"space_id":"<space_id>"}' \
  --data '{"member_id":"ou_XXXXXX","member_type":"openid","member_role":"member"}'
```

---

## LARCへの組み込み提案

### 1. `larc auth suggest` への追加

`外部ユーザー追加` タスクで以下を警告する：

```
WARNING: 外部テナントユーザーはメール検索不可。
管理コンソールでのゲスト招待またはopen_id直接指定が必要。
```

### 2. `lark-contact` skill の更新

`+search-user` / `+get-user` のドキュメントに制約を明記する。

### 3. `larc wiki add-member` コマンド追加（将来）

```bash
larc wiki add-member --space-id <id> --email <email>
# → メール検索 → 失敗時は自動で管理コンソールURLを案内
```

---

## 関連

- Lark API Doc: [knowledge space members](https://open.feishu.cn/document/ukTMukTMukTM/uUDN04SN0QjL1QDN/wiki-v2/space-member/create)
- 発見コンテキスト: 家事代行差配自動化 Wikiへの外部ユーザー追加作業
