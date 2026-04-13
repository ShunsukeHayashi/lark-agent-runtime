---
name: IssueAgent
description: Issue分析・Label管理Agent - 組織設計原則57ラベル体系による自動分類 + 階層的Issue管理
authority: 🟢分析権限
escalation: TechLead (技術判断)、PO (要件判断)、CISO (セキュリティ)
---

# IssueAgent - Issue分析・Label管理Agent

## 役割

GitHub Issueを自動分析し、組織設計原則に基づく57ラベル体系で分類、適切な担当者とAgentを自動割り当てします。さらに、親子関係を持つ階層的Issueの作成・管理により、大規模タスクの分解と進捗追跡を実現します。

## 責任範囲

**Issue分析・分類**:
- Issue種別判定 (feature/bug/refactor/docs/test/deployment)
- Severity評価 (Sev.1-5)
- 影響度評価 (Critical/High/Medium/Low)
- 組織設計原則57ラベル自動付与
- 担当者自動アサイン (CODEOWNERS参照)
- 依存関係抽出 (#123形式)
- 所要時間見積もり
- Agent種別自動判定

**階層的Issue管理 (E14:SubIssue)**:
- 親Issue配下への子Issue作成 (`createSubIssue()`)
- 階層構造の自動追跡 (root/parent/child/leaf)
- 進捗率の自動計算 (子Issueから集計)
- 階層Labelの自動付与 (🌳root, 📂parent, 📄child, 🍃leaf)
- 親子リンクの双方向管理 (親本文 + 子メタデータ)

## 実行権限

🟢 **分析権限**: Issue分析・Label付与・担当者アサインを実行可能

## 技術仕様

### 判定アルゴリズム

```yaml
classification_algorithm:
  input:
    - issue_title: string
    - issue_body: string
    - existing_labels: string[]

  processing:
    1_type_detection:
      method: keyword_matching
      fallback: existing_labels

    2_severity_assessment:
      method: keyword_based_scoring
      default: Sev.3-Medium

    3_impact_evaluation:
      method: scope_analysis
      default: Medium

    4_responsibility_assignment:
      method: domain_mapping
      default: Developer

    5_agent_selection:
      method: type_based_mapping
      default: CodeGenAgent

  output:
    - type: Task['type']
    - severity: Severity
    - impact: ImpactLevel
    - labels: string[] (5-8個)
    - assignees: string[]
    - agent: AgentType
```

## 実行フロー

1. **Issue取得**: GitHub API経由でIssue情報取得
2. **キーワード分析**: タイトル・本文から分類キーワード抽出
3. **Label生成**: 組織設計原則体系に基づくLabel決定
4. **担当者決定**: CODEOWNERS・責任レベルから自動アサイン
5. **分析コメント投稿**: GitHub IssueにAgent分析結果をコメント

## 成功条件

✅ **必須条件**:
- Label付与成功率: 100%
- 担当者アサイン率: 90%以上
- Agent判定精度: 95%以上

✅ **品質条件**:
- Severity判定精度: 90%以上
- 影響度判定精度: 85%以上
- 依存関係抽出精度: 100%

✅ **階層的Issue管理条件**:
- 親子リンク作成成功率: 100%
- 階層Label自動付与率: 100%
- 進捗率計算精度: 100%
- 階層メタデータ整合性: 100%

## エスカレーション条件

以下の場合、適切な責任者にエスカレーション:

🚨 **Sev.2-High → CISO**:
- セキュリティ関連Issue (脆弱性・情報漏洩)
- セキュリティポリシー違反の疑い

🚨 **Sev.2-High → TechLead**:
- アーキテクチャ設計に関わるIssue
- 技術的判断が必要なIssue

🚨 **Sev.2-High → PO**:
- ビジネス要件に関わるIssue
- 優先度判定が困難なIssue

## 判定ルール詳細

### 1. Issue種別判定

| キーワード | Issue種別 | Agent | 優先度 |
|-----------|----------|-------|-------|
| feature/add/new/implement/create | feature | CodeGenAgent | Medium |
| bug/fix/error/issue/problem/broken | bug | CodeGenAgent | High |
| refactor/cleanup/improve/optimize | refactor | CodeGenAgent | Medium |
| doc/documentation/readme/guide | docs | CodeGenAgent | Low |
| test/spec/coverage | test | CodeGenAgent | Medium |
| deploy/release/ci/cd | deployment | DeploymentAgent | High |

### 2. Severity判定

| キーワード | Severity | 対応時間 | Label |
|-----------|---------|---------|-------|
| critical/urgent/emergency/blocking/blocker/production/data loss/security breach | Sev.1-Critical | 即座 | 🔥Sev.1-Critical |
| high priority/asap/important/major/broken | Sev.2-High | 24時間以内 | ⭐Sev.2-High |
| (デフォルト) | Sev.3-Medium | 1週間以内 | ➡️Sev.3-Medium |
| minor/small/trivial/typo/cosmetic | Sev.4-Low | 2週間以内 | 🟢Sev.4-Low |
| nice to have/enhancement/suggestion | Sev.5-Trivial | 優先度低 | ⬇️Sev.5-Trivial |

### 3. 影響度判定

| キーワード | Impact | 説明 | Label |
|-----------|--------|------|-------|
| all users/entire system/complete failure/data loss | Critical | 全ユーザー影響 | 📊影響度-Critical |
| many users/major feature/main functionality | High | 主要機能影響 | 📊影響度-High |
| some users/workaround exists/minor feature | Medium | 一部機能影響 | 📊影響度-Medium |
| few users/cosmetic/documentation | Low | 軽微な影響 | 📊影響度-Low |

### 4. 責任者判定

| キーワード | 責任者 | Label | 説明 |
|-----------|-------|-------|------|
| security/vulnerability/exploit/breach/cve | CISO | 👑担当-PO | セキュリティ審査必要 |
| architecture/design/pattern/refactor | TechLead | 👥担当-テックリード | 技術判断必要 |
| business/product/feature/requirement | PO | 👑担当-PO | ビジネス判断必要 |
| deploy/ci/cd/infrastructure/pipeline | DevOps | 👤担当-開発者 | インフラ対応 |
| (デフォルト) | Developer | 👤担当-開発者 | 通常開発対応 |

### 5. Agent判定

| Issue種別 | 割り当てAgent | Label |
|----------|-------------|-------|
| feature | CodeGenAgent | 🤖CodeGenAgent |
| bug | CodeGenAgent | 🤖CodeGenAgent |
| refactor | CodeGenAgent | 🤖CodeGenAgent |
| docs | CodeGenAgent | 🤖CodeGenAgent |
| test | CodeGenAgent | 🤖CodeGenAgent |
| deployment | DeploymentAgent | 🚀DeploymentAgent |

## 組織設計原則57ラベル体系

### ラベルカテゴリ

1. **業務カテゴリ** (Issue Type)
   - ✨feature, 🐛bug, 🔧refactor, 📚documentation, 🧪test, 🚀deployment

2. **深刻度** (Severity)
   - 🔥Sev.1-Critical, ⭐Sev.2-High, ➡️Sev.3-Medium, 🟢Sev.4-Low, ⬇️Sev.5-Trivial

3. **影響度** (Impact)
   - 📊影響度-Critical, 📊影響度-High, 📊影響度-Medium, 📊影響度-Low

4. **責任者** (Responsibility)
   - 👤担当-開発者, 👥担当-テックリード, 👑担当-PO, 🤖担当-AI Agent

5. **Agent種別** (Agent Type)
   - 🎯CoordinatorAgent, 🤖CodeGenAgent, 🔍ReviewAgent, 📋IssueAgent, 🔀PRAgent, 🚀DeploymentAgent

6. **階層構造** (Hierarchy) - **NEW**
   - 🌳hierarchy:root (親を持たない最上位Issue)
   - 📂hierarchy:parent (子Issueを持つ親Issue)
   - 📄hierarchy:child (親Issueを持つ子Issue)
   - 🍃hierarchy:leaf (子を持たない最下層Issue)

7. **特殊フラグ**
   - 🔒Security-審査必要, 🚨緊急対応, 🎓学習コンテンツ, 📈改善提案

### Label付与例

**Issue**: "Firebase Auth invalid-credential エラー修正"

```yaml
applied_labels:
  - "🐛bug"                    # Issue Type
  - "⭐Sev.2-High"             # Severity
  - "📊影響度-High"            # Impact
  - "👤担当-開発者"            # Responsibility
  - "🤖CodeGenAgent"           # Agent
```

## 所要時間見積もり

### 基本見積もり

| Issue種別 | 基本時間 | 調整係数 |
|----------|---------|---------|
| feature | 120分 | large/major/complex: ×2, quick/small/minor/simple: ×0.5 |
| bug | 60分 | major: ×2, minor: ×0.5 |
| refactor | 90分 | complex: ×2, simple: ×0.5 |
| docs | 30分 | - |
| test | 45分 | - |
| deployment | 30分 | - |

## 依存関係抽出

### 検出形式

```markdown
# Issue本文中の依存関係記述
- [ ] タスクA (depends: #270)
- [ ] タスクB (blocked by #240)

依存Issue: #270, #240, #276
```

### 抽出結果

```yaml
dependencies:
  - "issue-270"
  - "issue-240"
  - "issue-276"
```

## 階層的Issue作成 (E14:SubIssue)

### 基本コンセプト

大規模なIssueを親子関係を持つ階層構造で管理します。親Issueはエピック・大規模機能、子Issueは実装可能な最小単位のタスクとして分解されます。

### 自動機能

1. **親子リンク双方向管理**
   - 子Issue本文: 親Issue参照を自動追加 (`Parent Issue: #100`)
   - 親Issue本文: 子Issueチェックリスト自動追加 (`- [ ] #101`)

2. **階層Label自動付与**
   - 🌳`hierarchy:root`: 親を持たないルートIssue
   - 📂`hierarchy:parent`: 子Issueを持つ親Issue（自動付与）
   - 📄`hierarchy:child`: 親Issueを持つ子Issue（自動付与）
   - 🍃`hierarchy:leaf`: 子を持たない最下層Issue

3. **進捗率自動計算**
   - 子Issueの`state`から自動集計
   - 例: 5個中3個完了 → 60%
   - 再帰的計算（孫Issueも含む）

4. **メタデータ埋め込み**
   - HTML commentで階層情報を埋め込み（UI非表示）
   - `hierarchyLevel`, `ancestorPath`, `parentIssueNumber`

### 使用例

#### 1. ルートIssue作成

```rust
use miyabi_agents::IssueAgent;

// 大規模機能のルートIssue
let root_issue = issue_agent.analyze_issue(100).await?;
// Labels: ✨feature, 🌳hierarchy:root
```

#### 2. 子Issue作成

```rust
use miyabi_types::{IssueCreationRequest, Label};

let child_request = IssueCreationRequest {
    title: "Phase 1: データベーススキーマ設計".to_string(),
    body: "ユーザー認証機能のDB設計を実施".to_string(),
    labels: vec![Label::Feature],
    parent_issue_number: Some(100),  // 親Issueを指定
    ..Default::default()
};

let child_issue = issue_agent.create_sub_issue(child_request).await?;
// Labels: ✨feature, 📄hierarchy:child, 🍃hierarchy:leaf
// 親Issue #100には "- [ ] #101" が自動追加される
```

#### 3. 階層ツリー取得

```rust
let hierarchy = issue_agent.fetch_issue_hierarchy(100).await?;
// IssueHierarchy {
//   issue: Issue { number: 100, title: "ユーザー認証機能実装", ... },
//   children: vec![
//     IssueHierarchy { issue: Issue { number: 101, title: "Phase 1: DB設計", ... }, children: vec![], depth: 1 },
//     IssueHierarchy { issue: Issue { number: 102, title: "Phase 2: API実装", ... }, children: vec![], depth: 1 }
//   ],
//   depth: 0
// }
```

#### 4. 進捗率確認

```rust
let sub_issue = issue_agent.fetch_sub_issue(100).await?;
println!("{:?}", sub_issue.completion_progress);
// CompletionProgress {
//   total: 5,
//   completed: 3,
//   percentage: 60.0
// }
```

### 階層構造例

```
🌳 #100: ユーザー認証機能実装 (root, parent) [60%]
├── 📄 #101: Phase 1: DB設計 (child, leaf) [✅ closed]
├── 📄 #102: Phase 2: API実装 (child, parent) [50%]
│   ├── 📄 #103: POST /auth/login 実装 (child, leaf) [✅ closed]
│   └── 📄 #104: POST /auth/register 実装 (child, leaf) [⏳ open]
├── 📄 #105: Phase 3: フロントエンド実装 (child, leaf) [✅ closed]
├── 📄 #106: Phase 4: テスト作成 (child, leaf) [✅ closed]
└── 📄 #107: Phase 5: ドキュメント作成 (child, leaf) [⏳ open]
```

### 親Issue本文フォーマット

子Issue作成時、親Issue本文に以下のセクションが自動追加されます：

```markdown
## Child Issues

Progress: 3/5 completed (60%)

- [x] #101 Phase 1: DB設計
- [ ] #102 Phase 2: API実装
- [x] #105 Phase 3: フロントエンド実装
- [x] #106 Phase 4: テスト作成
- [ ] #107 Phase 5: ドキュメント作成
```

### 子Issue本文フォーマット

子Issue作成時、以下の情報が自動追加されます：

```markdown
Parent Issue: #100

(ユーザー指定の本文)

<!-- HIERARCHY_METADATA
parentIssueNumber: 100
hierarchyLevel: 1
ancestorPath: [100]
-->
```

## 実行コマンド

### ローカル実行

```bash
# Issue分析実行
cargo run --bin miyabi-cli -- agent issue --issue 270

# 複数Issue一括分析
cargo run --bin miyabi-cli -- agent issue --issues 270,240,276

# 子Issue作成（親Issue指定）
cargo run --bin miyabi-cli -- agent issue --create-sub-issue --parent 100 --title "Phase 1実装" --body "詳細..."

# Release build（最適化済み）
cargo build --release
./target/release/miyabi-cli agent issue --issue 270
```

### GitHub Actions実行

Issueオープン時に自動実行 (`.github/workflows/issue-agent.yml`)

## 分析コメント出力例

### GitHub Issue コメント（通常Issue）

```markdown
## 🤖 IssueAgent Analysis

**Issue Type**: bug
**Severity**: Sev.2-High
**Impact**: High
**Responsibility**: Developer
**Assigned Agent**: CodeGenAgent
**Estimated Duration**: 60 minutes

### Applied Labels
- `🐛bug`
- `⭐Sev.2-High`
- `📊影響度-High`
- `👤担当-開発者`
- `🤖CodeGenAgent`

### Dependencies
- #270

---

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

### GitHub Issue コメント（階層的Issue）

```markdown
## 🤖 IssueAgent Analysis

**Issue Type**: feature
**Severity**: Sev.3-Medium
**Impact**: High
**Responsibility**: Developer
**Assigned Agent**: CodeGenAgent
**Estimated Duration**: 240 minutes

### Applied Labels
- `✨feature`
- `➡️Sev.3-Medium`
- `📊影響度-High`
- `👤担当-開発者`
- `🤖CodeGenAgent`
- `🌳hierarchy:root`

### Hierarchy Information
**Hierarchy Level**: 0 (Root Issue)
**Child Issues**: 5 sub-issues
**Progress**: 3/5 completed (60%)

### Child Issues
- [x] #101 Phase 1: DB設計
- [ ] #102 Phase 2: API実装
- [x] #105 Phase 3: フロントエンド実装
- [x] #106 Phase 4: テスト作成
- [ ] #107 Phase 5: ドキュメント作成

---

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

## ログ出力例

```
[2025-10-08T00:00:00.000Z] [IssueAgent] 🔍 Starting issue analysis
[2025-10-08T00:00:01.234Z] [IssueAgent] 📥 Fetching Issue #270
[2025-10-08T00:00:02.456Z] [IssueAgent] 🧠 Analyzing Issue content
[2025-10-08T00:00:03.789Z] [IssueAgent]    Type: bug, Severity: Sev.2-High, Impact: High
[2025-10-08T00:00:04.012Z] [IssueAgent] 🏷️  Applying 5 labels to Issue #270
[2025-10-08T00:00:05.234Z] [IssueAgent] 👥 Assigning 1 team members to Issue #270
[2025-10-08T00:00:06.456Z] [IssueAgent] 💬 Adding analysis comment to Issue #270
[2025-10-08T00:00:07.789Z] [IssueAgent] ✅ Issue analysis complete: 5 labels applied
```

## メトリクス

**Issue分析**:
- **実行時間**: 通常5-10秒
- **Label付与精度**: 95%+
- **Severity判定精度**: 90%+
- **担当者アサイン率**: 90%+
- **依存関係抽出精度**: 100%

**階層的Issue管理**:
- **子Issue作成時間**: 通常3-5秒
- **親子リンク作成成功率**: 100%
- **進捗率計算精度**: 100%
- **階層Label付与精度**: 100%
- **メタデータ整合性**: 100%

---

## 関連Agent

- **CoordinatorAgent**: IssueAgent分析結果を元にタスク分解
- **CodeGenAgent**: Issue種別に応じて実行
- **DeploymentAgent**: deployment種別Issue実行

---

🤖 組織設計原則: 責任と権限の明確化 - 57ラベル体系による組織的Issue分類 + 階層的Issue管理 (E14:SubIssue)
