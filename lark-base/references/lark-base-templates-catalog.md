# Lark Base テンプレートカタログ (templates-catalog)

> **このファイルの位置づけ**: 新規 Base 作成依頼を受けたとき、ゼロから `+base-create` する前に **まずこのカタログから類似テンプレートを探す**。該当があれば `+base-copy` でコピー → カスタマイズ、なければ `+base-create` でゼロ作成にフォールバック。

## 1. 運用ルール（最優先 — 先に読む）

ユーザーが「○○ Base を作って」と依頼してきた場合のフロー：

```
1. ユーザー要件をヒアリング（業務 / 規模 / 主要オブジェクト）
2. このカタログから候補テンプレートを 2〜3 件提案
   - 一致するものがある  → 採用候補として提示
   - 一致するものがない  → ゼロから作る方針に倒す
3. ユーザーが採用テンプレートを確定したら:
     lark-cli base +base-copy --base-token <obj_token> --name "<新Base名>"
4. コピー後にカスタマイズ（テーブル追加 / フィールド変更 / 不要レコード削除 / Dashboard / Workflow）
5. 結果 URL を返却 + bot 経由作成時は user に full_access 付与
```

**重要**: カタログを参照せずに即 `+base-create` でゼロ作成すると、ユーザーが既存テンプレで済んだケースで時間を浪費する。**まずカタログ参照** を default にする。

## 2. テナント差分について

このカタログは **`miyabi-g-k.jp.larksuite.com` テナント** のテンプレートセンターから 2026-05-01 に取得した obj_token 80 件。

- URL 形式: `https://miyabi-g-k.jp.larksuite.com/base/{obj_token}`
- 他テナントで運用する場合は、各テナントのテンプレートセンターから obj_token を再取得する必要がある（テンプレ ID はテナント間で互換性なし）
- React Fiber 経由で各テンプレートカードの `obj_token` を抽出する手法で取得（テンプレートセンター API は未公開）

Wiki INDEX: https://miyabi-g-k.jp.larksuite.com/wiki/OGS9wXrpAicMWgku1W7jIUj1pIc

## 3. カテゴリ別カタログ（80件）

### 3.1 おすすめ / 共同作業 (10)

| 名称 | obj_token |
|---|---|
| タスク管理 (リマインダー) | basjp3sNPafQyeDGAIcbn4SVPkU |
| タスク管理 | basjpe81if97I7ChNiONWHTA6wh |
| 新人タスク看板 | basjpSejSg5CfSVp4TmTIt4mMTc |
| 優先度看板 | basjppKRW52tvg1G3LbJLL5ynah |
| 業務引き継ぎ表 | basjp2G7ofDRiMRDEIWjkXny6Sh |
| 出席状況リアルタイム看板 | TnpHbOLyUadgzXsYhNejglHqpOF |
| 予実管理システム | BcMhbnkxQaxED9spuGUjPLTQpih |
| 飲食業界向け Base1つで会社管理 (A) | Ij6fbtAAua8fxqsFABDjIlGopSe |
| 📈 業務管理コンソール | LjwWbH0bUaDwswsAchOjs9Nfpbb |
| AI 経営分析管理 | GRwtbTAnUattyLsoyaRjBN7tpBf |

### 3.2 業務マスタ / プロジェクト管理 (8)

| 名称 | obj_token |
|---|---|
| 経営分析 | PHqCbixzHaPKy0svqdCj4jX4pRb |
| 飲食業界向け Base1つで会社管理 (B) | GuBebUxOfamo1MsE2XijZnpppvf |
| 简易 CRM | WIqWbyjSyaqxTEs4uWZjDO2Fp8e |
| タスク管理(別) | basjpQ8r7zuaeQNCX7VS5KetPBg |
| 経営分析（ダッシュボード付き） | GmR2bc14xa80ZssdbHwj2LnXpLc |
| タスク管理(別2) | basjpq151RPhrbYZOBTlei5rQDd |
| デザインプロジェクト管理 | basjpexA14SBeUsgORoGwk14Qvb |
| タスクの割り当て | basjpn1fDwpGb9ClJ98DTP96X0b |

### 3.3 社内文書・議事録 (2)

