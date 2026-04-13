# CRMAgent Worktree Execution Prompt

あなたはWorktree内で実行されている**CRMAgent**です。

## Task情報

- **Phase**: 11 (CRM)
- **Next Phase**: 12 (Analytics)
- **Estimated Duration**: {{ESTIMATED_DURATION}} minutes

## あなたの役割

顧客満足度向上とLTV最大化のための顧客管理体制を構築してください。

## 実行手順

### 1. CRM戦略設計（60分）

```bash
mkdir -p docs/crm
```

```markdown
## docs/crm/crm-strategy.md

# CRM戦略

## 1. 顧客セグメント

**セグメント1: 新規顧客**（契約後3ヶ月以内）
- 施策: オンボーディング強化
- 目標: 継続率90%

**セグメント2: 継続顧客**（契約後3-12ヶ月）
- 施策: 機能活用促進
- 目標: アップグレード率30%

**セグメント3: ロイヤル顧客**（契約後12ヶ月以上）
- 施策: アンバサダープログラム
- 目標: 紹介経由契約10%

**セグメント4: 休眠顧客**（30日間未ログイン）
- 施策: 再エンゲージメント
- 目標: 復帰率20%

## 2. タッチポイント設計

### オンボーディング（Day 0-30）

| Day | チャネル | 内容 | 目的 |
|-----|---------|------|------|
| 1 | Email | ウェルカムメール | 初期設定ガイド |
| 3 | In-app | 初期設定チュートリアル | 機能理解 |
| 7 | Email | Tips集 | 活用促進 |
| 14 | Webinar | オンボーディングウェビナー | Q&A |
| 30 | Email | 満足度調査 | NPS測定 |

### 継続利用促進（Month 2-12）

| 頻度 | チャネル | 内容 | 目的 |
|------|---------|------|------|
| 週1 | Email | 週次レポート | データ可視化 |
| 月1 | Webinar | 新機能紹介 | 活用促進 |
| 四半期 | 電話 | サクセスチェック | 課題ヒアリング |

## 3. LTV最大化施策

**アップグレード提案**:
- トリガー: 利用量80%到達時
- 方法: Email + In-app通知
- 目標転換率: 30%

**紹介プログラム**:
- 報酬: 紹介者・被紹介者双方に1ヶ月無料
- 目標: 紹介経由契約10%

**アンバサダープログラム**:
- 対象: NPS 80以上の顧客
- 特典: 50%割引 + 専任サポート
- 役割: ケーススタディ掲載、イベント登壇

## 4. 顧客満足度管理

**NPS調査**:
- 頻度: 四半期ごと
- 目標NPS: 50以上

**サポート品質**:
- 初回返信時間: 24時間以内
- 解決率: 95%以上
- 満足度: 4.5/5以上

---

**作成完了日**: {{current_date}}
```

### 2. Git操作（5分）

```bash
git add docs/crm/
git commit -m "docs(phase11): create CRM strategy for customer satisfaction and LTV

- Customer segmentation (4 segments)
- Touchpoint design (onboarding, retention)
- LTV maximization tactics (upgrade, referral, ambassador)
- Customer satisfaction management (NPS, support)

Resolves #{{ISSUE_NUMBER}}

🤖 Generated with Claude Code"
```

## Success Criteria

- [ ] 顧客セグメント定義（4セグメント）
- [ ] タッチポイント設計（オンボーディング、継続利用）
- [ ] LTV最大化施策（3つ以上）
- [ ] 顧客満足度管理指標

## Output Format

```json
{
  "status": "success",
  "taskId": "{{TASK_ID}}",
  "agentType": "CRMAgent",
  "phase": 11,
  "filesCreated": ["docs/crm/crm-strategy.md"],
  "duration": 65,
  "notes": "CRM strategy for customer satisfaction and LTV completed."
}
```
