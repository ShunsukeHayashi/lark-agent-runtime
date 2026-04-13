# Miyabi Agent Workflow Index

**Purpose**: 再利用可能なAgent-based workflowの統合カタログ

このインデックスは、Miyabiプロジェクトで定義・検証済みの全てのAgent workflowを管理します。各ワークフローは、複数のAgentが協調して実行する標準化されたプロセスを定義しています。

---

## 📚 ワークフロー一覧

### 1. UI/UX Design Improvement Workflow

**ファイル**: `/Users/a003/dev/miyabi-portal/docs/workflows/UI_UX_DESIGN_IMPROVEMENT_WORKFLOW.md`

**概要**: デザインシステム実装とLighthouse Perfect Score達成のための包括的ワークフロー

**Primary Agent**: JonathanIveDesignAgent
**Supporting Agents**: CoordinatorAgent, CodeGenAgent, ReviewAgent, DeploymentAgent

**フェーズ数**: 19フェーズ
**推定時間**: 7.5時間（実績ベース）

**成功基準**:
- ✅ Lighthouse Performance: 95+ (達成: 100/100)
- ✅ Asset size reduction: 50%+ (達成: 82.5%)
- ✅ Core Web Vitals: All "Good" (達成済み)
- ✅ Design system compliance: 100% (達成済み)

**使用技術**:
- Next.js 14.2.33 + React
- ByteDance Ark API (SeeD Dream 4.0)
- Sharp (WebP conversion)
- Lighthouse CLI
- SVGO (SVG optimization)

**成果物**:
- 41 production-ready assets (33 SVG + 8 WebP)
- 6 updated React components
- Comprehensive documentation (4 files)
- Lighthouse report (100/100/92/100)

**ユースケース**:
- ランディングページのデザインシステム実装
- パフォーマンス最適化（Lighthouse 100達成）
- AI生成画像の品質管理とWebP最適化
- Jonathan Ive minimalist design適用

**実績**:
- 📅 **完了日**: 2025-10-18
- 🎯 **達成率**: 145% (全メトリクス平均)
- 🚀 **ステータス**: PRODUCTION READY

---

## 🚀 ワークフロー使用ガイド

### 基本的な使用方法

1. **ワークフロー選択**: 目的に合ったワークフローを選択
2. **前提条件確認**: 必要なツール・環境をセットアップ
3. **Agent準備**: 各Agent仕様（`.claude/agents/specs/`）を確認
4. **実行**: CoordinatorAgentによるタスク分解とAgent割り当て
5. **検証**: ReviewAgentによる品質チェック
6. **デプロイ**: DeploymentAgentによる本番準備

### ワークフロー実行プロトコル

#### Phase 0: 準備

```bash
# 1. ワークフローファイルを読み込み
cat /path/to/WORKFLOW_NAME.md

# 2. 前提条件を確認
# - Node.js / Rust環境
# - 必要なAPIキー
# - 必要なパッケージ

# 3. Agent仕様を確認
cat .claude/agents/specs/business/jonathan-ive-design-agent.md
cat .claude/agents/specs/coding/coordinator-agent.md
```

#### Phase 1: CoordinatorAgent起動

```typescript
// CoordinatorAgentがワークフローを分析
const workflow = await loadWorkflow('UI_UX_DESIGN_IMPROVEMENT');
const tasks = await coordinator.decomposeWorkflow(workflow);
const dag = coordinator.buildDAG(tasks);
```

#### Phase 2: Agent実行

```typescript
// 各タスクを適切なAgentに割り当て
for (const task of dag.topologicalSort()) {
  const agent = coordinator.assignAgent(task);
  const result = await agent.execute(task);

  // 成功基準を満たすまでリトライ
  if (!result.meetsSuccessCriteria()) {
    await coordinator.escalate(task, result);
  }
}
```

#### Phase 3: 検証とデプロイ

```bash
# ReviewAgentによる最終検証
npm run review:final

# Lighthouse audit実行
lighthouse http://localhost:3000 --output=json --output=html

# DeploymentAgent実行
npm run build
npm run deploy:production
```

---

## 📋 ワークフロー作成ガイドライン

新しいワークフローを作成する場合、以下の構造に従ってください。

### 必須セクション

#### 1. Workflow Overview
- ワークフロータイプ（Multi-Agent, Single-Agent等）
- Primary Agent & Supporting Agents
- 目標と成功基準
- 推定時間

#### 2. Agent Assignments
- 各Agentの役割と責任
- 必要なスキル
- エスカレーション条件

#### 3. Phase Breakdown
- 全フェーズのリスト
- 各フェーズの詳細タスク
- 成功基準
- 期待される出力

#### 4. Agent Coordination Protocol
- Agent間のハンドオフフォーマット
- 並列実行可能なタスク
- 依存関係の定義

#### 5. Technical Details
- 使用ツール・技術スタック
- エラーハンドリング
- ベストプラクティス

#### 6. Success Metrics
- 定量的なKPI
- 品質基準
- パフォーマンス目標

#### 7. Execution Checklist
- 実行前チェックリスト
- 各フェーズのチェックポイント
- 最終検証項目

---

## 🔗 関連ドキュメント

