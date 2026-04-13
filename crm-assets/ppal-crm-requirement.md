# Miyabi Lead-to-Customer CRM Requirement

作成日: 2026-04-06
位置づけ: 合同会社みやび全体で、見込み客から顧客化後までを横断管理するための最小要件

## 1. リクエストの整理

求めているものは `ID連携` 単体ではなく、合同会社みやびとして
`見込み客 -> 購入者 -> 継続顧客` を一画面で見えるようにする CRM です。

- まだ購入していない見込み客も管理する
- この人は誰か
- LINE / Discord / Teachable がどれと紐づいているか
- どこから流入したか
- いまどの事業・商品に興味を持っているか
- どの商品を買っているか
- どのコースを受講しているか
- 今どこまで使っているか
- 課金は有効か / 解約済みか / 要対応か
- Teachable 上の学習進捗と理解度 proxy を見て、LINE follow-up をどう出し分けるか

## 2. 何を 1:1 で持ち、何を 1:N で持つか

### 1:1

- lead / customer profile
- LINE account
- Discord account
- Teachable account

### 1:N

- purchased products
- course entitlements
- enrollment / completion / usage events
- billing events
- journey states
- support notes / segmentation attributes

## 3. リード管理を最初から含める

この CRM は `サービスごとの会員台帳` ではなく、
`合同会社みやび全体のリスト基盤` として扱います。

そのため、未購入の見込み客でも profile を作成できる必要があります。

最低限の状態:

- `lead`
- `engaged`
- `purchased`
- `active_customer`
- `churned`

最低限の入口:

- LP からの LINE 登録
- セミナー
- note
- 紹介
- 手動追加
- 将来の法人問い合わせ

## 3.1 LINE tenant policy

この CRM の前提として、外向きの公式 LINE アカウントは当面 1 本に集約する。

- 外向き入口: `みやび公式LINE`
- 内部境界: tenant / line_account / campaign / journey / entitlement

理由:

- 会社として 1 つの list を育てたい
- 既存顧客 migration を単純に保ちたい
- どの LINE に登録すればよいかの迷いを減らしたい
- 名寄せ / support / backfill を壊さない

つまり、`OA を分けて CRM を作る` のではなく、
`1 本の OA を入口にして、内側のモデルをマルチテナント化する` 方針を取る。

## 4. 現状の実装

現行の `unified_profiles` は、互換 projection として次を部分的に保持しています。

- `line_uid`
- `teachable_id`
- `teachable_email`
- `discord_id`
- `discord_username`
- `discord_roles`

つまり、`誰と誰がつながっているか` までは持てます。
ただし、`何を買っているか / 何を使っているか / 課金状態はどうか` を長期運用に耐える形ではまだ持てていません。

## 5. 目標モデル

### `hub_profiles`

見込み客 / 顧客そのもの。

最低限持つ項目:

- `id`
- `display_name`
- `primary_email_normalized`
- `lifecycle_stage`
- `lead_source`
- `interest_products_json`
- `customer_tier`
- `created_at`
- `updated_at`

`lifecycle_stage` の候補:

- `lead`
- `engaged`
- `purchased`
- `active_customer`
- `churned`
- `needs_review`

補足:

- `lifecycle_stage` は CRM 上の事業ステージを表す
- pending capture 契約の `lifecycle_state` は identity resolve の状態軸であり、同じ列として扱わない
- `hub_profiles` は内部 profile の本体であり、外部 ID や購入イベントの生ログはここに持たない

### `channel_links`

外部アカウント紐付け。

- `line`
- `discord`
- `teachable`
- `email`

補足:

- `channel_links` の責務は `どの外部 ID がどの profile に、どの確度で紐づくか` だけに限定する
- `LINE UID` は強い link として扱うが、内部 primary identity そのものにはしない
- 購入事実、権限、導線進行はここで持たない

### `line tenant scope`

内部では `line_account` / tenant scope を持つ。

用途:

- 事業別配信境界
- campaign 切り分け
- reminder / automation の所属
- operator 向けの配信責務分離

ただし、これは外向きの OA 分割を直ちに意味しない。

### `entitlements`

顧客が何を買っていて、何にアクセスできるか。

最低限持つ項目:

- `profile_id`
- `product_code`
- `course_code`
- `entitlement_key`
- `status`
- `valid_from`
- `valid_until`
- `source_event_id`

補足:

- `entitlements` は現在有効な権限の truth を持つ
- `pending` と `active` の両方を許容し、未連携の購入も失わない
- raw webhook payload や marketing source はここに混ぜない

### `commerce_events`

購入 / 解約 / 登録の事実ログ。

最低限持つ項目:

