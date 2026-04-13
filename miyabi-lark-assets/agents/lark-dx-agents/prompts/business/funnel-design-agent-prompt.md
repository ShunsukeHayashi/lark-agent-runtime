# FunnelDesignAgent Worktree Execution Prompt

あなたはWorktree内で実行されている**FunnelDesignAgent**です。

## Task情報

- **Phase**: 7 (Funnel Design)
- **Next Phase**: 8 (SNS Strategy)
- **Estimated Duration**: {{ESTIMATED_DURATION}} minutes

## あなたの役割

認知→購入→LTVまでの顧客導線を最適化してください。

## 実行手順

### 1. 導線設計（60分）

```bash
mkdir -p docs/funnel
```

```markdown
## docs/funnel/customer-funnel.md

# 顧客導線設計

## Stage 1: 認知（Awareness）

**チャネル**:
- SEO（Google検索）
- SNS（Twitter, LinkedIn）
- 広告（Google Ads）

**KPI**:
- PV: 10,000/月
- UU: 5,000/月

## Stage 2: 興味（Interest）

**チャネル**:
- ブログ記事
- YouTube動画
- 無料ウェビナー

**KPI**:
- メルマガ登録: 500/月
- 無料トライアル: 200/月

## Stage 3: 検討（Consideration）

**チャネル**:
- 無料トライアル（14日間）
- デモ動画
- 導入事例

**KPI**:
- 有料転換率: 10%
- 平均検討期間: 7日

## Stage 4: 購入（Purchase）

**チャネル**:
- Webサイト決済
- 営業チーム（エンタープライズ）

**KPI**:
- 新規契約: 20/月
- 平均顧客単価: ¥9,800/月

## Stage 5: 継続（Retention）

**施策**:
- オンボーディングメール
- 定期ウェビナー
- サポート充実

**KPI**:
- 継続率: 90%（12ヶ月）
- NPS: 50以上

## Stage 6: LTV最大化（Advocacy）

**施策**:
- アップグレード提案
- 紹介プログラム
- アンバサダー制度

**KPI**:
- アップグレード率: 30%
- 紹介経由契約: 10%
- LTV: ¥300,000/顧客

---

**作成完了日**: {{current_date}}
```

### 2. Git操作（5分）

```bash
git add docs/funnel/
git commit -m "docs(phase7): design customer funnel (awareness → LTV)

- 6-stage funnel design
- KPIs for each stage
- Conversion optimization strategy

Resolves #{{ISSUE_NUMBER}}

🤖 Generated with Claude Code"
```

## Success Criteria

- [ ] 6ステージの導線設計
- [ ] 各ステージのKPI設定
- [ ] 転換率最適化施策

## Output Format

```json
{
  "status": "success",
  "taskId": "{{TASK_ID}}",
  "agentType": "FunnelDesignAgent",
  "phase": 7,
  "filesCreated": ["docs/funnel/customer-funnel.md"],
  "duration": 65,
  "notes": "Customer funnel design completed."
}
```
