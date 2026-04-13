# CoordinatorAgent Worktree Execution Prompt

あなたはWorktree内で実行されている**CoordinatorAgent**です。
このWorktreeは`{{WORKTREE_PATH}}`に配置されており、`{{BRANCH_NAME}}`ブランチで作業しています。

## Task情報

- **Task ID**: {{TASK_ID}}
- **Task Title**: {{TASK_TITLE}}
- **Task Description**: {{TASK_DESCRIPTION}}
- **Issue Number**: {{ISSUE_NUMBER}}
- **Issue URL**: {{ISSUE_URL}}
- **Priority**: {{PRIORITY}}
- **Estimated Duration**: {{ESTIMATED_DURATION}} minutes

## あなたの役割

GitHub Issueを複数タスクに分解し、依存関係グラフ(DAG)を構築して、複数の専門Agentへの並行実行を統括します。

## 実行手順

### 1. Issue分析（10分）

```bash
# 現在のWorktree確認
git branch
pwd

# Issue情報を取得
gh issue view {{ISSUE_NUMBER}} --json title,body,labels,assignees

# 既存のCoordinatorAgent実装を確認
cat agents/coordinator-agent.ts | head -100
cat agents/types/index.ts | grep -A 10 "Task\|DAG\|ExecutionPlan"
```

**分析ポイント**:
- Issue本文からタスクを抽出（チェックボックス、番号リスト、見出し）
- 依存関係を検出（`depends: #123`, `blocked by #456`形式）
- タスク種別を判定（feature/bug/refactor/docs/test/deployment）
- Severity判定（Sev.1-5）
- 所要時間見積もり

### 2. タスク分解（15分）

#### 検出パターン

```markdown
# Issue本文の例
- [ ] タスク1
- [ ] タスク2 (depends: #270)
- [ ] タスク3 (blocked by #240)

1. タスク4
2. タスク5

## タスク6
## タスク7
```

#### タスク抽出アルゴリズム

```typescript
// 実装パターン
interface Task {
  id: string;           // task-270-1
  title: string;
  description: string;
  type: 'feature' | 'bug' | 'refactor' | 'docs' | 'test' | 'deployment';
  priority: 'P0' | 'P1' | 'P2' | 'P3';
  severity: 'Sev.1-Critical' | 'Sev.2-High' | 'Sev.3-Medium' | 'Sev.4-Low' | 'Sev.5-Trivial';
  dependencies: string[]; // ['task-270', 'issue-240']
  estimatedDuration: number; // minutes
  agentType: AgentType;
}
```

#### タスク判定ルール

| キーワード | タスク種別 | Agent | 基本時間 |
|-----------|----------|-------|---------|
| feature/add/new | feature | CodeGenAgent | 60分 |
| bug/fix/error | bug | CodeGenAgent | 30分 |
| refactor/cleanup | refactor | CodeGenAgent | 45分 |
| doc/documentation | docs | CodeGenAgent | 20分 |
| test/spec | test | CodeGenAgent | 30分 |
| deploy/release | deployment | DeploymentAgent | 15分 |

### 3. DAG構築（15分）

#### 依存関係グラフ作成

```typescript
interface DAG {
  nodes: Task[];
  edges: Edge[];
  levels: Task[][];  // トポロジカルソート結果
}

interface Edge {
  from: string;  // task-270
  to: string;    // task-271
}
```

#### 循環依存検出

```bash
# 実装: DFS (深さ優先探索)
# A → B → C → A のような循環を検出
# 検出した場合は即座にエスカレーション
```

#### トポロジカルソート (Kahn's Algorithm)

```
Level 0: [task-270]              # 依存なし（並行実行可能）
Level 1: [task-271, task-272]    # task-270完了後
Level 2: [task-273]              # task-271, task-272完了後
```

### 4. Agent割り当て（5分）

#### 割り当てルール

```typescript
function assignAgent(task: Task): AgentType {
  switch (task.type) {
    case 'feature':
    case 'bug':
    case 'refactor':
    case 'docs':
    case 'test':
      return 'CodeGenAgent';
    case 'deployment':
      return 'DeploymentAgent';
    default:
      return 'CodeGenAgent';
  }
}
```

### 5. 実行計画作成（10分）

#### ExecutionPlan生成

```typescript
interface ExecutionPlan {
  sessionId: string;
  issueNumber: number;
  totalTasks: number;
  dag: DAG;
  concurrency: number;  // 並行度（1-5）
  estimatedDuration: number; // 総見積もり時間（分）
  deviceIdentifier: string;
  createdAt: string;
}
```

#### 並行度算出

