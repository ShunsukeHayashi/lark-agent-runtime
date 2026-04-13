# PPAL Lark Base CRM Review

作成日: 2026-04-13  
対象 Base: `PPALファネル管理` (`QRonbSCrBajWRtsZYrTjtUsep0d`)

## 1. 結論

現状の Lark Base は、テーブル分割とセマンティック ID の設計思想は良い一方で、
live データはまだ `Teachable 注文ログ + 一部マーケ構造` の段階にあり、
`L-Step / Teachable / Discord / UTM` を横断する CRM としては未完成。

特に次の 3 点がボトルネック:

1. 設計上の canonical key `line_uid` が live では 0 件入力
2. T1 の journey 情報が未入力で、`lead / buyer` の二値管理に潰れている
3. T3 / T4 / T5 がそれぞれ「分析」「商談」「流入 attribution」の責務をまだ安定して果たしていない

## 2. Live Base 確認サマリー

2026-04-13 時点で `lark-cli` により確認した内容:

- T1 `T1_ユーザー管理`: 6,956 件
- T2 `T2_ステップ配信`: 8 件
- T3 `T3_CV`: 1,101 件
- T4 `T4_ファネル集計`: 3 件
- T5 `T5_流入経路マスタ`: 7 件

### T1 主要カバレッジ

| 項目 | 入力件数 | 所見 |
|------|---------:|------|
| `user_id` | 6,956 | 実運用上の内部キーになっている |
| `segment` | 6,956 | 全件入力 |
| `current_stage` | 6,956 | 全件入力だが実質 2 値 |
| `is_blocked` | 2,164 | ブロック状況のみ一定の情報量あり |
| `added_at` | 6,956 | 友だち追加日は整備済み |
| `line_uid` | 0 | canonical key として機能していない |
| `teachable_id` | 0 | Teachable 突合未整備 |
| `discord_id` | 0 | Discord 突合未整備 |
| `entry_source` | 0 | attribution 未整備 |
| `backfill_status` | 0 | repair オペレーション未整備 |
| `day1_started_at` | 0 | onboarding の進行が見えない |
| `week1_started_at` | 0 | 成果体験到達が見えない |

### T1 stage 分布

| stage | 件数 |
|-------|-----:|
| `buyer` | 4,559 |
| `lead` | 2,397 |

`nurture / prospect / onboarding / active / upsell` は live 集計で未出現。

### T3 主要カバレッジ

| 項目 | 入力件数 | 所見 |
|------|---------:|------|
| `product_name` | 1,101 | 取得済み |
| `amount` | 1,101 | 取得済み |
| `cv_at` | 1,101 | 取得済み |
| `cv_type` | 1,101 | 取得済みだが営業種別化している |
| `status` | 1,101 | 取得済みだが営業管理寄り |
| `teachable_order_id` | 1,095 | 一部欠損あり |
| `cv_source` | 6 | attribution ほぼ未整備 |
| `user_id_ref` | ほぼ未接続 | T1 とのリンクが弱い |

### T3 status 分布

| status | 件数 |
|--------|-----:|
| `フォロー中` | 1,096 |
| `成約` | 5 |

### T4 所見

- live レコードは 3 件のみ
- 週次 / 月次の snapshot テーブルとしては件数不足
- `period` と `memo` の年次表記に不整合がある
- `ad_spend` null/0 行があり、`cpa/roas/cpl` が安定しない

### T5 所見

- 7 件の source マスタはある
- `utm_source / utm_medium / utm_campaign / utm_term` は全件 null
- T1 側 `entry_source` も 0 件で、attribution ハブとして未接続

## 3. 設計と live の主要ギャップ

## 3.1 identity spine の不一致

仕様書では `line_uid` を canonical key としているが、live では `user_id` が実質キー。
このままだと `L-Step / Teachable / Discord` を横断した 1 人 1 profile が成立しない。

## 3.2 journey 管理の未整備

T1 に journey 用の日時列はあるが、live では未入力。
`lead -> buyer -> onboarding -> active` の遷移が見えず、
オンボーディング repair や activation 施策に使えない。

## 3.3 T3 の責務混線

T3 は本来 `コンバージョン記録` だが、live では
注文ログ、商談ログ、フォロー進行、返金/キャンセルの表現が 1 テーブルに混在している。

## 3.4 attribution 未接続

T5 の構造はあるが、T1/T3 に attribution が流れていない。
このため「どの流入が buyer / membership に効いたか」が見えない。

## 3.5 KPI snapshot 不足