- `provider_event_id`
- `event_type`
- `product_code`
- `course_code`
- `pricing_plan_id`
- `subscription_id`
- `amount`
- `currency`
- `occurred_at`
- `raw_payload_json`

補足:

- `commerce_events` は append-only の監査ログとして扱う
- idempotency と provider event の原本保持が主責務で、現在権限の最終判定はしない
- 未解決 profile でも先に capture し、後で resolve する

### `journey_states`

今どこまで進んでいるか。

例:

- `teachable_purchased`
- `line_linked`
- `discord_linked`
- `week1_opened`
- `week1_completed`
- `churn_risk`

補足:

- `journey_states` は operator が `次に何をすべきか` を判断するための進行状態を持つ
- 購入の真実や access 権限の truth は持たず、`commerce_events` と `entitlements` の結果を operational に投影する
- migration 期間中は `migration_invited` / `needs_review` などの運用 step をここで追う

## 5.2 Teachable x LINE CRM engagement measurement

Teachable を `オンラインコース配信基盤` として使い続ける場合でも、
CRM 側は `購入済み` だけでは不十分で、`受講開始 / 進捗 / 完了 / 停滞` を持つ必要がある。

そのため、`commerce_events` とは別に `learning_events` を持つ。

最低限の learning signal:

- `Enrollment.created`
- `LectureProgress.created`
- `Response.created`
- `Enrollment.completed`

そして operator 向け read model では、少なくとも次が見える必要がある。

- 今どの course / week にいるか
- 最終 progress はいつか
- 完了率は何 % か
- quiz でつまずいていそうか
- 次に LINE で何を送るべきか

詳細は `teachable-line-engagement-measurement.md` を参照。

## 5.1 実装視点での最小境界

`hub_profiles / channel_links / commerce_events / entitlements / journey_states` はそれぞれ別責務として実装する。

### `hub_profiles` が持つもの / 持たないもの

持つもの:

- 顧客 1 人を表す内部 profile
- CRM 事業ステージ
- 表示名、主メール、tier、最小の属性

持たないもの:

- LINE UID / Discord ID / Teachable ID の生値
- 購入 webhook の raw payload
- コース利用権の最終判定

### `channel_links` が持つもの / 持たないもの

持つもの:

- 外部チャネル種別
- 外部 ID
- verified / unverified など link の確度

持たないもの:

- 顧客の購買状態
- entitlement 状態
- follow-up の進捗

### `commerce_events` が持つもの / 持たないもの

持つもの:

- 購入 / 解約 / enrollment の正規化イベント
- provider event id と raw payload
- resolve 前でも失わない監査証跡

持たないもの:

- operator 向け current status 表示
- 現在 active な access 判定

### `entitlements` が持つもの / 持たないもの

持つもの:

- 商品 / コース / コミュニティへの現在アクセス権
- `pending`, `active`, `cancelled`, `expired` などの権限状態
- どの event から生じた権限か

持たないもの:

- raw purchase payload
- lead source や campaign attribution
- UI 上の migration step 文言

### `journey_states` が持つもの / 持たないもの

持つもの:

- onboarding / migration / activation の現在 step
- 次アクション判断に必要な operational state
- `line_linked`, `discord_linked`, `migration_completed`, `needs_review` などの状態

持たないもの:

- 課金原本
- access 権限の truth
- 外部 ID の canonical 保存先

## 6. CRM 画面で最低限見たい項目

1 lead / customer に対して、次を同時に見えるようにする。

### identity

- 顧客名
- LINE UID
- Discord username / ID
- Teachable user id / email

### lead

- lead source
- first touch
- interested product
- seminar / note / campaign 由来
- purchase 前か後か

### billing

- 購入商品一覧
- 現在のプラン
- active / cancelled / expired
- 最終課金日
- 次回課金予定
- 累計課金額

### usage

- 受講中コース
- Week1 到達済みか
- 最終アクティビティ
- Discord 参加済みか
- follow-up の進行状況

### support / segmentation

- VIP / membership / archive
- churn risk
- support required
- first touch / campaign source

## 7. 最小実装順

1. LP / LINE 起点で `lead profile` を先に作れるようにする
2. `channel_links` で LINE / Discord / Teachable を profile に束ねる
3. `commerce_events` で purchase / cancel / enrollment を監査保存する
4. `entitlements` で商品 / コース / コミュニティ権限を正規化する
5. `journey_states` で lead -> purchase -> activation を持つ
6. admin read model で `lead + customer 360` 画面を出す

## 8. 一言でいうと

やりたいことは `LINE CRM` ではなく、`合同会社みやびの lead-to-customer CRM` です。

`LINE UID` は canonical な強いキーとして使い続けつつ、
CRM としては `lead / customer profile` を中心に、
`identity`, `lead`, `billing`, `usage`, `journey` を分離して持つのが正しいです。