| 名称 | obj_token |
|---|---|
| 会議クオリティマネジメント | basjptBWIDATErwcCRV2rXcFOzg |
| 要求データ管理 | basjpVsmlNeca8PI88NNPY0vhOf |

### 3.4 営業・セールス (11)

| 名称 | obj_token |
|---|---|
| 顧客関係管理 (A) | basjpbgpfCD7kJ1M9uWVpGoMwrh |
| 在庫管理 | basjpvNmCrPsejBeLSlEAnb3nXd |
| 💰営業管理システム | Mx9Yb5VI2aBdaxsNGW4jTQdRp2d |
| 顧客管理 | QIzPbCHh3avgfRsF847jvFxtpEh |
| 顧客関係管理 (B) | basjpdFtqXHxzG2bSt0blJv0EOd |
| 顧客使用記録 | basjpj6F73vIzuZtqhEZGWDI1ug |
| サプライチェーン管理 | basjp7Wo0QNbo8UcAM0dcvbefYb |
| 販売管理ダッシュボード | TjLqbY4xJau38EsrGOFjUeJhphd |
| オフライン店舗顧客フィードバック・改善サイクル管理 | ZiGObrTSya4arqs5Nymjrc5xpfc |
| 小売ERP管理システム（双方向関連機能） | ZwZpbCNCga1Ww5shUIqjvu3IpGf |
| 店舗管理（グループチャット） | TOTQbUF9AaHjlesF4OtjmTVMpEc |

### 3.5 コンテンツ制作 (5)

| 名称 | obj_token |
|---|---|
| スケジュールカレンダー | basjpR6qQNVvzHjbKb56htzithh |
| コンテンツ配信スケジュール | basjps35y20XLkGuoSUZwWVQVnb |
| デザインプロジェクト管理(別) | basjpuYDdBqLc4V5vTKtQPoNeGe |
| 宣伝資料管理 | basjpEJtw3oyYMqJMYqE8f1aCVf |
| 動画カット割り管理 (A) | basjprgmE3ssLJCLKJpmdlOOYQc |

### 3.6 マーケティング (8)

| 名称 | obj_token |
|---|---|
| お知らせ送信スケジュール | basjpqnqAkHSWiAptAYkV15Gtce |
| 動画カット割り管理 (B) | basjp4XDXqlNlTWOt8BBtbtpKgh |
| イベントマーケティング | basjpY4EiJwsppgZs95YdC8EeSe |
| 通年営業企画 | basjpxr73rbgF0GWnN3pW5gpxOc |
| イベント管理 | basjpzg7IzzXtN3gVNH3Q0xH0vg |
| メディア関係管理 | basjpcE6oyEcEv4xISeEjAqH3Ne |
| ゲストスケジュール | basjpaQMFKeIZUTs1UZAKDhXJRn |
| アナウンサーシフト | basjpz8dFmrQ44C51Tmumq0JKme |

### 3.7 日常業務 (9)

| 名称 | obj_token |
|---|---|
| ファイルデータベース | basjpKumypZ4fE0nHc39wZikhNe |
| スケジュール管理 | basjpOromjCXInkNVAfQnlhQNxc |
| ファイル共有スペース | basjp5A4QKiQwtbeTlakrrwA4Ec |
| 従業員データ登録表 | basjpJy9Nqo0RKaLT9YUAAzsRye |
| 部署別社員連絡帳 | YKZkbIQeWaKfnSs7A20jtnMrpSd |
| 📋To Doリスト | Cpprb80SwaUXSUsDU4ojhpf5pld |
| 会員管理 | basjpcjii9VUX6PiHLKWjcCoB4b |
| 📂契約満了リマインダー | RGxpbOpdeaOmrFsd5RljOEYcpHc |
| 自動レビュー分析 | DSEtbW88vaUJHfsCNV5jvExnp5e |

### 3.8 製品 (4)

| 名称 | obj_token |
|---|---|
| ユーザー調査 | basjplbvSuguohL50CoDrZGz8if |
| バグ管理表 | basjpQ5VvuYbjIBcrfz6aoEzQ9e |
| Bug フォローバック記録 | basjpKDKD6frlCTU085c58E5K0e |
| ユーザーフィードバック表 | basjpIdtn5tsU198y6oT0QWtVee |

### 3.9 人事 (12)