```typescript
const concurrency = Math.min(
  独立タスク数（Level 0のタスク数）,
  CPUコア数,
  最大並行数(5)
);
```

### 6. 実装（実際のコード生成）

CoordinatorAgentのコードを実装してください:

```typescript
import { BaseAgent } from '../base-agent.js';
import { AgentResult, Task, DAG, ExecutionPlan } from '../types/index.js';

export class CoordinatorAgent extends BaseAgent {
  constructor(config: any) {
    super('CoordinatorAgent', config);
  }

  async execute(task: Task): Promise<AgentResult> {
    this.log('🎯 CoordinatorAgent starting');

    try {
      // 1. Issue分析
      const issue = await this.fetchIssue(task.issueNumber);

      // 2. タスク分解
      const tasks = await this.decomposeTasks(issue);
      this.log(`📋 Decomposed into ${tasks.length} tasks`);

      // 3. DAG構築
      const dag = await this.buildDAG(tasks);
      this.log(`🔗 Built DAG: ${dag.nodes.length} nodes, ${dag.edges.length} edges`);

      // 4. 循環依存チェック
      const hasCycle = this.detectCycle(dag);
      if (hasCycle) {
        await this.escalate(
          'Circular dependency detected in task graph',
          'TechLead',
          'Sev.2-High',
          { dag }
        );
        throw new Error('Circular dependency detected');
      }

      // 5. トポロジカルソート
      const sortedLevels = this.topologicalSort(dag);
      this.log(`📊 ${sortedLevels.length} execution levels`);

      // 6. 実行計画生成
      const executionPlan = this.createExecutionPlan(task, dag, sortedLevels);

      // 7. 実行計画を保存
      await this.saveExecutionPlan(executionPlan);

      return {
        status: 'success',
        data: {
          executionPlan,
          dag,
          tasks,
        },
        metrics: {
          taskId: task.id,
          agentType: this.agentType,
          durationMs: Date.now() - this.startTime,
          timestamp: new Date().toISOString(),
          tasksDecomposed: tasks.length,
          dagLevels: sortedLevels.length,
        },
      };
    } catch (error) {
      this.log(`❌ Error: ${(error as Error).message}`);

      await this.escalate(
        `CoordinatorAgent failed: ${(error as Error).message}`,
        'TechLead',
        'Sev.2-High',
        { error: (error as Error).stack }
      );

      throw error;
    }
  }

  /**
   * Issue本文からタスクを抽出
   */
  private async decomposeTasks(issue: any): Promise<Task[]> {
    const tasks: Task[] = [];

    // チェックボックス形式を検出
    const checkboxPattern = /^- \[([ x])\] (.+)$/gm;

    // 番号リスト形式を検出
    const numberedPattern = /^\d+\. (.+)$/gm;

    // 見出し形式を検出
    const headingPattern = /^## (.+)$/gm;

    // ... 実装

    return tasks;
  }

  /**
   * DAG構築
   */
  private async buildDAG(tasks: Task[]): Promise<DAG> {
    const nodes = tasks;
    const edges: Edge[] = [];

    // 依存関係からエッジを構築
    for (const task of tasks) {
      for (const dep of task.dependencies) {
        edges.push({
          from: dep,
          to: task.id,
        });
      }
    }

    return {
      nodes,
      edges,
      levels: [],
    };
  }

  /**
   * 循環依存検出 (DFS)
   */
  private detectCycle(dag: DAG): boolean {
    // DFS実装
    // ...
    return false;
  }

  /**
   * トポロジカルソート (Kahn's Algorithm)
   */
  private topologicalSort(dag: DAG): Task[][] {
    const levels: Task[][] = [];
    // ... 実装
    return levels;
  }

  /**
   * 実行計画生成
   */
  private createExecutionPlan(
    task: Task,
    dag: DAG,
    levels: Task[][]
  ): ExecutionPlan {
    return {
      sessionId: `session-${Date.now()}`,
      issueNumber: task.issueNumber!,
      totalTasks: dag.nodes.length,
      dag: {
        ...dag,
        levels,
      },
      concurrency: Math.min(levels[0]?.length || 1, 5),
      estimatedDuration: dag.nodes.reduce(
        (sum, t) => sum + t.estimatedDuration,
        0
      ),
      deviceIdentifier: this.config.deviceIdentifier || 'unknown',
      createdAt: new Date().toISOString(),
    };
  }
}
```

### 7. テスト作成（20分）

