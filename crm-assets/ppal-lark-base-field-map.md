# Lark Base フィールドマップ

> 最終更新: 2026-04-13（live review 反映）
> Base: PPALファネル管理（`QRonbSCrBajWRtsZYrTjtUsep0d`）

## 設計原則（識学理論ベース）

テンプレート（`Lark_base_template.md`）に準拠。

| 原則 | 実装 |
|------|------|
| 責任と権限の明確化 | 各フィールドでソース責任者を明記 |
| 結果重視の命名 | 数値・事実ベースのフィールド名 |
| セマンティックID | 先頭Formula: `{種別}-YYYYMM-NNN \| 文脈` |
| 誤解排除 | 番号プレフィックス付きステータス値 |
| 感情的判断の排除 | 客観的データのみ格納 |

### セマンティックID設計

```
T1_ユーザー管理: USR-YYYYMM-NNN | display_name
T3_CV:          CV-YYYYMM-NNN  | product_name ¥amount
T4_ファネル集計: KPI-YYYYMM     | period_type CVR:%
```

## Current Truth Note

この field map は design intent と live current truth の両方を保持する。
2026-04-13 時点では以下の drift を確認:

- T1 の identity / journey / attribution 系は大半未入力
- T3 の select 値は旧 design 記述から変更済み
- T5 の `utm_*` は live 未入力

current truth の説明が必要な箇所には各テーブル下に `live note` を付与する。

---

## T1_ユーザー管理（tbl4sJd5HVE7u47v）

| フィールド名 | フィールドID | 型 | ソース | 備考 |
|------------|------------|---|------|------|
| **🆔 ユーザーID** | **fldDfsIf2a** | **formula** | **自動** | **セマンティックID: USR-YYYYMM-NNN \| 表示名** |
| **連番** | **flduIneGBi** | **auto_number** | **自動** | **月内連番（000始まり）** |
| line_uid | fldyRbKnRO | text | L-Step/みやびLINE | **Canonical Key** |
| lstep_id | fldPmQRERz | text | L-Step | CRM主系統照合キー |
| user_id | fldQT95VKX | text | 内部ID | |
| display_name | fldPTBnk3H | text | L-Step | 表示名 |
| teachable_id | fldXZ9lXIi | text | Teachable | 購入照合キー |
| discord_id | fldEYkNhnP | text | Discord | コミュニティID |
| discord_role_at | fldaXd1ndg | datetime | Discord | ロール付与日時 |
| added_at | fldyH3Y0Ji | datetime | L-Step | M0（友だち追加） |
| primary_email_normalized | fldGkDBluL | text | 手動/派生 | P0追加。正規化メール |
| teachable_email | fldVDGISwi | text | Teachable | P0追加。Teachable照合メール |
| day1_started_at | fldnrbbUuc | datetime | Teachable/L-Step | M1（Day1開始） |
| day3_completed_at | fldPJb8pn9 | datetime | Teachable | Day3完了 |
| day5_completed_at | fldqNrA2Nw | datetime | Teachable | Day5完了 |
| week1_started_at | fldTG8fwSb | datetime | Teachable | Week1開始 |
| last_activity_at | flduPOY4dL | datetime | L-Step | 最終アクティビティ |
| blocked_at | fldSzPVyMY | datetime | L-Step | ブロック日時 |
| is_blocked | fldTqvOIHL | checkbox | L-Step | ブロックフラグ |
| current_stage | fldzocGfQh | select | 手動/自動 | awareness/lead/nurture/prospect/buyer/onboarding/active/upsell |
| identity_status | fldhjyRqzM | select | 手動/派生 | P0追加。unresolved/line_only/teachable_only/discord_only/resolved/needs_review |
| activation_status | fldmtcs1AC | select | 手動/派生 | P0追加。not_started/onboarding/activated/stalled/needs_support |
| segment | fldv9lgVO5 | select | L-Step | sts:buyer等 |
| tag_list | fldQSutYzz | select | L-Step | 247タグから選択 |
| entry_source | fldU7f22vc | select | LP/UTM | 流入元 |
| source_ref | fldoVHOG8i | link | - | T5_流入経路マスタへのリンク |
| cv_id | fldBQIw5lz | link | - | T3_CVへのリンク（双方向） |
| backfill_status | fldDXyNCLJ | select | 手動 | 未対応/案内済/再連携完/スキップ |
| 📚 Wikiリンク | fldWg3MgPw | text | 手動 | 参照ドキュメント |
| memo | fldMZmrEJp | text | 手動 | メモ |