| 名称 | obj_token |
|---|---|
| 社員情報管理表 | basjpBMNdq8ZGBOj4NUoQZRtnmb |
| シフト管理 | QO5ybfPcGafP9rsqDU2jYq76p3d |
| シフト・勤怠管理・自動給与計算 | UWBhbsJHIaEX3ZsiB0ljiC4Spab |
| 📠 採用進捗管理 | basjp462OMCeBPxWcheQexWXGvd |
| 新卒社員リスト | basjp6O1iyBClWQHpbbhgPBSxfb |
| 領収書管理 | basjpom8kR42N4WWS12hPGIcHeb |
| イベントスケジュール | basjpl3fjGXF4yOW7JhSNcksGsg |
| 備品点検チェックリスト | basjpyzl8GmYShKxysviGDckBof |
| 休暇統計 (A) | basjpX5DSjqiyWwgtEjM4VDnq4e |
| 備品検査リスト | basjpQDvpqbNVqAWQcHK4uByRoh |
| 休暇統計 (B) | basjpbNfH7rBEQa4v4JziW9NqGd |
| 精算承認システム | LKz8bZyp8a9Cp6s8fbnj8BWep9d |

### 3.10 パーソナル (6)

| 名称 | obj_token |
|---|---|
| 自己成長データベース | basjpGZEDUgZna9iPMcHUbKk34c |
| チーム学習共有記録 | basjpmUZ4rSWmssLutl7LK8yd9e |
| 個人学習・成長管理 | basjptQEe5b9YPccWSBlCQgSrDc |
| 学生の成績管理 | basjpHxj4chNWMuAFu3g0R51n3X |
| 学生用時間割表 | basjp1gTOMn2Id0hYe9c9TDgrwE |
| 先生用時間割表 | basjpRdpOuJRv1OnsO1q6mQnJYd |

### 3.11 生活・娯楽 (5)

| 名称 | obj_token |
|---|---|
| クラス連絡表 | basjpSjIKuR7kGftZ8hmq9VES5c |
| 個人用計画表 | basjpV5I7zXk7eoQU5mzDYMbZZg |
| 旅行計画 | basjpurtBCQjeH9Mf9BYERj4F9d |
| 習慣育成打刻 | basjpyvzkYxCzCjZl9JB4Lqa34f |
| 同僚のコーヒー好み | basjpPWujeTUGBKQGPbNf6HTAUd |

## 4. 用途別ホットリスト（高頻度想定）

ユーザー依頼パターン別に、まず提案すべきテンプレート：

| 依頼パターン | 第一候補 | 第二候補 | 第三候補 |
|---|---|---|---|
| **CRM / 営業管理** | 简易 CRM `WIqWbyjSyaqxTEs4uWZjDO2Fp8e` | 💰営業管理システム `Mx9Yb5VI2aBdaxsNGW4jTQdRp2d` | 顧客関係管理(A) `basjpbgpfCD7kJ1M9uWVpGoMwrh` |
| **タスク管理** | タスク管理 (リマインダー) `basjp3sNPafQyeDGAIcbn4SVPkU` | 優先度看板 `basjppKRW52tvg1G3LbJLL5ynah` | 📋To Doリスト `Cpprb80SwaUXSUsDU4ojhpf5pld` |
| **PJ管理** | デザインプロジェクト管理 `basjpexA14SBeUsgORoGwk14Qvb` | タスクの割り当て `basjpn1fDwpGb9ClJ98DTP96X0b` | — |
| **人事 / 勤怠** | 社員情報管理表 `basjpBMNdq8ZGBOj4NUoQZRtnmb` | シフト・勤怠・自動給与 `UWBhbsJHIaEX3ZsiB0ljiC4Spab` | 採用進捗管理 `basjp462OMCeBPxWcheQexWXGvd` |
| **会計 / 経理** | 領収書管理 `basjpom8kR42N4WWS12hPGIcHeb` | 精算承認システム `LKz8bZyp8a9Cp6s8fbnj8BWep9d` | 予実管理システム `BcMhbnkxQaxED9spuGUjPLTQpih` |
| **経営ダッシュボード** | AI 経営分析管理 `GRwtbTAnUattyLsoyaRjBN7tpBf` | 経営分析（ダッシュボード付き） `GmR2bc14xa80ZssdbHwj2LnXpLc` | 📈 業務管理コンソール `LjwWbH0bUaDwswsAchOjs9Nfpbb` |
| **議事録 / MTG** | 会議クオリティマネジメント `basjptBWIDATErwcCRV2rXcFOzg` | — | — |
| **業界特化（飲食 / 小売）** | 飲食業界向け Base1つ `Ij6fbtAAua8fxqsFABDjIlGopSe` | 小売ERP管理システム `ZwZpbCNCga1Ww5shUIqjvu3IpGf` | 店舗管理（グループチャット） `TOTQbUF9AaHjlesF4OtjmTVMpEc` |
| **マーケ / イベント** | イベントマーケティング `basjpY4EiJwsppgZs95YdC8EeSe` | 通年営業企画 `basjpxr73rbgF0GWnN3pW5gpxOc` | メディア関係管理 `basjpcE6oyEcEv4xISeEjAqH3Ne` |
| **コンテンツ制作** | コンテンツ配信スケジュール `basjps35y20XLkGuoSUZwWVQVnb` | 動画カット割り管理 `basjprgmE3ssLJCLKJpmdlOOYQc` | 宣伝資料管理 `basjpEJtw3oyYMqJMYqE8f1aCVf` |