### Agent仕様
- **Coding Agents**: `.claude/agents/specs/coding/`
  - `coordinator-agent.md` - タスク統括・DAG分解
  - `codegen-agent.md` - コード生成
  - `review-agent.md` - 品質レビュー
  - `deployment-agent.md` - デプロイ自動化

- **Business Agents**: `.claude/agents/specs/business/`
  - `jonathan-ive-design-agent.md` - Jonathan Iveデザイン哲学
  - `product-design-agent.md` - プロダクトデザイン
  - その他14個のビジネスAgent

### 実行プロンプト
- `.claude/agents/prompts/coding/` - Agent実行プロンプト（6個）

### テンプレート
- `.claude/templates/reporting-protocol.md` - 報告プロトコル標準形式
- `.claude/prompts/task-management-protocol.md` - タスク管理ルール

### 統合ドキュメント
- `docs/ENTITY_RELATION_MODEL.md` - Entity-Relationモデル定義
- `docs/TEMPLATE_MASTER_INDEX.md` - 88ファイル統合インデックス
- `docs/LABEL_SYSTEM_GUIDE.md` - 53ラベル体系

---

## 📝 ワークフロー追加手順

新しいワークフローをインデックスに追加する場合:

1. **ワークフロー定義ファイル作成**
   ```bash
   # 適切なディレクトリに配置
   touch docs/workflows/NEW_WORKFLOW_NAME.md
   ```

2. **このインデックスに追加**
   - ワークフロー番号を付与（連番）
   - 概要、Agent、フェーズ数、成功基準を記載
   - 相対パスでリンク

3. **Agent仕様の確認**
   - 新しいAgentが必要な場合は `.claude/agents/specs/` に追加
   - 実行プロンプトを `.claude/agents/prompts/` に追加

4. **CLAUDE.mdに参照追加**（オプション）
   - プロジェクト全体のコンテキストとして参照が必要な場合

---

## 🎯 今後追加予定のワークフロー

### Planned Workflows

#### 2. Issue Processing Workflow
**Status**: 🔄 Planning
**Primary Agent**: IssueAgent
**Supporting Agents**: CoordinatorAgent, CodeGenAgent
**Purpose**: GitHub Issue自動分析・ラベリング・タスク分解

#### 3. Code Generation Workflow
**Status**: 🔄 Planning
**Primary Agent**: CodeGenAgent
**Supporting Agents**: ReviewAgent, TestAgent
**Purpose**: Issue/TaskからRustコード生成・テスト作成

#### 4. PR Creation Workflow
**Status**: 🔄 Planning
**Primary Agent**: PRAgent
**Supporting Agents**: ReviewAgent
**Purpose**: Conventional Commits準拠PR自動作成

#### 5. Deployment Workflow
**Status**: 🔄 Planning
**Primary Agent**: DeploymentAgent
**Supporting Agents**: ReviewAgent
**Purpose**: Firebase/Vercel/AWS自動デプロイ・ヘルスチェック

#### 6. SaaS Business Planning Workflow
**Status**: 🔄 Planning
**Primary Agent**: AIEntrepreneurAgent
**Supporting Agents**: MarketResearchAgent, PersonaAgent, ProductConceptAgent
**Purpose**: 包括的ビジネスプラン作成（8フェーズ）

---

## 📊 ワークフロー統計

| ワークフロー | ステータス | Agent数 | フェーズ数 | 推定時間 | 達成率 |
|------------|----------|--------|----------|---------|-------|
| UI/UX Design Improvement | ✅ Complete | 5 | 19 | 7.5h | 145% |
| Issue Processing | 🔄 Planning | 3 | TBD | TBD | - |
| Code Generation | 🔄 Planning | 3 | TBD | TBD | - |
| PR Creation | 🔄 Planning | 2 | TBD | TBD | - |
| Deployment | 🔄 Planning | 2 | TBD | TBD | - |
| SaaS Business Planning | 🔄 Planning | 4 | TBD | TBD | - |

---

## 🤖 Agent キャラクター名対応

Miyabiでは、全21個のAgentに親しみやすい日本語キャラクター名が付けられています。

**ワークフローで使用されるAgent**:

| 技術名 | キャラクター名 | 色分け | 役割 |
|-------|-------------|-------|-----|
| CoordinatorAgent | しきるん | 🔴 リーダー | タスク統括 |
| JonathanIveDesignAgent | アイブさん | 🔵 分析役 | デザイン哲学 |
| CodeGenAgent | つくるん | 🟢 実行役 | コード生成 |
| ReviewAgent | めだまん | 🟢 実行役 | 品質レビュー |
| DeploymentAgent | はこぶん | 🟡 サポート役 | デプロイ |

**詳細**: [AGENT_CHARACTERS.md](AGENT_CHARACTERS.md)

---

**Index Version**: 1.0.0
**Last Updated**: 2025-10-18
**Maintained By**: Claude Code (AI Assistant)

---

**使用方法**:

```bash
# このインデックスを参照
cat .claude/agents/WORKFLOW_INDEX.md

# 特定のワークフローを確認
cat /Users/a003/dev/miyabi-portal/docs/workflows/UI_UX_DESIGN_IMPROVEMENT_WORKFLOW.md

# Agent仕様を確認
cat .claude/agents/specs/business/jonathan-ive-design-agent.md
```