### live note

- live 件数: 6,956
- `user_id`, `segment`, `current_stage`, `added_at` は高カバレッジ
- 2026-04-13 に `identity_status`, `activation_status`, `primary_email_normalized`, `teachable_email` を追加
- `identity_status` は P0 backfill 実施済み。`activation_status` は backfill 実施済みだが、新規 `onboarding` レコード流入により継続反映が必要
- `line_uid`, `teachable_id`, `discord_id`, `entry_source`, `backfill_status`, `day1_started_at`, `day3_completed_at`, `day5_completed_at`, `week1_started_at` は 2026-04-13 時点で未入力
- `current_stage` live 値は実質 `lead`, `buyer` の 2 値
- `is_blocked` は 2,164 件入力済み

## T2_ステップ配信（tblSw9XkVFGkvYWQ）

| フィールド名 | フィールドID | 型 | ソース | 備考 |
|------------|------------|---|------|------|
| delivery_id | - | auto_number | 自動 | |
| content_title | - | text | 手動 | 配信タイトル |
| step_name | - | select | 手動 | ステップ名 |
| delivered_at | - | datetime | L-Step | 配信日時 |
| delivered_count | - | number | L-Step | 配信数 |
| opened_count | - | number | L-Step | 開封数 |
| clicked_count | - | number | L-Step | クリック数 |
| replied_count | - | number | L-Step | 返信数 |
| lp_visit_count | - | number | L-Step | LP遷移数 |
| open_rate | - | formula | 自動 | opened/delivered×100 |
| click_rate | - | formula | 自動 | clicked/delivered×100 |
| user_ref | - | link | - | T1_ユーザー管理へのリンク |
| memo | - | text | 手動 | |

### live note

- live 件数: 8
- 現状はステップ別集計テーブルとして使われている
- `user_ref` は 2026-04-13 時点で未接続
- 将来ユーザー単位イベントを追う場合は別テーブル分離を推奨

## T3_CV（tbliH8JqoIWGgt9X）

| フィールド名 | フィールドID | 型 | ソース | 備考 |
|------------|------------|---|------|------|
| **🆔 CV-ID** | **fldNzvXyYi** | **formula** | **自動** | **セマンティックID: CV-YYYYMM-NNN \| 商品名 ¥金額** |
| cv_id | fldpibY6xt | auto_number | 自動 | 連番キー |
| product_name | fldD2lRc02 | text | Teachable | 商品名 |
| amount | fldfi6tM8X | number | Teachable | 金額（円） |
| cv_at | fldMHhyQ07 | datetime | Teachable | 購入日時 |
| teachable_order_id | fldZ3G0YoL | text | Teachable | 注文ID（Webhook照合キー） |
| provider | fldQRWTEqE | select | 手動/自動 | P0追加。teachable/manual/other |
| provider_event_id | fldJYSJ3aX | text | Teachable/外部 | P0追加。外部イベントID |
| product_code | fldPc0IV2r | text | 手動/派生 | P0追加。商品正規化コード |
| cv_type | fldBOFN0mW | select | 手動/自動 | live値: 購入 / 5days購入 / membership購入 / LINE相談 / セミナー申込 / 資料請求 / 返金 |
| cv_source | fldxUwWLX7 | select | UTM/L-Step | live値: STEP1経由 / STEP2経由 / STEP3経由 / STEP4経由 / 自然流入 |
| status | fldLTHZ7vM | select | 手動 | live値: フォロー中 / 成約 / キャンセル |
| identity_match_status | fldBi30Iu2 | select | 手動/派生 | P0追加。matched/unmatched/ambiguous/needs_review |
| days_to_cv | fldmFPKfXV | formula | 自動 | cv_at - T1.added_at |
| user_id_ref | fldx2oF8EI | link | - | T1_ユーザー管理へのリンク |
| source_ref | fldR2pmxNG | link | - | P0追加。T5_流入経路マスタへのリンク |
| assigned_to | fld85jj1C6 | user | 手動 | 担当者 |
| memo | fldR9IR5zM | text | 手動 | |

### live note