T4 の live 件数が少なく、週次モニタリングや変化量比較に耐えない。
formula 自体は良いが、投入元の raw 数値が安定していない。

## 4. 既存要件文書との整合

`12-docs/architecture/domain-design/ppal-customer-crm-requirement.md` と比較すると、
今回のレビューで見えた課題は既存要件と概ね一致している。

特に整合するポイント:

- CRM の中心は `lead/customer profile` であるべき
- `LINE UID` は強い link だが、内部 primary identity そのものとは分けて扱う
- `commerce_events`, `entitlements`, `journey_states` を責務分離すべき
- `line_linked`, `discord_linked`, `week1_opened` などの operational state を持つべき

つまり、新しい方針を作るよりも、
既存要件を live Base と同期させるのが正しい次の一手。

## 5. 改善ロードマップ

## Phase 0: ドキュメントと実体の同期

目的: 仕様と live のズレを見える化し、今後の自動化が壊れない土台を作る。

- `spec.md` と `field-map.md` に「live 差分」セクションを追加
- T3 `cv_type` / `status` の live 値に合わせて設計記述を更新
- `README.md` の `lark-cli` 誤記を修正
- coverage 指標を文書化:
  - `line_uid_filled / total`
  - `teachable_id_filled / total`
  - `discord_id_filled / total`
  - `entry_source_filled / total`
  - `T3 user_id_ref linked / total`

## Phase 1: identity spine 再設計

目的: 1 人 1 profile への解決率を上げる。

- T1 に `identity_status` を追加
  - `unresolved`
  - `teachable_only`
  - `line_only`
  - `discord_only`
  - `resolved`
  - `needs_review`
- T1 に `primary_email_normalized` を追加
- T1 に `teachable_email` を追加
- `line_uid` が本当に canonical か再判断
  - 維持する場合: L-Step 同期で最優先入力
  - 変更する場合: `user_id` を internal profile key として再定義

## Phase 2: T3 の責務分離

目的: 注文ログと商談/営業状態を分ける。

推奨案:

- `T3_orders`
  - teachable_order_id
  - product_code
  - product_name
  - amount
  - cv_at
  - source_ref
  - profile_ref
  - raw_provider
- `T3_pipeline`
  - profile_ref
  - opportunity_type
  - pipeline_status
  - owner
  - next_action_at
  - memo

分離しない場合でも最低限:

- `status` を営業状態か会計状態かで定義し直す
- `cv_type` を product/category 軸と event type 軸に分割する

## Phase 3: journey state の実装

目的: `初月の成果体験` を CRM で見えるようにする。

T1 に追加または別テーブル化したい state:

- `line_linked_at`
- `discord_linked_at`
- `teachable_linked_at`
- `week1_opened_at`
- `week1_completed_at`
- `activation_status`
- `churn_risk_status`

推奨ビュー:

- `要ID解決`
- `Discord未連携`
- `Week1未開始 3日超`
- `M2バックフィル対応待ち`
- `buyer だが onboarding 未着手`

## Phase 4: attribution 復旧

目的: 流入から buyer までの分析を可能にする。

- T5 に `campaign_owner`, `default_product`, `cost_bucket` を追加
- T1 の `entry_source` は自由入力ではなく `source_ref` 由来にする
- T3 に `source_ref` 追加または `cv_source` を `source_ref` に置換
- `utm_*` を LP / webhook / L-Step から最低限 backfill

## Phase 5: KPI snapshot 自動化

目的: T4 を monitor 用 truth に近づける。

- 毎日 or 毎週の snapshot job を固定化
- T4 に `snapshot_date`, `window_start`, `window_end`, `calc_version`, `is_complete` を追加
- raw 数値と formula の責務を分離
- `period` と `memo` の年次表記ズレを解消

## 6. 優先度つき実装順

### P0

- README / spec / field-map の drift 修正
- identity spine の定義確定
- T1 coverage dashboard の追加

### P1

- T3 の責務整理
- journey state 導入
- M2 / Week1 オペレーションビュー整備

### P2

- attribution 復旧
- T4 snapshot 自動化
- 商品名正規化マスタ導入

## 7. 次の具体アクション

1. `spec.md` と `field-map.md` に live 差分を反映する
2. T1/T3 再設計案をフィールド差分レベルで作る
3. coverage を集計する `lark-cli base +data-query` コマンド群を runbook 化する
4. `M2バックフィル対応待ち` と `buyer だが Week1 未開始` のビューを優先運用する
