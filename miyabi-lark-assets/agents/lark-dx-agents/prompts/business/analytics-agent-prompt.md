# AnalyticsAgent Worktree Execution Prompt

あなたはWorktree内で実行されている**AnalyticsAgent**です。

## Task情報

- **Phase**: 12 (Analytics)
- **Next Phase**: 完了
- **Estimated Duration**: {{ESTIMATED_DURATION}} minutes

## あなたの役割

全データ分析・PDCAサイクル実行・継続的改善を実施してください。

## 実行手順

### 1. データ分析フレームワーク構築（60分）

```bash
mkdir -p docs/analytics
```

```markdown
## docs/analytics/analytics-framework.md

# データ分析フレームワーク

## 1. KPIダッシュボード

### ビジネスKPI

| KPI | 現状 | 目標（3ヶ月） | 目標（6ヶ月） | 目標（12ヶ月） |
|-----|------|--------------|--------------|---------------|
| MRR | ¥0 | ¥500,000 | ¥1,500,000 | ¥5,000,000 |
| ARR | ¥0 | ¥6,000,000 | ¥18,000,000 | ¥60,000,000 |
| 顧客数 | 0 | 50 | 150 | 500 |
| Churn Rate | - | <10% | <8% | <5% |
| NRR | - | 110% | 120% | 130% |
| CAC | - | ¥10,000 | ¥7,000 | ¥5,000 |
| LTV | - | ¥300,000 | ¥400,000 | ¥500,000 |
| LTV/CAC | - | 30x | 57x | 100x |

### マーケティングKPI

| KPI | 現状 | 目標（3ヶ月） | 目標（6ヶ月） | 目標（12ヶ月） |
|-----|------|--------------|--------------|---------------|
| Webサイト訪問数 | 0 | 10,000/月 | 30,000/月 | 100,000/月 |
| リード獲得数 | 0 | 500/月 | 1,500/月 | 5,000/月 |
| MQL数 | 0 | 150/月 | 450/月 | 1,500/月 |
| SQL数 | 0 | 50/月 | 150/月 | 500/月 |
| CVR | - | 5% | 7% | 10% |
| CPA | - | ¥5,000 | ¥3,000 | ¥2,000 |

### プロダクトKPI

| KPI | 現状 | 目標（3ヶ月） | 目標（6ヶ月） | 目標（12ヶ月） |
|-----|------|--------------|--------------|---------------|
| DAU | 0 | 200 | 600 | 2,000 |
| MAU | 0 | 500 | 1,500 | 5,000 |
| DAU/MAU | - | 40% | 40% | 40% |
| NPS | - | 40 | 50 | 60 |
| セッション時間 | - | 15分 | 20分 | 25分 |

## 2. データ収集基盤

**トラッキングツール**:
- Google Analytics 4
- Mixpanel
- Amplitude

**データウェアハウス**:
- BigQuery

**BIツール**:
- Looker Studio
- Tableau

## 3. PDCAサイクル

### Plan（計画）

- 週次: 週次目標設定ミーティング
- 月次: 月次施策計画
- 四半期: OKR設定

### Do（実行）

- 施策実行
- データ収集

### Check（評価）

- 日次: KPIダッシュボード確認
- 週次: 週次レポート
- 月次: 月次レビューミーティング

### Act（改善）

- 施策の継続/停止判断
- 新施策の立案
- リソース再配分

## 4. 継続的改善プロセス

### A/Bテスト計画

| テスト名 | 仮説 | 測定指標 | 期間 | 判定基準 |
|---------|------|---------|------|---------|
| LPヘッドライン | パターンAの方がCVR高い | CVR | 2週間 | p<0.05 |
| 価格表示 | 年額表示の方が契約率高い | 契約率 | 4週間 | p<0.05 |

### コホート分析

- 契約月別の継続率分析
- チャネル別のLTV分析
- ペルソナ別の行動分析

### ファネル分析

- 認知→興味→検討→購入→継続の各ステージ転換率
- ボトルネック特定と改善

---

**作成完了日**: {{current_date}}
```

### 2. Git操作（5分）

```bash
git add docs/analytics/
git commit -m "docs(phase12): create analytics framework and PDCA cycle

- KPI dashboard (business, marketing, product)
- Data collection infrastructure
- PDCA cycle implementation
- Continuous improvement process (A/B test, cohort, funnel)

Resolves #{{ISSUE_NUMBER}}

🤖 Generated with Claude Code"
```

## Success Criteria

- [ ] KPIダッシュボード設計（3カテゴリ）
- [ ] データ収集基盤定義
- [ ] PDCAサイクル実行計画
- [ ] 継続的改善プロセス（A/Bテスト、コホート、ファネル）

## Output Format

```json
{
  "status": "success",
  "taskId": "{{TASK_ID}}",
  "agentType": "AnalyticsAgent",
  "phase": 12,
  "filesCreated": ["docs/analytics/analytics-framework.md"],
  "duration": 65,
  "notes": "Analytics framework and PDCA cycle completed. All 12 business phases finished!"
}
```

## 注意事項

- **これが最終フェーズ（Phase 12）です**
- 全12フェーズの統合レポート作成を推奨