## 5. ベース作成時の標準ワークフロー

```bash
# Step 1: テンプレ採用が決まったら
lark-cli base +base-copy \
  --base-token <obj_token from this catalog> \
  --name "<新Base名>" \
  --time-zone Asia/Tokyo

# Step 2: 元テンプレに不要レコードがあれば削除（多くのテンプレはサンプルデータ入り）
lark-cli base +record-list --base-token <new_base_token> --table-id <tbl_id> --limit 200
lark-cli base +record-delete --base-token <new_base_token> --table-id <tbl_id> --record-id <rec_id> --yes

# Step 3: 必要に応じてテーブル / フィールド / Dashboard / Workflow をカスタマイズ
# (lark-base-table-create.md / field-create / dashboard / workflow を参照)

# Step 4: bot 経由作成時は user に full_access 付与（lark-base-base-copy.md の IMPORTANT 参照）
```

## 6. 同名テンプレートの取り扱い

複数同名テンプレ（例: 「タスク管理」が3つ）はそれぞれ別 `obj_token` で別構成。提案時は構成の差を簡単に説明し、ユーザーに用途で選んでもらう。

| 同名グループ | obj_tokens |
|---|---|
| タスク管理 | `basjp3sNPafQyeDGAIcbn4SVPkU` (リマインダー版) / `basjpe81if97I7ChNiONWHTA6wh` / `basjpQ8r7zuaeQNCX7VS5KetPBg` (別) / `basjpq151RPhrbYZOBTlei5rQDd` (別2) |
| 顧客関係管理 | `basjpbgpfCD7kJ1M9uWVpGoMwrh` (A) / `basjpdFtqXHxzG2bSt0blJv0EOd` (B) |
| 動画カット割り管理 | `basjprgmE3ssLJCLKJpmdlOOYQc` (A) / `basjp4XDXqlNlTWOt8BBtbtpKgh` (B) |
| 休暇統計 | `basjpX5DSjqiyWwgtEjM4VDnq4e` (A) / `basjpbNfH7rBEQa4v4JziW9NqGd` (B) |
| 飲食業界向け Base1つで会社管理 | `Ij6fbtAAua8fxqsFABDjIlGopSe` (A) / `GuBebUxOfamo1MsE2XijZnpppvf` (B) |
| デザインプロジェクト管理 | `basjpexA14SBeUsgORoGwk14Qvb` / `basjpuYDdBqLc4V5vTKtQPoNeGe` (別) |

## 7. メンテナンス

- カタログは 2026-05-01 取得時点のスナップショット
- テンプレートセンターは Lark 側で更新される可能性あり。半年〜1年ごとに再取得推奨
- 「マイテンプレート」「自分への共有」は 2026-05-01 時点で 0 件（取得対象外）

## 参考

- [`lark-base-base-create.md`](lark-base-base-create.md) — 新規 Base 作成（ゼロから / カタログに該当なしの場合）
- [`lark-base-base-copy.md`](lark-base-base-copy.md) — Base コピー（カタログから採用時）
- [`lark-base-workspace.md`](lark-base-workspace.md) — Base モジュール索引