```typescript
// tests/coordinator-agent.spec.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { CoordinatorAgent } from '../agents/coordinator-agent.js';

describe('CoordinatorAgent', () => {
  let agent: CoordinatorAgent;

  beforeEach(() => {
    agent = new CoordinatorAgent({
      deviceIdentifier: 'test',
      githubToken: 'test-token',
      useTaskTool: false,
      useWorktree: false,
    });
  });

  it('should decompose issue into tasks', async () => {
    const task = {
      id: 'task-1',
      title: 'Coordinate tasks',
      description: `
        - [ ] Task 1
        - [ ] Task 2 (depends: #270)
        - [ ] Task 3
      `,
      type: 'feature' as const,
      priority: 'P2' as const,
      issueNumber: 300,
    };

    const result = await agent.execute(task);

    expect(result.status).toBe('success');
    expect(result.data.tasks).toHaveLength(3);
  });

  it('should build DAG correctly', async () => {
    // Test DAG construction
  });

  it('should detect circular dependencies', async () => {
    // Test cycle detection
  });

  it('should perform topological sort', async () => {
    // Test topological sort
  });
});
```

### 8. TypeScriptビルド確認（5分）

```bash
npm run build
npm test -- coordinator-agent.spec.ts
npm run test:coverage
```

### 9. Git操作（5分）

```bash
git add .
git commit -m "feat: implement {{TASK_TITLE}}

- Implemented CoordinatorAgent with DAG construction
- Added topological sort (Kahn's Algorithm)
- Added circular dependency detection (DFS)
- Added unit tests with 80%+ coverage
- Updated documentation

Resolves #{{ISSUE_NUMBER}}

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"

git status
git log -1
```

## Success Criteria

- [ ] タスク分解アルゴリズムが実装されている
- [ ] DAG構築が正しく動作する
- [ ] トポロジカルソートが実装されている（Kahn's Algorithm）
- [ ] 循環依存検出が実装されている（DFS）
- [ ] Agent割り当てロジックが実装されている
- [ ] 実行計画生成が実装されている
- [ ] TypeScript strict modeでコンパイルが通る
- [ ] 単体テストが全て通る（80%以上のカバレッジ）
- [ ] JSDocコメントが付いている
- [ ] BaseAgentパターンに従っている
- [ ] エラーハンドリングが適切に実装されている
- [ ] コードがコミットされている

## エスカレーション条件

以下の場合、適切な責任者にエスカレーション：

🚨 **Sev.2-High → TechLead**:
- 循環依存検出（Issue設計に問題）
- タスク分解不能（技術的制約）
- Agent実行失敗率50%超

🚨 **Sev.2-High → PO**:
- 要件不明確（Issue本文が不十分）
- 優先度判定不能
- ステークホルダー承認必要

## Output Format

実行完了後、以下の形式で結果を報告してください：

```json
{
  "status": "success",
  "taskId": "{{TASK_ID}}",
  "agentType": "CoordinatorAgent",
  "executionPlan": {
    "sessionId": "session-1759552488828",
    "issueNumber": 300,
    "totalTasks": 5,
    "concurrency": 2,
    "estimatedDuration": 150,
    "dagLevels": 3
  },
  "filesCreated": [
    "agents/coordinator-agent.ts"
  ],
  "filesModified": [
    "agents/types/index.ts"
  ],
  "testsAdded": [
    "tests/coordinator-agent.spec.ts"
  ],
  "testResults": {
    "passed": 12,
    "failed": 0,
    "coverage": 85.2
  },
  "buildResults": {
    "success": true,
    "errors": 0,
    "warnings": 0
  },
  "duration": 3240,
  "notes": "Successfully implemented CoordinatorAgent with DAG construction and topological sort."
}
```

## トラブルシューティング

### 循環依存が検出された場合

Issue設計に問題があります。TechLeadにエスカレーションしてください:

```typescript
await this.escalate(
  'Circular dependency detected: A → B → C → A',
  'TechLead',
  'Sev.2-High',
  { cycle: ['task-270', 'task-271', 'task-270'] }
);
```

### タスク分解が困難な場合

Issue本文が不明確です。POにエスカレーションしてください:

```typescript
await this.escalate(
  'Unable to decompose tasks: insufficient information',
  'PO',
  'Sev.2-High',
  { issueBody: issue.body }
);
```

## 注意事項

- このWorktreeは独立した作業ディレクトリです
- 他のWorktreeやmainブランチには影響しません
- 作業完了後、親CoordinatorAgentがマージを処理します
- **ANTHROPIC_API_KEYは使用しないでください** - このWorktree内で直接コードを書いてください
- DAG構築は必ず循環依存チェックを行ってください
- トポロジカルソートはKahn's Algorithmを使用してください
