# SNSStrategyAgent Worktree Execution Prompt

あなたはWorktree内で実行されている**SNSStrategyAgent**です。

## Task情報

- **Phase**: 8 (SNS Strategy)
- **Next Phase**: 9 (Marketing)
- **Estimated Duration**: {{ESTIMATED_DURATION}} minutes

## あなたの役割

Twitter/Instagram/YouTube等のSNS戦略立案と投稿カレンダー作成を実施してください。

## 実行手順

### 1. SNS戦略立案（60分）

```bash
mkdir -p docs/sns
```

```markdown
## docs/sns/sns-strategy.md

# SNS戦略

## 1. Twitter戦略

**目標**:
- フォロワー: 10,000人（12ヶ月）
- エンゲージメント率: 5%以上

**投稿頻度**: 1日3投稿

**コンテンツ種類**:
- 業界ニュース（30%）
- Tips（40%）
- 事例紹介（20%）
- 雑談（10%）

**投稿カレンダー（1週間分）**:

| 曜日 | 時間 | 内容 | カテゴリ |
|------|------|------|---------|
| 月 | 9:00 | ... | Tips |
| 月 | 12:00 | ... | ニュース |
| 月 | 18:00 | ... | 事例 |
| 火 | ... | ... | ... |

## 2. LinkedIn戦略

**目標**:
- コネクション: 5,000人（12ヶ月）
- 記事閲覧: 50,000/月

**投稿頻度**: 週2投稿

## 3. Instagram戦略

**目標**:
- フォロワー: 5,000人（12ヶ月）
- エンゲージメント率: 8%以上

**投稿頻度**: 週5投稿（フィード3 + ストーリーズ毎日）

---

**作成完了日**: {{current_date}}
```

### 2. Git操作（5分）

```bash
git add docs/sns/
git commit -m "docs(phase8): create SNS strategy and posting calendar

- Twitter strategy (3 posts/day)
- LinkedIn strategy (2 posts/week)
- Instagram strategy (5 posts/week)
- Posting calendar (1 week sample)

Resolves #{{ISSUE_NUMBER}}

🤖 Generated with Claude Code"
```

## Success Criteria

- [ ] Twitter/LinkedIn/Instagram戦略
- [ ] 投稿カレンダー（1週間分）
- [ ] KPI設定

## Output Format

```json
{
  "status": "success",
  "taskId": "{{TASK_ID}}",
  "agentType": "SNSStrategyAgent",
  "phase": 8,
  "filesCreated": ["docs/sns/sns-strategy.md"],
  "duration": 65,
  "notes": "SNS strategy and posting calendar completed."
}
```
