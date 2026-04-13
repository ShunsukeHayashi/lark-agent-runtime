# Coding Agent Execution Prompts

コーディング・開発運用系AgentのWorktree実行プロンプトディレクトリです。

## 概要

このディレクトリには、**Git Worktree内でClaude Codeが実行する際の具体的な手順書**が格納されています。

## プロンプトファイル一覧（6個）

### 1. coordinator-agent-prompt.md
**CoordinatorAgent実行プロンプト**

- **対応Agent**: CoordinatorAgent
- **内容**:
  - Issue分解アルゴリズム（チェックボックス/番号/見出し検出）
  - DAG構築手順（Kahn's Algorithm）
  - Agent割り当てロジック（キーワードベース判定）
  - 並行実行制御（レベル順実行）
  - エラーハンドリング（循環依存検出）
- **変数**:
  - `{{ISSUE_NUMBER}}` - 処理対象のIssue番号
  - `{{WORKTREE_PATH}}` - Worktreeパス
  - `{{CONCURRENCY}}` - 最大並行数

### 2. codegen-agent-prompt.md
**CodeGenAgent実行プロンプト**

- **対応Agent**: CodeGenAgent
- **内容**:
  - 要件分析手順
  - TypeScript strict mode コード生成
  - BaseAgentパターン実装
  - Vitestユニットテスト作成
  - ドキュメント生成（JSDoc）
- **変数**:
  - `{{TASK_ID}}` - タスクID
  - `{{ISSUE_NUMBER}}` - Issue番号
  - `{{BRANCH_NAME}}` - ブランチ名

### 3. review-agent-prompt.md
**ReviewAgent実行プロンプト**

- **対応Agent**: ReviewAgent
- **内容**:
  - ESLint実行手順
  - TypeScript型チェック
  - セキュリティスキャン（npm audit）
  - 品質スコアリング（100点満点）
  - レビューコメント生成
- **変数**:
  - `{{TARGET_FILES}}` - レビュー対象ファイル
  - `{{QUALITY_THRESHOLD}}` - 品質閾値（デフォルト: 80点）

### 4. issue-agent-prompt.md
**IssueAgent実行プロンプト**

- **対応Agent**: IssueAgent
- **内容**:
  - Issue本文解析
  - キーワード抽出（type/priority/severity判定）
  - 53ラベル体系による自動ラベリング
  - 依存関係抽出（depends: #123）
  - JSON形式の出力生成
- **変数**:
  - `{{ISSUE_NUMBER}}` - Issue番号
  - `{{ISSUE_TITLE}}` - Issueタイトル
  - `{{ISSUE_BODY}}` - Issue本文

### 5. pr-agent-prompt.md
**PRAgent実行プロンプト**

- **対応Agent**: PRAgent
- **内容**:
  - Git diff分析
  - Conventional Commits準拠のPRタイトル生成
  - PR本文作成（Summary + Test plan）
  - GitHub API経由でPR作成
- **変数**:
  - `{{BASE_BRANCH}}` - ベースブランチ（通常: main）
  - `{{HEAD_BRANCH}}` - Headブランチ
  - `{{COMMIT_MESSAGES}}` - コミットメッセージ一覧

### 6. deployment-agent-prompt.md
**DeploymentAgent実行プロンプト**

- **対応Agent**: DeploymentAgent
- **内容**:
  - ビルド実行（npm run build）
  - テスト実行（npm test）
  - Firebase/Vercel/AWSデプロイ
  - ヘルスチェック
  - 自動ロールバック手順
- **変数**:
  - `{{DEPLOY_TARGET}}` - デプロイ先（firebase/vercel/aws）
  - `{{ENVIRONMENT}}` - 環境（staging/production）

## プロンプトの構造

各プロンプトファイルは以下の構造を持ちます：

```markdown
# [AgentName] Worktree Execution Prompt

あなたはWorktree内で実行されている**[AgentName]**です。
このWorktreeは`{{WORKTREE_PATH}}`に配置されており、`{{BRANCH_NAME}}`ブランチで作業しています。

## Task情報
- **Task ID**: {{TASK_ID}}
- **Issue Number**: {{ISSUE_NUMBER}}
...

## 実行手順

### 1. [フェーズ1名]（推定時間）
ステップバイステップの手順...

### 2. [フェーズ2名]（推定時間）
...

## 実装例
具体的なコード例...

## Success Criteria
✅ 完了条件のチェックリスト

## Troubleshooting
よくある問題と解決方法

## Output Format
JSON形式の結果レポート
```

## 使用方法

### Worktree内での自動実行

CoordinatorAgentがWorktreeを作成し、該当するプロンプトを自動的にClaude Codeに渡します：

```bash
# 実行例
npm run agents:parallel:exec -- --issues=270 --concurrency=2

# Worktree構成
.worktrees/
└── issue-270/
    ├── .claude/agents/prompts/coding/
    │   └── codegen-agent-prompt.md  # ← Claude Codeが読み込む
    └── [その他のファイル]
```

### 手動実行

特定のプロンプトを個別にテストする場合：

```bash
# Worktree作成
git worktree add .worktrees/test-270 -b test/issue-270

# Worktreeに移動
cd .worktrees/test-270

# Claude Codeでプロンプトファイルを開く
claude .claude/agents/prompts/coding/codegen-agent-prompt.md
```

## 変数置換

プロンプト内の変数は、CoordinatorAgentが実行時に自動的に置換します：

| 変数 | 説明 | 例 |
|------|------|-----|
| `{{TASK_ID}}` | タスクID | `task-270-1` |
| `{{ISSUE_NUMBER}}` | Issue番号 | `270` |
| `{{WORKTREE_PATH}}` | Worktreeパス | `.worktrees/issue-270` |
| `{{BRANCH_NAME}}` | ブランチ名 | `issue-270-fix-auth` |
| `{{CONCURRENCY}}` | 並行数 | `2` |
| `{{TARGET_FILES}}` | 対象ファイル | `agents/*.ts` |

## 関連ドキュメント

- **Agent仕様**: [../../specs/coding/](../../specs/coding/)
- **Worktree実行**: [../../../../CLAUDE.md](../../../../CLAUDE.md)
- **タスク管理プロトコル**: [../../../prompts/task-management-protocol.md](../../../prompts/task-management-protocol.md)

---

🤖 Coding Agent Execution Prompts - Worktree Automation
