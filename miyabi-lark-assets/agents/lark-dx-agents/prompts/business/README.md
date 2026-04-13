# Business Agent Execution Prompts

ビジネス・経営戦略系AgentのWorktree実行プロンプトディレクトリです。

## 概要

このディレクトリには、**Git Worktree内でClaude Codeが実行する際の具体的な手順書**を格納します。

## ステータス

🚧 **将来追加予定** 🚧

現在、ビジネス系Agentの実行プロンプトは作成中です。
以下のプロンプトファイルを順次追加していきます。

## 計画中のプロンプトファイル（14個）

### 戦略・企画系プロンプト (6個)

#### 1. ai-entrepreneur-agent-prompt.md
**AIEntrepreneurAgent実行プロンプト**

- **対応Agent**: AIEntrepreneurAgent
- **内容**（予定）:
  - 8フェーズのビジネスプラン作成手順
  - 市場分析 → 競合分析 → 顧客分析
  - 価値提案 → 収益モデル → マーケティング戦略
  - チーム編成 → 資金調達計画
  - 統合レポート生成
- **変数**:
  - `{{BUSINESS_IDEA}}` - ビジネスアイデア
  - `{{TARGET_MARKET}}` - 対象市場
  - `{{KEYWORDS}}` - キーワードリスト

#### 2. product-concept-agent-prompt.md
**ProductConceptAgent実行プロンプト**

- **内容**（予定）:
  - MVP設計手順
  - Lean Canvas作成
  - Jobs To Be Done分析
  - プロダクトロードマップ生成

#### 3. product-design-agent-prompt.md
**ProductDesignAgent実行プロンプト**

- **内容**（予定）:
  - UI/UX設計手順
  - Figmaプロトタイプ作成
  - デザインシステム構築
  - アクセシビリティチェック

#### 4. funnel-design-agent-prompt.md
**FunnelDesignAgent実行プロンプト**

- **内容**（予定）:
  - カスタマージャーニーマップ作成
  - コンバージョンファネル設計
  - AARRR Metrics設定
  - Growth Hacking施策立案

#### 5. persona-agent-prompt.md
**PersonaAgent実行プロンプト**

- **内容**（予定）:
  - ペルソナテンプレート作成
  - ユーザーインタビュー分析
  - セグメンテーション
  - ペルソナカード生成

#### 6. self-analysis-agent-prompt.md
**SelfAnalysisAgent実行プロンプト**

- **内容**（予定）:
  - SWOT分析実行
  - ストレングスファインダー
  - キャリアプランニング
  - 目標設定（SMART）

### マーケティング系プロンプト (5個)

#### 7. market-research-agent-prompt.md
**MarketResearchAgent実行プロンプト**

- **内容**（予定）:
  - 市場トレンド分析
  - 競合調査（Web Scraping）
  - 市場規模推定
  - トレンド予測レポート

#### 8. marketing-agent-prompt.md
**MarketingAgent実行プロンプト**

- **内容**（予定）:
  - マーケティング施策立案
  - KPI設定（SMART）
  - チャネル選定
  - 予算配分計画

#### 9. content-creation-agent-prompt.md
**ContentCreationAgent実行プロンプト**

- **内容**（予定）:
  - ブログ記事生成（SEO最適化）
  - SNS投稿作成
  - プレスリリース作成
  - ストーリーテリング

#### 10. sns-strategy-agent-prompt.md
**SNSStrategyAgent実行プロンプト**

- **内容**（予定）:
  - SNS投稿カレンダー作成
  - エンゲージメント分析
  - ハッシュタグ最適化
  - インフルエンサー連携

#### 11. youtube-agent-prompt.md
**YouTubeAgent実行プロンプト**

- **内容**（予定）:
  - 動画企画書作成
  - 台本生成
  - サムネイル最適化
  - SEO最適化（タイトル・説明文）

### 営業・顧客管理系プロンプト (3個)

#### 12. sales-agent-prompt.md
**SalesAgent実行プロンプト**

- **内容**（予定）:
  - 営業戦略立案
  - SPIN Selling フレームワーク
  - リード管理
  - 成約率向上施策

#### 13. crm-agent-prompt.md
**CRMAgent実行プロンプト**

- **内容**（予定）:
  - 顧客データ分析
  - セグメンテーション
  - LTV最大化施策
  - リテンション施策立案

#### 14. analytics-agent-prompt.md
**AnalyticsAgent実行プロンプト**

- **内容**（予定）:
  - データ分析手順
  - レポート生成
  - データビジュアライゼーション
  - 意思決定支援

## プロンプト構造（標準テンプレート）

ビジネス系Agentプロンプトは以下の構造を想定しています：

```markdown
# [AgentName] Worktree Execution Prompt

あなたはWorktree内で実行されている**[AgentName]**です。

## Business Context
- **Business Idea**: {{BUSINESS_IDEA}}
- **Target Market**: {{TARGET_MARKET}}
- **Phase**: {{PHASE}}

## 実行手順

### 1. 市場調査（推定時間）
...

### 2. データ分析（推定時間）
...

### 3. レポート生成（推定時間）
...

## 実装例
具体的な分析手法・テンプレート例...

## Success Criteria
✅ 完了条件のチェックリスト

## Output Format
```json
{
  "agentType": "...",
  "phase": "...",
  "result": {
    "report": "...",
    "recommendations": [...]
  }
}
```
```

## 開発ロードマップ

### Phase 1: 戦略・企画系（優先度: 高）
- [ ] ai-entrepreneur-agent-prompt.md
- [ ] product-concept-agent-prompt.md
- [ ] persona-agent-prompt.md

### Phase 2: マーケティング系（優先度: 中）
- [ ] market-research-agent-prompt.md
- [ ] marketing-agent-prompt.md
- [ ] content-creation-agent-prompt.md

### Phase 3: 営業・顧客管理系（優先度: 中）
- [ ] sales-agent-prompt.md
- [ ] crm-agent-prompt.md
- [ ] analytics-agent-prompt.md

### Phase 4: その他（優先度: 低）
- [ ] product-design-agent-prompt.md
- [ ] funnel-design-agent-prompt.md
- [ ] sns-strategy-agent-prompt.md
- [ ] youtube-agent-prompt.md
- [ ] self-analysis-agent-prompt.md

## 貢献方法

ビジネス系Agentプロンプトの作成に協力いただける場合は、以下の手順で進めてください：

1. **既存のコーディング系プロンプトを参考にする**
   - [../coding/README.md](../coding/README.md)

2. **テンプレートを使用する**
   ```bash
   cp ../coding/codegen-agent-prompt.md ./your-agent-prompt.md
   ```

3. **ビジネスコンテキストを追加する**
   - 市場分析手法
   - ビジネスフレームワーク（SWOT、Lean Canvas等）
   - レポートフォーマット

4. **変数を定義する**
   - `{{BUSINESS_IDEA}}`
   - `{{TARGET_MARKET}}`
   - `{{PHASE}}`

## 関連ドキュメント

- **Agent仕様**: [../../specs/business/](../../specs/business/)
- **ビジネスモデル**: [../../../../docs/SAAS_BUSINESS_MODEL.md](../../../../docs/SAAS_BUSINESS_MODEL.md)
- **市場分析**: [../../../../docs/MARKET_ANALYSIS_2025.md](../../../../docs/MARKET_ANALYSIS_2025.md)

---

🚧 Business Agent Execution Prompts - In Development