- live 件数: 1,101
- 2026-04-13 に `provider`, `provider_event_id`, `product_code`, `identity_match_status`, `source_ref` を追加
- `provider`, `identity_match_status`, `provider_event_id` の P0 backfill は実施済み
- `product_name`, `amount`, `cv_at`, `cv_type`, `status` は高カバレッジ
- `teachable_order_id` は 1,095 件入力
- `cv_source` は 6 件のみ入力
- `user_id_ref` は 2026-04-13 review 時点でほぼ未接続
- `status` 分布は `フォロー中=1,096`, `成約=5`
- 設計上の「CV記録」より、live では注文ログ + フォロー状態管理に近い

## T4_ファネル集計（tblR58a8UANR4nC2）

| フィールド名 | フィールドID | 型 | ソース | 備考 |
|------------|------------|---|------|------|
| **🆔 KPI-ID** | **fldQ5tZxFQ** | **formula** | **自動** | **セマンティックID: KPI-YYYYMM \| 期間種別 CVR%** |
| **連番** | **fldAuNMynP** | **auto_number** | **自動** | 月内連番 |
| period | fldfv7jrVM | datetime | 手動 | 集計期間 |
| period_type | fldHmLBp4N | select | 手動 | 週次/月次 |
| new_friends | fld206lHvf | number | L-Step | 新規友だち数 |
| total_friends | fldTioYrwt | number | L-Step | 累計友だち数 |
| block_count | fld30yeb3K | number | L-Step | ブロック数 |
| ad_spend | fldlHihD2H | number | 手動 | 広告費（円） |
| revenue | fldJCzFGWh | number | Teachable | 売上（円） |
| cv_count | flduVxjhIY | number | Teachable | CV数 |
| step1_open_rate | fld6xMWDEA | number | L-Step | Step1開封率 |
| step2_open_rate | fldo4vXPEf | number | L-Step | Step2開封率 |
| step3_lp_rate | fldesOI1uH | number | L-Step | Step3LP遷移率 |
| **cvr** | fldreeZWk9 | **formula** | 自動 | cv_count/new_friends×100 |
| **block_rate** | fldcJ5fNsK | **formula** | 自動 | block_count/total_friends×100 |
| **cpa** | fldb1kdKaC | **formula** | 自動 | ad_spend/cv_count |
| **roas** | fldy885C5f | **formula** | 自動 | revenue/ad_spend×100 |
| **cpl** | fldOnYZDJU | **formula** | 自動 | ad_spend/new_friends |
| memo | fldelPk8U6 | text | 手動 | |

### live note

- live 件数: 4
- 月次 / 週次 snapshot の暫定運用
- 2026-04-13 に `rolling7d / teachable-only` の正式 snapshot を 1 件追加
- `ad_spend` が null または 0 の行があり、formula 系 KPI は参照時に注意
- `period` と `memo` の年次ズレを含む行あり
- 2026-04-13 に `teachable_* / ga4_* / gsc_* / derived KPI` を追加済み
- 追加 runbook は `03-automation/lark-base/t4-metrics-field-create-runbook-2026-04-13.md`
- `ga4_begin_checkout_count` は現時点で取りづらいため、当面は `ga4_add_to_cart_count` と `ga4_checkout_views` を proxy として扱う

### T4 metrics current truth

| フィールド名 | フィールドID | 型 | ソース | 備考 |
|------------|------------|---|------|------|
| teachable_purchase_count | fldA3XPD0r | number | Teachable 指標API | 期間内購入件数 |
| teachable_gross_revenue | flddjwYaPL | number | Teachable 指標API | 総売上 |
| teachable_refund_count | fldhJxg06F | number | Teachable 指標API | 返金件数 |
| teachable_refund_amount | fldZrKVhAR | number | Teachable 指標API | 返金額 |
| teachable_net_revenue | fldmsaLL8U | number | Teachable 指標API | 純売上 |
| teachable_new_users | fld9BpFms9 | number | Teachable 指標API | 新規購入ユーザー |
| teachable_aov | fldbKmNdD0 | number | Teachable 指標API | 平均注文単価 |
| ga4_users | fldFYvizF7 | number | GA4 | ユーザー数 |
| ga4_sessions | fldNPG71QP | number | GA4 | セッション数 |
| ga4_engaged_sessions | fldmBFfluD | number | GA4 | エンゲージドセッション数 |
| ga4_engagement_rate | fldLfCknQd | number | GA4 | エンゲージメント率 |
| ga4_avg_engagement_time_sec | flde4ZIIuc | number | GA4 | 平均エンゲージメント時間（秒） |
| ga4_product_page_views | flddMvGJFJ | number | GA4 | 商品ページ閲覧数 |
| ga4_checkout_views | fldhpCWo3v | number | GA4 | checkout ページ閲覧数 |
| ga4_begin_checkout_count | fld97WHdes | number | GA4 | 将来値。現状は proxy 運用 |
| ga4_add_to_cart_count | fldtvVsNgb | number | GA4 | checkout proxy |
| ga4_purchase_count | fldcH9nFkx | number | GA4 | purchase 件数 |
| ga4_purchase_revenue | fldkx2Hu1b | number | GA4 | purchase revenue |
| gsc_clicks | fldwkeNohJ | number | Search Console | クリック数 |
| gsc_impressions | fldhihVF7l | number | Search Console | 表示回数 |
| gsc_ctr | fld8CemTAh | number | Search Console | CTR |
| gsc_avg_position | fldsyvlsjy | number | Search Console | 平均掲載順位 |
| gsc_brand_clicks | fldYPYsiob | number | Search Console | 指名検索クリック |
| gsc_nonbrand_clicks | fldpy0Pd2B | number | Search Console | 非指名検索クリック |
| gsc_teachable_page_clicks | fldSiO4oEb | number | Search Console | Teachable ページクリック |
| gsc_teachable_page_impressions | fldkEHGoLx | number | Search Console | Teachable ページ表示回数 |
| product_page_to_cart_rate | fldMz7wA53 | formula | 自動 | `ga4_add_to_cart_count / ga4_product_page_views * 100` |
| cart_to_purchase_rate | fldyQuJLlF | formula | 自動 | `ga4_purchase_count / ga4_add_to_cart_count * 100` |
| search_to_purchase_rate | fld18VOniQ | formula | 自動 | `ga4_purchase_count / gsc_clicks * 100` |
| impression_to_purchase_rate | fldlbO4TOC | formula | 自動 | `ga4_purchase_count / gsc_impressions * 100` |

## T5_流入経路マスタ（tbli5hWHQKH8AQxb）

| フィールド名 | フィールドID | 型 | ソース | 備考 |
|------------|------------|---|------|------|
| ID | fldnK8DauC | auto_number | 自動 | |
| source_name | fldo9KAJge | text | 手動 | 流入元名称 |
| source_type | fld98kM7S9 | select | 手動 | 広告/SNS/紹介/オーガニック/イベント |
| utm_source | - | text | LP | utm_source |
| utm_medium | - | text | LP | utm_medium |
| utm_campaign | - | text | LP | utm_campaign |
| utm_content | fldZ7zDZfP | text | LP | utm_content |
| utm_term | - | text | LP | utm_term |
| is_active | fldjvHhbeo | checkbox | 手動 | 運用中フラグ |
| users | fldp4mMdqM | link | 自動 | T1からの双方向リンク（自動生成） |
| memo | fld5XWAzkc | text | 手動 | |

### live note

- live 件数: 7
- source master (`X（旧Twitter）`, `note`, `YouTube`, `広告`, `Discord`, `紹介`, `Teachableメール`) は存在
- `utm_source`, `utm_medium`, `utm_campaign`, `utm_term`, `utm_content` は 2026-04-13 時点で未入力
- attribution hub としては未接続で、現状は列挙マスタに近い
- Search Console を導入する場合は `organic search` の分析粒度を広げるため、`brand_nonbrand`, `landing_page_pattern`, `gsc_site_segment` のような列追加を検討する

## L-Stepタグフォルダ構造

| フォルダID | フォルダ名 | 主なタグ |
|-----------|---------|--------|
| 未分類 | - | 旧タグ・移行待ち |
| 696686 | Marketing | offer:/risk:/GenStudio等 |
| 696685 | Profile | 職業/レベル/関心/NP等 |
| 696684 | Lifecycle | ライフサイクル管理 |
| 696532 | B2B | b2b:sts/b2b:src/b2b:funnel等 |
| 670029 | Source | src:* 流入元管理 |
| 668982 | Engagement | funnel:/milestone:/course:等 |
